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

"""Runs the given VHDL files as a vhlib test suite using GHDL. Requires GHDL
to be on the system path and that the Plumbum Python library is installed."""

import sys
import tempfile
import fnmatch

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

    parser.add_argument(
        '--ieee', metavar='lib', action='store',
        choices=['standard', 'synopsys', 'mentor', 'none'], default='synopsys',
        help='Specifies which version of the IEEE library to use when compiling. '
        'Options are standard, synopsys, mentor, and none; default is synopsys. '
        'Note that GHDL itself defaults to standard; Synopsys\' implementation '
        'seems to be a bit more lenient in practice, so it seems like the '
        'better choice for a tool that should "just work".')

    parser.add_argument(
        '--no-debug', action='store_true',
        help='Disables generation of debug symbols (adds -g0 switch to GHDL '
        'if passed, instead of the default -g switch).')

    parser.add_argument(
        '--no-tempdir', action='store_true',
        help='Disables cwd\'ing to a temporary working directory.')

    parser.add_argument(
        '--coverage', action='store_true',
        help='EXPERIMENTAL: adds flags to GHDL for generating gcov-style code '
        'coverage data. This only works when GHDL is compiled with the GCC '
        'backend! Combine with --no-tempdir to prevent the output from being '
        'deleted when vhdeps terminates.')

def run(l, f, pattern, ieee, no_debug, no_tempdir, coverage):
    try:
        from plumbum import local, ProcessExecutionError, FG
        from plumbum.cmd import ghdl
    except ImportError:
        raise ImportError('The GHDL backend requires plumbum to be installed (pip3 install plumbum).')

    debug = '-g0' if no_debug else '-g'
    if not pattern:
        pattern = ['*_tc']

    # Make sure all files in the compile order have the same version.
    versions = set()
    for vhd in l.order:
        versions.add(vhd.version)
    if len(versions) > 1:
        raise ValueError('GHDL does not support mixing VHDL versions. Use the -v flag to force one. '
            'The following versions were detected: ' + ', '.join(map(str, sorted(versions))))
    elif versions:
        version = next(iter(versions))
    else:
        version = 2008

    # Convert the version number to a GHDL flag.
    supported_versions = {
        1987: '--std=87',
        1993: '--std=93c',
        2000: '--std=00',
        2002: '--std=02',
        2008: '--std=08',
    }
    std_switch = supported_versions.get(version, None)
    if std_switch is None:
        raise ValueError('GHDL supports only the following versions: ' + ', '.join(map(str, sorted(supported_versions))))

    def run_internal():
        f.write('Analyzing...\n')
        failed = False
        for vhd in l.order:
            cmd = ghdl[
                '-a',
                debug,
                std_switch,
                '--ieee=%s' % ieee,
                '--work=%s' % vhd.lib]
            if coverage:
                cmd = cmd['-Wc,-fprofile-arcs', '-Wc,-ftest-coverage']
            cmd = cmd[vhd.fname]
            rc, stdout, stderr = cmd.run(retcode=None)
            if rc != 0:
                failed = True
            f.write(stdout)
            f.write(stderr)
        if failed:
            f.write('Analysis failed!\n')
            return 2
        summary = []
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
                f.write('Elaborating %s...\n' % top.unit)
                cmd = ghdl[
                    '-e',
                    debug,
                    std_switch,
                    '--ieee=%s' % ieee,
                    '--work=%s' % top.lib]
                if coverage:
                    cmd = cmd['-Wl,-lgcov']
                cmd = cmd[top.unit]
                rc, stdout, stderr = cmd.run(retcode=None)
                f.write(stdout)
                f.write(stderr)
                if rc != 0:
                    f.write('Elaboration for %s failed!\n' % top.unit)
                else:
                    f.write('Running %s...\n' % top.unit)
                    cmd = ghdl[
                        '-r',
                        debug,
                        std_switch,
                        '--ieee=%s' % ieee,
                        '--work=' + top.lib,
                        top.unit,
                        '--stop-time=' + top.get_timeout().replace(' ', '')]
                    rc, stdout, stderr = cmd.run(retcode=None)
                    f.write(stdout)
                    f.write(stderr)
                    if 'simulation stopped by --stop-time' in stdout:
                        summary.append((1, ' * TIMEOUT %s' % top.unit))
                        failed = True
                    elif rc != 0:
                        summary.append((2, ' * FAILED  %s' % top.unit))
                        failed = True
                    else:
                        summary.append((0, ' * PASSED  %s' % top.unit))

        f.write('\nFinal summary:\n' + '\n'.join(map(lambda x: x[1], sorted(summary))) + '\n')
        if failed:
            f.write('Test suite FAILED\n')
            return 1
        else:
            f.write('Test suite PASSED\n')
            return 0

    if no_tempdir:
        return run_internal()
    with tempfile.TemporaryDirectory() as tempdir:
        with local.cwd(tempdir):
            return run_internal()
