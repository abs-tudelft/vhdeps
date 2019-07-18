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
from collections import namedtuple

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

TestCase = namedtuple('TestCase', ('file', 'unit'))

def get_test_cases(vhd_list, pattern=None, **_):
    """Filters the toplevel entities in `vhd_list` using the given pattern
    list, returning the resulting list."""
    if not pattern:
        pattern = ['*_tc']
    test_cases = []
    for top in vhd_list.top:
        for unit in top.entity_defs:
            include = False
            for pat in pattern:
                target = unit
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
                test_cases.append(TestCase(top, unit))
    return test_cases

def run_cmd(output_file, cmd, *args, workdir=None):
    """Runs the given plumbum-style command with the given arguments, sending
    the results to `output_file` (and stderr if `output_file` is `sys.stdout`).
    Returns a three-tuple of the exit code, stdout as a string, and stderr as a
    string."""
    if workdir is None:
        from plumbum import local
        workdir = str(local.cwd)

    if output_file == sys.stdout:
        from subprocess import PIPE
        from select import select
        from plumbum.commands.modifiers import ExecutionModifier
        from plumbum.lib import read_fd_decode_safely

        class TeeWithDir(ExecutionModifier):
            """Like plumbum._TEE, but with a custom working directory for the
            child process."""
            #pylint: disable=R0903

            __slots__ = ('workdir',)

            def __init__(self, workdir):
                """`workdir` is the working directory in which the command
                should run."""
                super().__init__()
                self.workdir = workdir

            def __rand__(self, cmd):
                with cmd.bgrun(
                        retcode=None,
                        stdin=None,
                        stdout=PIPE,
                        stderr=PIPE,
                        cwd=self.workdir) as process:
                    outbuf = []
                    errbuf = []
                    out = process.stdout
                    err = process.stderr
                    buffers = {out: outbuf, err: errbuf}
                    tee_to = {out: sys.stdout, err: sys.stderr}
                    done = False
                    while not done:
                        # After the process exits, we have to do one more
                        # round of reading in order to drain any data in the
                        # pipe buffer. Thus, we check poll() here,
                        # unconditionally enter the read loop, and only then
                        # break out of the outer loop if the process has
                        # exited.
                        done = (process.poll() is not None)

                        # We continue this loop until we've done a full
                        # `select()` call without collecting any input. This
                        # ensures that our final pass -- after process exit --
                        # actually drains the pipe buffers, even if it takes
                        # multiple calls to read().
                        progress = True
                        while progress:
                            progress = False
                            ready, _, _ = select((out, err), (), ())
                            for fildes in ready:
                                buf = buffers[fildes]
                                data, text = read_fd_decode_safely(fildes, 4096)
                                if not data:  # eof
                                    continue
                                progress = True

                                # Python conveniently line-buffers stdout and
                                # stderr for us, so all we need to do is write
                                # to them.

                                # This will automatically add up to three bytes
                                # if it cannot be decoded.
                                tee_to[fildes].write(text)

                                buf.append(data)

                    stdout = ''.join([x.decode('utf-8') for x in outbuf])
                    stderr = ''.join([x.decode('utf-8') for x in errbuf])
                    return process.returncode, stdout, stderr

        exit_code, stdout, stderr = cmd[args] & TeeWithDir(workdir)
    else:
        exit_code, stdout, stderr = cmd[args].run(retcode=None, cwd=workdir)
        output_file.write(stdout + stderr)
    return exit_code, stdout, stderr
