# Copyright 2018 Delft University of Technology
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Modelsim/Questasim target for vhdeps. Generates a TCL script that will
simulate all toplevel entities ending in _tc (or only those specified on the
command line) as a regression test in either batch mode or GUI mode depending
on how the simulator is started. Test cases are expected to terminate by
running out of events in case of success and with a "severity failure" report
statement or simulator timeout in case of failure. This is reflected in the
exit status of vsim when running in batch mode."""

import tempfile
import os
from .shared import add_arguments_for_get_test_cases, get_test_cases, run_cmd

_HEADER = """\
# Copyright 2018 Delft University of Technology
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set libs [list]
set libdir [pwd]
set del_modelsim_ini false
set sources [list]
set test_cases [list]
set current_test -1

# Closes any running simulation, and changes the working directory back to the
# library dir.
proc close_sim {} {
  global libdir del_modelsim_ini current_test test_cases

  # If we were running a test case and are not in batch mode, do some GUI
  # cleanup.
  if {($current_test > -1) && (![batch_mode])} {

    # Close any source view windows that might be open. If we don't do this,
    # regression test simulation will slow down polynomially in the GUI,
    # because modelsim keeps trying to rerender the source viewers... which
    # it's not very good at.
    set windows [view]
    foreach window $windows {
      if {[string first ".source" $window] != -1} {
        noview $window
      }
    }

    # Save the waveform state. If we already have a wave configuration
    # filename, save to that file; it might be user-specified. Otherwise, write
    # a file in the library directory, which is usually a temporary directory
    # made by vhdeps.
    set test_case [lindex $test_cases $current_test]
    dict with test_case {
      if {$wave_config == {}} {
        set wave_config ${libdir}/${lib}.${unit}.wave.cfg
      }
      write format wave $wave_config
    }
    lreplace test_cases $current_test $current_test $test_case

  }

  # Quit any ongoing simulation. Note that the user might have started one
  # outside of our control as well, so we need to do this regardless of the
  # state of $current_test
  quit -sim

  # Change back to the library directory if we're not already there. A false
  # negative here (as in, not detecting that we're in the library directory
  # when in fact we are) is bad, because we incorrectly delete modelsim.ini
  # then.
  if {[pwd] != $libdir} {

    # Modelsim tracks its library mappings (vmap) in modelsim.ini, which it
    # spams in the working directory whenever vmap is run. Such littering is
    # undesirable, so delete it if we created it.
    if {$del_modelsim_ini} {
      file delete modelsim.ini
      set del_modelsim_ini false
    }

    cd $libdir
  }

  # Indicate that we're no longer simulating a test case.
  set current_test -1

}

# Compile sources added with add_source incrementally.
proc compile_sources {{recompile false}} {
  global sources
  close_sim

  # Once we have to compile something, all subsequent files are recompiled as
  # well, since they may depend on the changed file. $compile tracks whether
  # we've had to recompile anything yet. It's simply initialized to true when
  # we want to recompile everything.
  set compile $recompile

  foreach source $sources {
    dict with source {

      # If the file has been modified since it was last compiled, set the
      # $compile flag.
      set new_stamp [file mtime $fname]
      if {$new_stamp > $stamp} {
        set compile true
      }

      # Compile the file if we need to.
      if {$compile} {
        echo "Compiling \\(-work $lib $flags\\):" [file tail $fname]
        set stamp $new_stamp
        eval vcom "-quiet -work $lib $flags $fname"
      }
    }
  }
}

# Shorthand for recompiling all sources.
proc recompile_sources {} {
  compile_sources true
}

# Adds a source to the source list.
proc add_source {fname lib flags} {
  global sources libs
  close_sim

  # Make sure the file exists.
  if {![file exists $fname]} {
    error "$fname does not exist."
    return
  }

  # Make sure the library exists; create it if it doesn't yet.
  if {[lsearch $libs $lib] == -1} {
    vlib $lib
    lappend libs $lib
  }

  # If the file is already in the compile order, just set its flags and return.
  foreach source $sources {
    if {[dict get $source fname] == $fname} {
      set flags new_flags
      return
    }
  }

  # Add the file.
  lappend sources [dict create  \
                   fname $fname \
                   lib   $lib   \
                   flags $flags \
                   stamp 0]
}

