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

import sys
import fnmatch

_header = """\
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

proc timestamp {} {
  return [clock seconds]
}

proc add_source {file_name compile_flags} {
  global compile_list

  if {[file exists $file_name]} {
    # calculate md5 hash
    set file_hash [md5::md5 -hex $file_name]

    # Check if file exists in list
    for {set i 0} {$i < [llength $compile_list]} {incr i} {
      set comp_unit [lindex $compile_list $i]
      if {[lindex $comp_unit 0] == $file_name} {
        # file exists, check if mode changed
        if {[lindex $comp_unit 3] != $compile_flags} {
          # change the mode and reset the timestamp
          lset compile_list $i [list $file_name $file_hash 0 $compile_flags]
        }
        return
      }
    }

    # if the file isn't in the list yet, so we haven't returned, add file to 
    # compile list
    lappend compile_list [list $file_name $file_hash 0 $compile_flags]
  } else {
    error $file_name " does not exist."
  }
  return
}

# compile all sources added to the compilation list
proc compile_sources {{quiet 1}} {
  global compile_list

  for {set i 0} {$i < [llength $compile_list]} {incr i} {
    set comp_unit [lindex $compile_list $i]

    # extract file information
    set file_name [lindex $comp_unit 0] 
    set file_hash [lindex $comp_unit 1]
    set file_last [lindex $comp_unit 2]
    set compile_flags [lindex $comp_unit 3]

    # check if file still exists
    if {[file exists $file_name]} {
      set file_disk_time [file mtime $file_name]
      # check if file needs to be recompiled
      if {($file_disk_time > $file_last)} {
        set file_disk_hash [md5::md5 -hex $file_name]
        if {($file_disk_time > $file_last) || ($file_hash != $file_disk_hash)} {
          echo "Compiling \($compile_flags\):" [file tail $file_name]
          eval vcom "-quiet $compile_flags $file_name"
          # if compilation failed, the script will exit and the file will not be
          # added to the compile list.

          # update the compile list
          lset compile_list $i [list $file_name $file_hash [timestamp] $compile_flags]
        }
      }
    } else {
      echo "File " $file_name " no longer exists. Removing from compile list."
      set compile_list [lreplace $compile_list $i $i]
    }
  }
}

# recompile all sources added to the compilation list
proc recompile_sources {{quiet 1}} {
  global compile_list

  # loop over each compilation unit
  for {set i 0} {$i < [llength $compile_list]} {incr i} {
    set comp_unit [lindex $compile_list $i]

    # extract file information
    set file_name [lindex $comp_unit 0] 
    set file_hash [lindex $comp_unit 1]
    set compile_flags [lindex $comp_unit 3]

    # set timestamp to 0
    lset compile_list $i [list $file_name $file_hash 0 $compile_flags]
  }
  compile_sources $quiet
}

proc suppress_warnings {} {
  global StdArithNoWarnings
  global StdNumNoWarnings
  global NumericStdNoWarnings

  set StdArithNoWarnings 1
  set StdNumNoWarnings 1
  set NumericStdNoWarnings 1
}

proc colorize {l c} {
  foreach obj $l {
    # get leaf name
    set nam [lindex [split $obj /] end]
    # change color
    property wave $nam -color $c
  }
}

proc add_colored_unit_signals_to_group {group unit in_color out_color internal_color} {
  # add wave -noupdate -expand -group $group -divider -height 32 $group
  catch {add wave -noupdate -expand -group $group $unit}

  set input_list    [lsort [find signals -in        $unit]]
  set output_list   [lsort [find signals -out       $unit]]
  set port_list     [lsort [find signals -ports     $unit]]
  set internal_list [lsort [find signals -internal  $unit]]

  # This could be used to work with dividers:
  colorize $input_list     $in_color
  colorize $output_list    $out_color
  colorize $internal_list  $internal_color
}

proc add_waves {groups {in_color #00FFFF} {out_color #FFFF00} {internal_color #FFFFFF}} {
  for {set group_idx 0} {$group_idx < [llength $groups]} {incr group_idx} {
    set group [lindex [lindex $groups $group_idx] 0]
    set unit  [lindex [lindex $groups $group_idx] 1]
    add_colored_unit_signals_to_group $group $unit $in_color $out_color $internal_color
    WaveCollapseAll 0
  }
}

proc close_all_sources {} {
  set windows [view]
  foreach window $windows {
    if {[string first ".source" $window] != -1} {
      noview $window
    }
  }
}

proc simulate {lib top {duration -all}} {
  global last_sim
  set last_sim [list $lib $top $duration]

  compile_sources

  vsim -novopt -assertdebug $lib.$top
  suppress_warnings

  if [batch_mode] {
  } else {
    catch {add log -recursive *}
    set lcname [string tolower $top]
    set tcname sim:/${lcname}/*
    set tbname sim:/${lcname}/tb/*
    set uutname sim:/${lcname}/tb/uut/*
    set tcsig [list "TC" $tcname]
    set tbsig [list "TB" $tbname]
    set uutsig [list "UUT" $uutname]
    configure wave -signalnamewidth 1
    add_waves [list $tcsig $tbsig $uutsig]
    configure wave -namecolwidth    256
    configure wave -valuecolwidth   192
  }

  onbreak resume
  run $duration
  if [batch_mode] {
    run -step
    if {[runStatus -full] ne "ready end"} {
      exit -code 1
    } else {
      exit -code 0
    }
  }
  onbreak ""
  close_all_sources

  wave zoom full

  echo "Run 'resim' to run the simulation again."
}

proc resim {} {
  global last_sim
  if {$last_sim == 0} {
    echo "No simulation to rerun."
    return 1
  }
  set lib [lindex $last_sim 0]
  set top [lindex $last_sim 1]
  set duration [lindex $last_sim 2]

  compile_sources
  write format wave wave.cfg
  vsim -novopt -assertdebug $lib.$top
  suppress_warnings
  add log -recursive *
  onbreak resume
  run $duration
  onbreak ""
  close_all_sources
  do wave.cfg
  echo "Run 'resim' to run the simulation again."
}

proc regression {} {
  global testcases
  global last_failure
  compile_sources
  set results [list]
  foreach testcase $testcases {
    set lib [lindex $testcase 0]
    set top [lindex $testcase 1]
    set duration [lindex $testcase 2]
    if [catch {
      vsim -novopt -assertdebug $lib.$top
      suppress_warnings
      onbreak resume
      run $duration
      set status1 [runStatus -full]
      run -step
      onbreak ""
      close_all_sources
      set status2 [runStatus -full]
      if {$status2 eq "ready end"} {
        lappend results [list $lib $top PASSED $duration]
      } elseif {$status1 eq "break simulation_stop"} {
        lappend results [list $lib $top FAILED $duration]
      } else {
        lappend results [list $lib $top TIMEOUT $duration]
      }
    }] {
      lappend results [list $lib $top fail $duration]
    }
  }
  echo "Regression test complete. Results:"
  foreach tcresult $results {
    set lib [lindex $tcresult 0]
    set top [lindex $tcresult 1]
    set result [lindex $tcresult 2]
    if {$result eq "PASSED"} {
      echo " - $result $lib.$top"
    }
  }
  set runs 0
  set passes 0
  set fails 0
  set last_failure 0
  foreach tcresult $results {
    set lib [lindex $tcresult 0]
    set top [lindex $tcresult 1]
    set result [lindex $tcresult 2]
    set duration [lindex $tcresult 3]
    incr runs
    if {$result ne "PASSED"} {
      incr fails
      echo " - $result $lib.$top"
      set last_failure [list $lib $top $duration]
    } else {
      incr passes
    }
  }
  echo "$passes/$runs test(s) passed"
  if [batch_mode] {
    if {$fails > 0} {
      exit -code 1
    } else {
      exit -code 0
    }
  } else {
    if {$fails > 0} {
      echo "Failure! Run 'regression' to recompile and try again, or 'failure' to simulate the last failure."
    } else {
      echo "Success! Run 'regression' to recompile and try again."
    }
  }
}

proc failure {} {
  global last_failure
  if {$last_failure == 0} {
    echo "No failed simulation to run."
    return 1
  }
  set lib [lindex $last_failure 0]
  set top [lindex $last_failure 1]
  set duration [lindex $last_failure 2]
  simulate $lib $top $duration
}

# initialization
package require md5
set last_sim 0
set last_failure 0
set testcases [list]
set compile_list [list]

"""

