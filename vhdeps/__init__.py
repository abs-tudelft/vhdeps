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

"""Main module for vhdeps.

Use `run_cli()` to run vhdeps as if it was run from the command line. For a
more script-friendly interface, use the `vhdeps.vhdl' submodule directly."""

import sys
import os
import glob
import argparse
import vhdeps.vhdl as vhdl
import vhdeps.target as target_mod
from vhdeps.version import __version__

def run_cli(args=None):
    """Runs the vhdeps CLI. The command-line arguments are taken from `args`
    when specified, or `sys.argv` by default. The return value is the exit code
    for the process. If the backtrace option is passed, exceptions will not be
    caught."""

    parser = argparse.ArgumentParser(
        usage='vhdeps <target> [entities...] [flags...] [--] [target-flags...]',
        description='This script is a VHDL dependency analyzer. Given a list '
        'of VHDL files and/or directories containing VHDL files, it can '
        'generate a compile order and output this in various formats, such '
        'as a TCL file to be sourced by a Modelsim-compatible simulator. '
        'Specify --targets to list the available targets/output formats. '
        'In addition, this script can check some style rules, and prevents '
        'accidental black-box insertion due to missing entities for component '
        'declarations, by making you explicitly opt out of this behavior when '
        'necessary.')

    # Positional arguments.
    parser.add_argument(
        'target', metavar='target',
        nargs='?', default=None,
        help='Target simulator/synthesizer. Specify --targets to print the '
        'list of supported targets.')

    parser.add_argument(
        'entity', metavar='entity',
        nargs='*',
        help='Specifies the toplevel entity/ies to be compiled. When specified, '
        'the compile order will be such that only these entities and their '
        'dependencies are included. If not specified, all files are included. '
        'Entities are specified by their VHDL name, optionally prefixed with '
        'the library they\'re compiled into. Glob-style pattern matching is '
        'also supported.')

    # Source directory specifications. At least one of these should be
    # specified for this program to do anything useful.
    parser.add_argument(
        '-i', '--include', metavar='{{version:}lib:}path',
        action='append', default=[],
        help='Includes VHDL files for dependency analysis. If the path is a '
        'directory, it is scanned recursively; if it is a file, only that '
        'file is added. If the path contains * or ?, it is instead treated as '
        'a non-recursive file glob, so \'<path>/*.vhd\' can be used to '
        'include a directory non-recursively. If lib is specified, it marks '
        'that files must be compiled into the specified library name instead '
        'of the default (work). If version is specified, all files in the '
        'directory are assumed to have the given VHDL version, regardless of '
        'version tags in the filenames.')

    parser.add_argument(
        '-I', '--strict', metavar='{{version:}lib:}path',
        action='append', default=[],
        help='Same as -i, but also enforces style rules. Specify --style for more '
        'information.')

    parser.add_argument(
        '-x', '--external', metavar='{{version:}lib:}path',
        action='append', default=[],
        help='Same as -i, but the included files are allowed to have unresolved '
        '"black-box" components. Useful for interfaces to Verilog or for vendor '
        'libraries.')

    # Filters.
    parser.add_argument(
        '-d', '--desired-version', metavar='desired-version',
        type=int, default=None,
        help='Desired VHDL version, specified as 2-digit or 4-digit year. Default '
        '2008. This is used when multiple versions of a VHDL file are available, '
        'indicated through *.<version>.* tags in the filename, where <version> is '
        'a two-digit year. A file can be tagged with multiple versions if it is '
        'compatible with multiple versions. Files that are not tagged at all are '
        'assumed to be valid in all versions of VHDL.')

    parser.add_argument(
        '-v', '--version', metavar='version',
        type=int, default=None,
        help='Target VHDL version, specified as 2-digit or 4-digit year. Default '
        'is mixed-mode. When specified, files that include version tags for only '
        '*other* VHDL versions are filtered out. These version tags are indicated '
        'through *.<version>.* tags in the filename, where <version> is a '
        'two-digit year. Targets that do not support mixing different VHDL '
        'versions require this flag to be set.')

    parser.add_argument(
        '-m', '--mode',
        choices=['sim', 'syn', 'all'], default='sim',
        help='Specifies the target compilation mode. Defaults to sim. This flag '
        'controls a filename filter intended to be used to mark files as '
        'simulation- or synthesis-only: if a VHDL filename matches  *.sim.* it is '
        'considered simulation-only, if it matches *.syn.* it is considered '
        'synthesis-only. Specify -m all to disable this filter.')

    # Output control.
    parser.add_argument(
        '-o', '--outfile',
        default=None,
        help='Output file. If not specified, stdout is used.')

    # Debugging.
    parser.add_argument(
        '--stacktrace',
        action='store_true',
        help='Print complete Python stack traces instead of just the message.')

    # Help information.
    parser.add_argument(
        '--targets',
        action='store_true',
        help='List the supported targets.')

    parser.add_argument(
        '--style',
        action='store_true',
        help='Print information about the VHDL style rules enforced by '
        '--strict.')

    parser.add_argument(
        '--vhdeps-version', action='version', version='vhdeps ' + __version__,
        help='Prints the current version of vhdeps and exits.')

    try:

        # Parse the command line.
        if args is None:
            args = sys.argv[1:]
        if '--' in args:
            index = args.index('--')
            target_args = args[index+1:]
            args = parser.parse_args(args[:index])
        else:
            args, target_args = parser.parse_known_args(args)

        # Print additional information and exit if requested using --targets or
        # --style. --help also falls within this category, but argparse handles
        # that internally.
        if args.targets:
            target_mod.print_help()
            return 0

        if args.style:
            print('The following style rules are enforced by -I/--strict:')
            print(' - Each VHDL file must define exactly one entity or exactly one package.')
            print(' - VHDL package names must use the _pkg suffix.')
            print(' - The filename must match the name of the VHDL entity/package.')
            return 0

        # Select the target.
        if args.target is None:
            print('Error: no target specified.', file=sys.stderr)
            parser.print_usage()
            return 1
        target = target_mod.get_target(args.target)
        if target is None:
            print('Error: unknown target "%s".' % args.target, file=sys.stderr)
            print('Specify --targets to get a listing of all supported targets.', file=sys.stderr)
            return 1

        # Parse the target's arguments, if any.
        target_args = target_mod.get_argument_parser(args.target).parse_args(target_args)

    except SystemExit as exc:
        return exc.code

    # Construct the list of VHDL files.
    vhd_list = vhdl.VhdList(
        mode=args.mode,
        desired_version=args.desired_version,
        required_version=args.version)

    try:
        # Add the specified files/directories to the VHDL file list.
        def add_dir(arglist, **kwargs):
            for arg in arglist:
                arg = arg.split(':', maxsplit=2)
                fname = arg[-1]
                lib = arg[-2] if len(arg) >= 2 else 'work'
                override_version = int(arg[-3]) if len(arg) >= 3 else None
                if '*' in fname or '?' in fname:
                    for match in glob.glob(fname):
                        vhd_list.add_file(
                            match, lib=lib, override_version=override_version, **kwargs)
                elif os.path.isdir(fname):
                    vhd_list.add_dir(
                        fname, lib=lib, override_version=override_version, **kwargs)
                elif os.path.isfile(fname):
                    vhd_list.add_file(
                        fname, lib=lib, override_version=override_version, **kwargs)
                else:
                    raise ValueError('file/directory not found: "%s"' % fname)

        # Default to including the working directory if no includes are specified.
        if not args.include and not args.strict and not args.external:
            print('Including the current working directory recursively by default...',
                  file=sys.stderr)
            args.include.append('.')

        add_dir(args.include)
        add_dir(args.strict, strict=True)
        add_dir(args.external, allow_bb=True)

        if not vhd_list.files:
            print('Warning: no VHDL files found.', file=sys.stderr)
        else:

            # Determine the compile order.
            vhd_list.determine_compile_order(args.entity)

            if not vhd_list.order:
                print('Warning: no design units found.', file=sys.stderr)
            elif not vhd_list.top:
                print('Warning: no toplevel entities found.', file=sys.stderr)

        # Run the selected target with the selected output file or stdout.
        if args.outfile is None:
            code = target.run(vhd_list, sys.stdout, **vars(target_args))
        else:
            with open(args.outfile, 'w') as output_file:
                code = target.run(vhd_list, output_file, **vars(target_args))
        if code is None:
            code = 0
        return code

    except Exception as exc: #pylint: disable=W0703
        if args.stacktrace:
            raise
        print('%s: %s' % (str(type(exc).__name__), str(exc)), file=sys.stderr)
        return 1

    except KeyboardInterrupt as exc:
        if args.stacktrace:
            raise
        return 1

def _init():
    if __name__ == '__main__':
        sys.exit(run_cli())

_init()