# Adds a test case to the test case list. Returns its index/ID.
proc add_test {lib unit workdir timeout {config {}}} {
  global test_cases
  set test_case [dict create        \
    lib $lib                        \
    unit $unit                      \
    workdir $workdir                \
    timeout $timeout                \
    flags {-novopt -assertdebug}    \
    suppress_warnings true          \
    log_all true                    \
    wave_config {}]
  if {$config != {}} {
    set test_case [dict merge $test_case $config]
  }
  dict set test_case result "unknown"
  lappend test_cases $test_case
  return [expr {[llength $test_cases] - 1}]
}

# Run the given test case with the given integer index/ID.
proc run_test_by_id {index} {
  global libdir libs del_modelsim_ini test_cases
  global StdArithNoWarnings StdNumNoWarnings NumericStdNoWarnings

  # Close any currently running simulation before starting a new one. This
  # also cleans up the previous working directory if it wasn't the library
  # dir, and cd's to $libdir. It might also mutate $test_cases, so we do this
  # outside the dict with command.
  close_sim

  set test_case [lindex $test_cases $index]
  dict with test_case {

    # Change to the working directory for this test case. If that was no-op,
    # just return.
    cd $workdir

    # Map the libraries to the ones in $libdir so we can access them. This
    # creates a modelsim.ini file that, if no such file existed before the vmap
    # commands, we should clean up later to avoid littering.
    set del_modelsim_ini [file exists modelsim.ini]
    foreach lib $libs {
      vmap $lib $libdir/$lib
    }

    # Give the command to initialize the simulation.
    eval "vsim $flags $lib.$unit"

    # Enable or disable library warnings based on preferences.
    set StdArithNoWarnings $suppress_warnings
    set StdNumNoWarnings $suppress_warnings
    set NumericStdNoWarnings $suppress_warnings

    # Add signals to the waveform if we're not running in batch mode.
    if {![batch_mode]} {

      # Add all signals to the log if requested.
      if {$log_all} {
        catch {add log -recursive *}
      }

      # If we've run this test case before or the user specified a waveform
      # configuration file for the test case manually, load that configuration
      # instead of setting up the defaults.
      if {[file exists $wave_config]} {
        do $wave_config
      } else {
        configure wave -signalnamewidth 1
        add_signals_to_wave TC sim:/[string tolower $unit]/*
        configure wave -namecolwidth 256
        configure wave -valuecolwidth 192
      }

    }

    # Run until either the test case terminates using a failure report, by
    # event starvation, or due to a timeout. Failure causes a break, which we
    # don't want killing this script, so we have to add onbreak resume too.
    onbreak resume
    run $timeout
    onbreak ""

    # To detect which of the three things occurred, we need to do some arcane
    # stuff, because unfortunately there doesn't seem to be a direct query for
    # it in modelsim. Note that $result is part of the test case dictionary, so
    # the dict implicitely gets updated as well.
    set status1 [runStatus -full]
    onbreak resume
    run -step
    onbreak ""
    set status2 [runStatus -full]
    if {$status2 eq "ready end"} {
      set result passed
    } elseif {$status1 eq "break simulation_stop"} {
      set result failed
    } else {
      set result timeout
    }

  }

  # Update the test_cases global with the updated dict.
  lreplace test_cases $index $index $test_case

  # Return the test case result.
  return $result
}

# Runs the given test by name, which can include wildcards. The first matching
# test case found in the list of test cases is run. If any source files changed
# since the last compilation, they are recompiled.
proc run_test {name} {

}

proc test {name} {run_test name}


proc colorize {vhd_list color} {
  foreach obj $vhd_list {
    # get leaf name
    set nam [lindex [split $obj /] end]
    # change color
    property wave $nam -color $color
  }
}

proc add_signals_to_wave {
  group pattern
  {in_color #00FFFF}
  {out_color #FFFF00}
  {internal_color #FFFFFF}
} {
  catch {add wave -noupdate -expand -group $group $pattern}

  set input_list    [lsort [find signals -in       $pattern]]
  set output_list   [lsort [find signals -out      $pattern]]
  set internal_list [lsort [find signals -internal $pattern]]

  colorize $input_list    $in_color
  colorize $output_list   $out_color
  colorize $internal_list $internal_color

  WaveCollapseAll 0
}

#proc close_all_sources {} {
#  set windows [view]
#  foreach window $windows {
#    if {[string first ".source" $window] != -1} {
#      noview $window
#    }
#  }
#}
#
#proc simulate {lib top {duration -all}} {
#  global last_sim
#  set last_sim [list $lib $top $duration]
#
#  compile_sources
#
#  vsim -novopt -assertdebug $lib.$top
#  suppress_warnings
#
#  if {![batch_mode]} {
#    catch {add log -recursive *}
#    set lcname [string tolower $top]
#    set tcname sim:/${lcname}/*
#    set tbname sim:/${lcname}/tb/*
#    set uutname sim:/${lcname}/tb/uut/*
#    set tcsig [list "TC" $tcname]
#    set tbsig [list "TB" $tbname]
#    set uutsig [list "UUT" $uutname]
#    configure wave -signalnamewidth 1
#    add_waves [list $tcsig $tbsig $uutsig]
#    configure wave -namecolwidth    256
#    configure wave -valuecolwidth   192
#  }
#
#  onbreak resume
#  run $duration
#  if {[batch_mode]} {
#    run -step
#    if {[runStatus -full] ne "ready end"} {
#      exit -code 1
#    } else {
#      exit -code 0
#    }
#  }
#  onbreak ""
#  close_all_sources
#
#  wave zoom full
#
#  echo "Run 'resim' to run the simulation again."
#}
#
#proc resim {} {
#  global last_sim
#  if {$last_sim == 0} {
#    echo "No simulation to rerun."
#    return 1
#  }
#  set lib [lindex $last_sim 0]
#  set top [lindex $last_sim 1]
#  set duration [lindex $last_sim 2]
#
#  compile_sources
#  write format wave wave.cfg
#  vsim -novopt -assertdebug $lib.$top
#  suppress_warnings
#  add log -recursive *
#  onbreak resume
#  run $duration
#  onbreak ""
#  close_all_sources
#  do wave.cfg
#  echo "Run 'resim' to run the simulation again."
#}
#
#proc regression {} {
#  global testcases
#  global last_failure
#  compile_sources
#  set results [list]
#  foreach testcase $testcases {
#    set lib [lindex $testcase 0]
#    set top [lindex $testcase 1]
#    set duration [lindex $testcase 2]
#    if [catch {
#      vsim -novopt -assertdebug $lib.$top
#      suppress_warnings
#      onbreak resume
#      run $duration
#      set status1 [runStatus -full]
#      run -step
#      onbreak ""
#      close_all_sources
#      set status2 [runStatus -full]
#      if {$status2 eq "ready end"} {
#        lappend results [list $lib $top PASSED $duration]
#      } elseif {$status1 eq "break simulation_stop"} {
#        lappend results [list $lib $top FAILED $duration]
#      } else {
#        lappend results [list $lib $top TIMEOUT $duration]
#      }
#    }] {
#      lappend results [list $lib $top fail $duration]
#    }
#  }
#  echo "Regression test complete. Results:"
#  foreach tcresult $results {
#    set lib [lindex $tcresult 0]
#    set top [lindex $tcresult 1]
#    set result [lindex $tcresult 2]
#    if {$result eq "PASSED"} {
#      echo " - $result $lib.$top"
#    }
#  }
#  set runs 0
#  set passes 0
#  set fails 0
#  set last_failure 0
#  foreach tcresult $results {
#    set lib [lindex $tcresult 0]
#    set top [lindex $tcresult 1]
#    set result [lindex $tcresult 2]
#    set duration [lindex $tcresult 3]
#    incr runs
#    if {$result ne "PASSED"} {
#      incr fails
#      echo " - $result $lib.$top"
#      set last_failure [list $lib $top $duration]
#    } else {
#      incr passes
#    }
#  }
#  echo "$passes/$runs test(s) passed"
#  if [batch_mode] {
#    if {$fails > 0} {
#      exit -code 1
#    } else {
#      exit -code 0
#    }
#  } else {
#    if {$fails > 0} {
#      echo "Failure! Run 'regression' to recompile and try again, or 'failure' to simulate the last failure."
#    } else {
#      echo "Success! Run 'regression' to recompile and try again."
#    }
#  }
#}
#
#proc failure {} {
#  global last_failure
#  if {$last_failure == 0} {
#    echo "No failed simulation to run."
#    return 1
#  }
#  set lib [lindex $last_failure 0]
#  set top [lindex $last_failure 1]
#  set duration [lindex $last_failure 2]
#  simulate $lib $top $duration
#}
#
## initialization
#package require md5
#set last_sim 0
#set last_failure 0
#set testcases [list]
#set compile_list [list]

"""

def add_arguments(parser):
    """Adds the command-line arguments supported by this target to the given
    `argparse.ArgumentParser` object."""
    add_arguments_for_get_test_cases(parser)

    parser.add_argument(
        '--tcl', action='store_true',
        help='Don\'t run vsim; just output the TCL script.')

    parser.add_argument(
        '--gui', action='store_true',
        help='Launch vsim in GUI mode versus batch mode.')

    parser.add_argument(
        '--no-tempdir', action='store_true',
        help='Disables cwd\'ing to a temporary working directory.')

def _write_tcl(vhd_list, tcl_file, **kwargs):
    """Writes the TCL file for the given VHDL list and testcase pattern to
    `outfile`."""
    tcl_file.write(_HEADER)
    for vhd in vhd_list.order:
        flags = '-quiet'
        if vhd.version <= 1987:
            flags += ' -87'
        elif vhd.version <= 1993:
            flags += ' -93'
        elif vhd.version <= 2002:
            flags += ' -2002'
        elif vhd.version <= 2008:
            flags += ' -2008'
        else:
            raise ValueError('VHDL version %d is not supported' % vhd.version)
        tcl_file.write('add_source {%s} {%s} {%s}\n' % (vhd.fname, vhd.lib, flags))

    test_cases = get_test_cases(vhd_list, **kwargs)
    for test_case in test_cases:
        tcl_file.write('add_test %s %s "%s" "%s"\n' % (
            test_case.file.lib,
            test_case.unit,
            os.path.dirname(test_case.file.fname),
            test_case.file.get_timeout()))
        #tcl_file.write('lappend testcases [list %s %s "%s"]\n' % (
            #test_case.file.lib, test_case.unit, test_case.file.get_timeout()))
    #if len(test_cases) == 1:
        #test_case = test_cases[0]
        #tcl_file.write('simulate %s %s "%s"\n' % (
            #test_case.file.lib, test_case.unit, test_case.file.get_timeout()))
    #else:
        #tcl_file.write('regression\n')

def _run(vhd_list, output_file, gui=False, **kwargs):
    """Runs this backend in the current working directory."""
    try:
        from plumbum.cmd import vsim
    except ImportError:
        raise ImportError('no vsim-compatible simulator was found.')
    from plumbum import local

    # Write the TCL file to a temporary file.
    with open('vsim.do', 'w') as tcl_file:
        _write_tcl(vhd_list, tcl_file, **kwargs)

    # Run vsim in the requested way.
    if gui:
        cmd = vsim['-do', 'vsim.do']
    else:
        cmd = local['cat']['vsim.do'] | vsim
    exit_code, *_ = run_cmd(output_file, cmd)

    # Forward vsim's exit code.
    return exit_code

def run(vhd_list, output_file, tcl=False, no_tempdir=False, **kwargs):
    """Runs this backend."""

    # If we just need to output TCL, short-circuit the rest of the backend.
    if tcl:
        _write_tcl(vhd_list, output_file, **kwargs)
        return 0

    try:
        from plumbum import local
    except ImportError:
        raise ImportError('the vsim backend requires plumbum to be installed '
                          'to run vsim (pip3 install plumbum).')

    if no_tempdir:
        return _run(vhd_list, output_file, **kwargs)
    with tempfile.TemporaryDirectory() as tempdir:
        with local.cwd(tempdir):
            return _run(vhd_list, output_file, **kwargs)