def add_arguments(parser):
    parser.add_argument(
        '--pattern', metavar='pat', action='append',
        help='Specifies a pattern used to filter which toplevel entities are '
        'actually simulated. Patterns work glob-style and are applied in the '
        'sequence in which they are specified, by default operating on entity '
        'names. If a pattern starts with \'!\', entities matched previously '
        'that also match this pattern are excluded. If a pattern starts with '
        '\':\', the filename is matched instead. \':!\' combines the two. If '
        'no patterns are specified, the matcher defaults to a single \'*_tc\' '
        'pattern.')

def run(l, f, pattern):
    if not pattern:
        pattern = ['*_tc']
    f.write(_header)
    libs = set()
    for vhd in l.order:
        libs.add(vhd.lib)
    for lib in libs:
        f.write('vlib %s\n' % lib)
    for vhd in l.order:
        flags = '-quiet -work %s' % vhd.lib
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
        f.write('add_source {%s} {%s}\n' % (vhd.fname, flags))
    for top in l.top:
        include = False
        for pat in pattern:
            target = top.unit
            if pat.startswith(':'):
                target = top.fname
                pat = pat[1:]
            invert = False
            if pat.startswith('!'):
                invert = True
                pat = pat[1:]
            if fnmatch.fnmatchcase(target, pat):
                include = not invert
        if include:
            f.write('lappend testcases [list %s %s "%s"]\n' % (top.lib, top.unit, top.get_timeout()))
    if len(l.top) == 1:
        top = l.top[0]
        f.write('simulate %s %s "%s"\n' % (top.lib, top.unit, top.get_timeout()))
    else:
        f.write('regression\n')

