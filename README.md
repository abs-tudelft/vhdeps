
vhdeps: a VHDL file dependency analyzer
=======================================

`vhdeps` is a simple dependency analyzer for VHDL, to be used with tools that
either awkwardly or downright *don't* support automatic compile order
generation. It's quite simplistic in its VHDL parsing -- it just uses regular
expressions to match entity, component, and package declarations, uses, and
definitions and works from there -- but it should be enough for most use cases.

`vhdeps` provides a generic output format so you can easily do whatever you
want with the compile order, but it also allows "targets" to be defined to do
this within `vhdeps`. At the time of writing, there is one such target, which
outputs a TCL script for Modelsim-compatible simulators, supporting a bunch of
convenience stuff like incremental compilation and batch-mode regression
testing. The only requirements it poses are that the toplevel simulation
entities end in "_tc" (test case), and terminate through event exhaustion upon
success or through a `report ... severity failure` statement upon failure.

Finally, `vhdeps` can do some basic style checking if you like. The rules it
can enforce for you are:

 - Each VHDL file must define exactly one entity or exactly one package.
 - VHDL package names must use the `_pkg` suffix.
 - The filename must match the name of the VHDL entity/package.
 - The filename must match `*.<version>.*`, where `<version>` is an integer
   specifying the version of the VHDL file (93, 2008, etc)
 - The filename must match `*.i.*` and/or `*.y.*` to indicate inclusion
   in simulation resp. synthesis contexts.

The version and simulation/synthesis "modifiers" in the VHDL filenames are used
by `vhdeps` to filter out files based on a maximum VHDL version and whether
it's targeting simulation or synthesis.

