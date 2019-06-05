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

def run(l, f):
    try:
        from plumbum import local, ProcessExecutionError, FG
        from plumbum.cmd import ghdl
    except ImportError:
        raise ImportError('The GHDL backend requires plumbum to be installed (pip3 install plumbum).')

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

    f.write('Analyzing...\n')
    failed = False
    for vhd in l.order:
        rc, stdout, stderr = (ghdl
                              ['-a']['-g']['--work=' + vhd.lib]
                              [std_switch]['--ieee=synopsys']
                              [vhd.fname]
                              ).run(retcode=None)
        if rc != 0:
            failed = True
        f.write(stdout)
        f.write(stderr)
    if failed:
        f.write('Analysis failed!\n')
        return 2
    summary = []
    for top in l.top:
        if top.unit.endswith('_tc'):
            f.write('Elaborating %s...\n' % top.unit)
            rc, stdout, stderr = (ghdl
                                  ['-e']['-g']['--work=' + top.lib]
                                  [std_switch]['--ieee=synopsys'][top.unit]
                                  ).run(retcode=None)
            f.write(stdout)
            f.write(stderr)
            if rc != 0:
                f.write('Elaboration for %s failed!\n' % top.unit)
            else:
                f.write('Running %s...\n' % top.unit)
                rc, stdout, stderr = (ghdl
                                      ['-r']['-g']['--work=' + top.lib]
                                      [std_switch]['--ieee=synopsys'][top.unit]
                                      ['--stop-time=' + top.get_timeout().replace(' ', '')]
                                      ).run(retcode=None)
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

