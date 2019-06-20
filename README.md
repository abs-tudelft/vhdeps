
vhdeps: a VHDL file dependency analyzer and test runner
=======================================================

[![PyPi](https://badgen.net/pypi/v/vhdeps)](https://pypi.org/project/vhdeps/)
[![Build Status](https://dev.azure.com/abs-tudelft/vhdeps/_apis/build/status/abs-tudelft.vhdeps?branchName=master)](https://dev.azure.com/abs-tudelft/vhdeps/_build/latest?definitionId=4&branchName=master)
[![codecov](https://codecov.io/gh/abs-tudelft/vhdeps/branch/master/graph/badge.svg)](https://codecov.io/gh/abs-tudelft/vhdeps)

Whatever tool you use, testing VHDL code has always been a pain. With most
tools you have to write TCL scripts for compilation, requiring you to copypaste
all the paths of the files your test case depends on... eventually leading you
to just include everything despite the additional compilation time. Automated
testing for CI requires yet more TCL scripting, or is outright not possible due
to licensing or the tools being primarily GUI-oriented. Not to mention doing
all this for more than two or three integration tests, unit tests be damned.
Don't even start about code coverage.

`vhdeps` aims to change this, at least for a common subset of problems. With
it, running your test suite is as simple as going to your project's root
directory and running `vhdeps ghdl`, `vhdeps vsim`, or whatever other target
that may be added in the future. As it should be!


Installation
------------

`vhdeps` is a Python package. To install it, simply run:

    sudo pip3 install vhdeps

You can of course install it to a venv or your home directory as well if you
prefer, as long as you make sure you add the `bin` folder to your system path,
or call `vhdeps` using `python3 -m vhdeps`.

Installing `vhdeps` this way takes care of all its Python dependencies, but
does not install [`ghdl`](https://github.com/ghdl/ghdl) or a `vsim`-compatible
simulator (like Modelsim) for you.

To use the code coverage features of the GHDL target, you must get yourself a
GHDL build that uses the [GCC backend](https://ghdl.readthedocs.io/en/latest/building/gcc/),
and install [`lcov`](http://ltp.sourceforge.net/coverage/lcov.php) in addition
if you want the fancier output formats.

Once you have that, try the [vhlib](https://github.com/abs-tudelft/vhlib)
repository to see `vhdeps` in action.


Targets
-------

After `vhdeps` determines the compile order for your project, it passes it to a
so-called target of your choosing. Currently, the following targets are
available.

### `dump`

This target simply dumps the compile order in a format that should be easy
to read using whatever script you may devise on your own. It does not require
any non-Python tools.

    $ vhdeps dump StreamBuffer -o order
    Including the current working directory recursively by default...

    $ cat order
    dep work 2008 /path/to/vhlib/stream/StreamSlice.vhd
    dep work 2008 /path/to/vhlib/util/UtilRam1R1W.vhd
    dep work 2008 /path/to/vhlib/stream/StreamFIFOCounter.vhd
    dep work 2008 /path/to/vhlib/util/UtilRam_pkg.vhd
    dep work 2008 /path/to/vhlib/util/UtilInt_pkg.vhd
    dep work 2008 /path/to/vhlib/stream/Stream_pkg.vhd
    dep work 2008 /path/to/vhlib/stream/StreamFIFO.vhd
    top work 2008 /path/to/vhlib/stream/StreamBuffer.vhd

### `ghdl`

This target runs the test cases detected in the compile order using GHDL. For
example:

    $ vhdeps ghdl StreamBuffer_*_tc
    ...
    Final summary:
     * PASSED  streambuffer_0_tc
     * PASSED  streambuffer_200_tc
     * PASSED  streambuffer_2_tc
     * PASSED  streambuffer_4_tc
     * PASSED  streambuffer_6_tc
    Test suite PASSED

Here's some of the features this target supports:

 - Runs in a temporary directory by default, preventing `.cf` or object files
   from appearing all over the place.
 - Supports parallel elaboration and execution (parallel analysis is
   [not supported by GHDL](https://github.com/ghdl/ghdl/issues/829)).
 - Can output VCD files for all test cases to a directory of your choosing.
 - Can automatically open `gtkwave` for you to view the waveform(s).
 - If GHDL is built with the [GCC backend](https://ghdl.readthedocs.io/en/latest/building/gcc/),
   it can generate coverage information for you, all the way to user-friendly
   HTML output.

### `vsim`

This target runs the test suite in Modelsim or Questasim, either in GUI or
batch mode, or simply outputs an appropriate `.do` file for you. Here's an
example of what it all looks like:

    $ vhdeps vsim StreamBuffer_*_tc
    ...
    # Regression test complete. Results:
    #  - PASSED work.streambuffer_0_tc
    #  - PASSED work.streambuffer_200_tc
    #  - PASSED work.streambuffer_2_tc
    #  - PASSED work.streambuffer_4_tc
    #  - PASSED work.streambuffer_6_tc
    # 5/5 test(s) passed

    $ vhdeps vsim StreamBuffer_0_tc --gui
    ...

(after zooming in to the waveforms only:)

![Modelsim screenshot](/.assets/modelsim.png?raw=true)

The TCL script supports the following:

 - Incremental recompilation and rerunning in the GUI through the `resim`
   command.
 - `resim` maintains your waveform view configuration (zoom level, signals,
   etc.).
 - Initially, signals are automatically added for the toplevel test case, the
   `uut` instance in the test case (if any) and the `tb` instance in the test
   case (if any). Inputs are colored blue, outputs are colored yellow, and
   internal signals are colored white to improve readability.
 - When there are multiple test cases, the script executes all of them
   initially without displaying any waveforms. You can then run `failure`
   to run (one of) the failing test case(s) with waveforms enabled to
   debug it.
 - Automatic GUI vs. batch mode detection: in batch mode, Modelsim
   automatically exits with 0 or 1 depending on the result of the test suite.

The script is only tested in Modelsim and Questasim so far, and requires some
rather magical constructs to make signal coloring and restoring the waveform
view work properly. Your mileage may vary with other vsim-compatible tools
such as Riviera.

### (your target here?)

It's easy to add a new target to `vhdeps`. Simply look for its install
directory (or clone this repository and install it using `setup.py`) and add
a file to the `vhdeps/target` directory. `vhdeps` automagically detects the
available targets, so there's no need to add your target to any kind of index.

API documentation is still somewhat lacking, however. Then again, it shouldn't
be *too* difficult to figure it out from the docstrings and existing targets.


VHDL code requirements
----------------------

`vhdeps` is currently quite simplistic in its VHDL parsing -- it just uses
regular expressions to match entity, component, and package declarations, uses,
and definitions and works from there -- but it should be enough for most use
cases. Some known limitations are listed [here](https://github.com/abs-tudelft/vhdeps/issues/6).

By default, `vhdeps` detects test cases by looking for toplevel entities that
end in `_tc`. This is intentionally different from the industry-standard `_tb`,
because test benches are rarely built to check themselves and self-terminate
in practice, which would just lead to timeouts. You can of course adjust this
behavior using command-line options. Currently, `vhdeps`
[does not support](https://github.com/abs-tudelft/vhdeps/issues/4) defining
multiple test case entities in a single file, but it should be able to handle
this just fine for design files.

By self-terminating, we mean that it either terminates by event exhausting
to indicate success (usually, this means stopping the clock), or through a
`severity failure` report or assertion statement to indicate failure. If a
test case does not terminate within a specified timeout, the test case is also
considered to have failed. This timeout is specified in the test case file
using a pragma, like this:

    -- pragma simulation timeout 10 ms

The timeout arbitrarily defaults to 1 ms if it is not specified.

`vhdeps` can handle input from different VHDL versions within a single run (as
long as the target supports this as well) and can distinguish between
simulation-only, synthesis-only, and universal source files. It does this based
on tags specified in the VHDL filenames:

 - Filenames matching `*.<version>.*`, where `<version>` is a two-digit VHDL
   version code (93, 08, and so on), are compatible with the specified version.
   Multiple version tags can be chained for files that are compatible with
   multiple versions. If no version tag is present, the file is assumed to be
   compatible with all versions.
 - Filenames matching `*.syn.*` are synthesis-only.
 - Filenames matching `*.sim.*` are simulation-only.

You can even have both a VHDL-93 and a VHDL-2008 file for a single design unit;
`vhdeps` will automatically disambiguate based on a desired or required VHDL
version that you specify on the command line.


Miscellaneous features
----------------------

### Black box detection

Most tools are, annoyingly, perfectly okay with black boxes by default (black
boxes are component instantiations that don't resolve to any previously
compiled entity, in case you're not aware). `vhdeps` isn't: by default, it will
refuse to output a compile order for you if your design has black boxes. You
can override this behavior by including the files that contain the black box
component definitions with the `-x` flag instead of `-i`, which may be useful
for getting the compile order for projects that use vendor primitives.

### Style checking

In addition to the rules above, `vhdeps` can enforce some additional rules for
you if you like by including VHDL files "strictly" (`-I` instead of `-i`).
These rules are:

 - Each VHDL file must define exactly one entity or exactly one package.
 - VHDL package names must use the `_pkg` suffix.
 - The filename must match the name of the VHDL entity/package.
