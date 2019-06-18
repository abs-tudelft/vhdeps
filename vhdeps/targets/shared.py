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

"""Contains some utilty functions that are used in multiple targets."""

import sys
import fnmatch

def add_arguments_for_get_test_cases(parser):
    """Adds the appropriate command line arguments for the `get_test_cases()`
    function to work to the given `argparse.ArgumentParser` object."""
    parser.add_argument(
        '-p', '--pattern', metavar='pat', action='append',
        help='Specifies a pattern used to filter which toplevel entities are '
        'actually simulated. Patterns work glob-style and are applied in the '
        'sequence in which they are specified, by default operating on entity '
        'names. If a pattern starts with \'!\', entities matched previously '
        'that also match this pattern are excluded. If a pattern starts with '
        '\':\', the filename is matched instead. \':!\' combines the two. '
        'Note that the patterns match the *entire* entity name/absolute '
        'filename, so make sure to prefix/suffix an asterisk if you want a '
        'partial match. If no patterns are specified, the matcher defaults to '
        'a single \'*_tc\' pattern.')

def get_test_cases(vhd_list, pattern=None, **_):
    """Filters the toplevel entities in `vhd_list` using the given pattern
    list, returning the resulting list."""
    if not pattern:
        pattern = ['*_tc']
    test_cases = []
    for top in vhd_list.top:
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
            test_cases.append(top)
    return test_cases

def run_cmd(output_file, cmd, *args):
    """Runs the given plumbum-style command with the given arguments, sending
    the results to `output_file` (and stderr if `output_file` is `sys.stdout`).
    Returns a three-tuple of the exit code, stdout as a string, and stderr as a
    string."""
    if output_file == sys.stdout:
        from plumbum.commands.modifiers import _TEE
        exit_code, stdout, stderr = cmd[args] & _TEE(retcode=None)
    else:
        exit_code, stdout, stderr = cmd[args].run(retcode=None)
        output_file.write(stdout + stderr)
    return exit_code, stdout, stderr
