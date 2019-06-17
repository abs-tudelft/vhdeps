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

from vhdeps.vhdl import *
from vhdeps.target import *

def run_cli():
    import sys
    import argparse

    parser = argparse.ArgumentParser(
        usage='%s [flags] <sim/synth target> [toplevel ...] [-- <target-args>]' % sys.argv[0],
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
        help='Recursively includes (paths containing) arbitrary VHDL files. If '
        'lib is specified, it marks that files must be compiled into the '
        'specified library name instead of the default (work). If version is '
        'specified, all files in the directory are assumed to have the given '
        'VHDL version, regardless of version tags in the filenames.')

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

    # Parse the command line.
    args = sys.argv
    target_args = []
    if '--' in args:
        index = args.index('--')
        target_args = args[index+1:]
        args = args[:index]
    args = parser.parse_args(args[1:])

    # Print additional information and exit if requested using --targets or
    # --style. --help also falls within this category, but argparse handles
    # that internally.
    if args.targets:
        print_targets()
        sys.exit(0)

    if args.style:
        print('The following style rules are enforced by -I/--strict:')
        print(' - Each VHDL file must define exactly one entity or exactly one package.')
        print(' - VHDL package names must use the _pkg suffix.')
        print(' - The filename must match the name of the VHDL entity/package.')
        sys.exit(0)

    # Select the target.
    if args.target is None:
        print('Error: no target specified.', file=sys.stderr)
        parser.print_usage()
        sys.exit(1)
    target = get_target(args.target)

    # Parse the target's arguments, if any.
    target_parser = argparse.ArgumentParser(
        prog='%s %s ... --' % (sys.argv[0], args.target),
        description=target.__doc__)
    if hasattr(target, 'add_arguments'):
        target.add_arguments(target_parser)
    target_args = target_parser.parse_args(target_args)

    # Construct the list of VHDL files.
    l = VhdList(
        mode=args.mode,
        desired_version=args.desired_version,
        required_version=args.version)

    try:
        # Add the specified files/directories to the VHDL file list.
        def add_dir(arglist, **kwargs):
            for p in arglist:
                p = p.split(':', maxsplit=2)
                fname   = p[-1]
                lib     = p[-2] if len(p) >= 2 else 'work'
                override_version = int(p[-3]) if len(p) >= 3 else None
                if os.path.isdir(fname):
                    l.add_dir(fname, lib, override_version=override_version, **kwargs)
                else:
                    l.add_file(fname, lib, override_version=override_version, **kwargs)

        # Default to including the working directory if no includes are specified.
        if not args.include and not args.strict and not args.external:
            print('Including the current working directory recursively by default...', file=sys.stderr)
            args.include.append('.')

        add_dir(args.include)
        add_dir(args.strict, strict=True)
        add_dir(args.external, allow_bb=True)

        # Determine the compile order.
        l.determine_compile_order(args.entity)

        if not l.order:
            print('Error: no VHDL files found.', file=sys.stderr)
            sys.exit(1)

        # Run the selected target with the selected output file or stdout.
        if args.outfile is None:
            code = target.run(l, sys.stdout, **vars(target_args))
        else:
            with open(args.outfile, 'w') as f:
                code = target.run(l, f, **vars(target_args))
        if code is None:
            code = 0
        sys.exit(code)

    except Exception as e:
        if args.stacktrace:
            raise
        print('%s: %s' % (str(type(e).__name__), str(e)), file=sys.stderr)
        sys.exit(-1)

    except KeyboardInterrupt as e:
        if args.stacktrace:
            raise
        sys.exit(-1)

if __name__ == '__main__':
    run_cli()
