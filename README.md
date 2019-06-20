
vhdeps: a VHDL file dependency analyzer
=======================================

[![PyPi](https://badgen.net/pypi/v/vhdeps)](https://pypi.org/project/vhdeps/)
[![Build Status](https://dev.azure.com/abs-tudelft/vhdeps/_apis/build/status/abs-tudelft.vhdeps?branchName=master)](https://dev.azure.com/abs-tudelft/vhdeps/_build/latest?definitionId=4&branchName=master)
[![codecov](https://codecov.io/gh/abs-tudelft/vhdeps/branch/master/graph/badge.svg)](https://codecov.io/gh/abs-tudelft/vhdeps)

`vhdeps` is a simple dependency analyzer for VHDL, to be used with tools that
either awkwardly or downright *don't* support automatic compile order
generation. It's quite simplistic in its VHDL parsing -- it just uses regular
expressions to match entity, component, and package declarations, uses, and
definitions and works from there -- but it should be enough for most use cases.

`vhdeps` provides a generic output format so you can easily do whatever you
want with the compile order, but it also allows "targets" to be defined to do
this within `vhdeps`. At the time of writing, there are two such targets; one
that outputs a TCL script for Modelsim-compatible simulators (with a bunch of
convenience stuff like incremental compilation and batch-mode regression
testing) and one that drives a simulation with GHDL. Both of these targets do
pose the requirement that toplevel entities end in `_tc` (test case) and
terminate through event exhaustion upon success or through a
`report ... severity failure` statement or a timeout upon failure. The timeout
defaults to 1 ms, but can be overridden using a pragma statement.

`vhdeps` allows VHDL files to be tagged with the VHDL versions they're
compatible with or be marked as synthesis- or simulation-only using
`.`-separated tags in the filename:

 - Filenames matching `*.<version>.*`, where `<version>` is a two-digit VHDL
   version code (93, 08, and so on), are compatible with the specified version.
   Multiple version tags can be chained for files that are compatible with
   multiple versions. If no version tag is present, the file is assumed to be
   compatible with all versions.
 - Filenames matching `*.syn.*` are synthesis-only.
 - Filenames matching `*.sim.*` are simulation-only.

By default, `vhdeps` ignores synthesis-only files and chooses a file compatible
with VHDL-2008 if it has to choose between multiple implementations of the same
design unit. This behavior can be configured on the command line.

Finally, `vhdeps` can do some basic style checking if you like. The rules it
can enforce for you are:

 - Each VHDL file must define exactly one entity or exactly one package.
 - VHDL package names must use the `_pkg` suffix.
 - The filename must match the name of the VHDL entity/package.
