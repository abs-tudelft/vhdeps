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

import tempfile
import threading
import queue
import io
import os
from .shared import add_arguments_for_get_test_cases, get_test_cases, run_cmd

def add_arguments(parser):
    """Adds the command-line arguments supported by this target to the given
    `argparse.ArgumentParser` object."""
    add_arguments_for_get_test_cases(parser)

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
        '-c', '--coverage', nargs='?', action='append',
        choices=['gcov', 'lcov', 'html'],
        help='Adds flags to GHDL for generating gcov-style code coverage '
        'data. This only works when GHDL is compiled with the GCC backend! '
        'The coverage files are moved to the directory specified by '
        '--cover-dir, or the working directory if this is not specified. '
        'The file format written depends on the parameter to this switch: '
        '"gcov" copies the .gcno and .gcda files, "lcov" runs lcov in '
        'addition to produce coverage.info and copies that instead, and '
        '"html" calls genhtml to generate HTML output and copies that '
        'instead. Default is "gcov".')

    parser.add_argument(
        '-d', '--cover-dir', action='store', default=None,
        help='Specifies the directory to which the coverage data generated '
        'by -c/--coverage is copied. Defaults to "./coverage".')

    parser.add_argument(
        '-j', '--jobs', metavar='N', nargs='?', action='append', type=int,
        help='Runs the test cases in parallel with the given number of '
        'parallel GHDL runs, or infinite if no argument is specified.')

    parser.add_argument(
        '-w', '--vcd-dir', action='store', default=None,
        help='When specified, waveform data will be captured (*.vcd files) '
        'to the specified output directory.')

    parser.add_argument(
        '--gui', action='store_true',
        help='When specified, vhdeps will launch gtkwave after the test '
        'case(s) complete. If there is a single test case, gtkwave is opened '
        'regardless of whether it passed or not. If there are multiple test '
        'cases, gtkwave is launched for the first failure.')

def _get_ghdl_cmds(vhd_list, ieee='synopsys', no_debug=False, coverage=None, **_):
    """Returns a three-tuple of the analyze, elaborate, and run commands for
    GHDL in plumbum form."""

    # Look for the base GHDL executable.
    try:
        from plumbum.cmd import ghdl
    except ImportError:
        raise ImportError('ghdl was not found.')

    # Make sure all files in the compile order have the same version.
    versions = set()
    for vhd in vhd_list.order:
        versions.add(vhd.version)
    if len(versions) > 1:
        raise ValueError('GHDL does not support mixing VHDL versions. Use the '
                         '-v flag to force one. The following versions were '
                         'detected: ' + ', '.join(map(str, sorted(versions))))
    if versions:
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
        raise ValueError('GHDL supports only the following versions: '
                         + ', '.join(map(str, sorted(supported_versions))))

    # Determine the debug switch.
    debug = '-g0' if no_debug else '-g'

    # Construct the three GHDL commands.
    common_switches = [debug, std_switch, '--ieee=%s' % ieee]
    ghdl_analyze = ghdl['-a'][common_switches]
    ghdl_elaborate = ghdl['-e'][common_switches]
    ghdl_run = ghdl['-r'][common_switches]

    # Add flags for coverage output if requested.
    if coverage:
        ghdl_analyze = ghdl_analyze['-Wc,-fprofile-arcs', '-Wc,-ftest-coverage']
        ghdl_elaborate = ghdl_elaborate['-Wl,-lgcov']

    return ghdl_analyze, ghdl_elaborate, ghdl_run

def _run_test_case(output_file, test_case, vcd_dir, ghdl_elaborate, ghdl_run):
    """Runs the given test case with the given GHDL commands, writing the
    results to `output_file`. Returns a two-tuple of an exit code (higher is
    a worse result, 0 is pass) and a message for the summary."""
    output_file.write('Elaborating %s...\n' % test_case.unit)
    exit_code, *_ = run_cmd(
        output_file,
        ghdl_elaborate,
        '--work=%s' % test_case.lib,
        test_case.unit)
    if exit_code != 0:
        output_file.write('Elaboration for %s failed!\n' % test_case.unit)
        return 3, test_case, None

    output_file.write('Running %s...\n' % test_case.unit)
    vcd_file = None
    vcd_switch = []
    if vcd_dir is not None:
        vcd_file = '%s/%s.%s.vcd' % (
            vcd_dir, test_case.lib, test_case.unit)
        vcd_switch.append('--vcd=%s' % vcd_file)
    exit_code, stdout, *_ = run_cmd(
        output_file,
        ghdl_run,
        '--work=' + test_case.lib, test_case.unit,
        '--stop-time=' + test_case.get_timeout().replace(' ', ''),
        *vcd_switch)
    if 'simulation stopped by --stop-time' in stdout:
        code = 1
    elif exit_code != 0:
        code = 2
    else:
        code = 0
    return code, test_case, vcd_file

def _run(vhd_list, output_file, jobs=None, coverage=None,
         cover_dir=None, vcd_dir=None, gui=False, **kwargs):
    """Runs this backend in the current working directory."""
    from plumbum import local, FG

    # Construct the plumbum command representations of the three GHDL commands
    # we need, complete with all flags that are not file-dependent.
    cmds = _get_ghdl_cmds(vhd_list, coverage=coverage, **kwargs)
    ghdl_analyze, ghdl_elaborate, ghdl_run = cmds

    # Analyze all files with GHDL.
    failed = False
    for index, vhd in enumerate(vhd_list.order):
        output_file.write('Analyzing (%d/%d) %s...\n' % (index+1, len(vhd_list.order), vhd.fname))
        exit_code, _, stderr = run_cmd(
            output_file,
            ghdl_analyze,
            '--work=%s' % vhd.lib,
            vhd.fname)
        if exit_code != 0:
            if 'unknown option \'-Wc' in stderr:
                output_file.write(
                    'GHDL did not understand -Wc option! You need a version '
                    'of GHDL that was\ncompiled with the GCC backend for this '
                    'combination of command-line options.\n')
                return 2
            failed = True
    if failed:
        output_file.write('Analysis failed!\n')
        return 2

    # Construct a list of test cases.
    test_cases = get_test_cases(vhd_list, **kwargs)

    if vcd_dir is not None:
        local['mkdir']('-p', vcd_dir)

    # If the user did not specifically request VCD files but did request the
    # GUI to be opened, default to saving the VCD files in the working
    # directory (which is normally a temporary directory).
    if gui and vcd_dir is None:
        vcd_dir = '.'

    # Run the test cases.
    if jobs is None:

        # Run sequentially.
        results = [
            _run_test_case(
                output_file, test_case, vcd_dir, ghdl_elaborate, ghdl_run)
            for test_case in test_cases]

    else:

        # Run multithreaded.
        pending_test_cases = queue.Queue()
        for test_case in test_cases:
            pending_test_cases.put(test_case)
        result_queue = queue.Queue()
        output_lock = threading.Lock()

        # Worker thread function. Runs test cases until there are no more
        # pending test cases.
        def thread_run():
            try:
                while True:
                    test_case = pending_test_cases.get_nowait()
                    stdout = io.StringIO()
                    result = _run_test_case(
                        stdout, test_case, vcd_dir, ghdl_elaborate, ghdl_run)
                    with output_lock:
                        output_file.write(stdout.getvalue())
                    result_queue.put(result)
                    pending_test_cases.task_done()
            except queue.Empty:
                pass

        # Construct a thread pool to execute the test cases.
        pool = []
        jobs = jobs[-1]
        if not jobs:
            jobs = len(test_cases)
        for _ in range(jobs):
            thread = threading.Thread(target=thread_run)
            thread.start()
            pool.append(thread)

        # Wait for the threads to finish. If we get a keyboard interrupt,
        # remove all the pending test cases from the queue and wait again.
        try:
            pending_test_cases.join()
            for thread in pool:
                thread.join()
        except KeyboardInterrupt:
            try:
                while True:
                    pending_test_cases.get_nowait()
            except queue.Empty:
                pass
            for thread in pool:
                thread.join()
            raise

        # Drain the result queue into a list.
        results = []
        while not result_queue.empty():
            results.append(result_queue.get())
        assert len(results) == len(test_cases)

    # If any of the entries in summary have a nonzero code attached to them,
    # something went wrong.
    failed = any(map(lambda ent: ent[0], results))

    # Print a summary of the test case results.
    output_file.write('\nFinal summary:\n')
    for code, test_case, _ in sorted(results):
        code = {
            0: 'PASSED ',
            1: 'TIMEOUT',
            2: 'FAILED ',
            3: 'ERROR  ',
        }[code]
        output_file.write(' * %s %s\n' % (code, test_case.unit))
    if failed:
        output_file.write('Test suite FAILED\n')
    else:
        output_file.write('Test suite PASSED\n')

    # Copy/interpret coverage data.
    if coverage:
        coverage = coverage[-1]
        if coverage is None:
            coverage = 'gcov'

        local['mkdir']('-p', cover_dir)

        if coverage == 'gcov':
            copy = local['cp']
            if cover_dir != os.getcwd():
                for fname in os.listdir(os.getcwd()):
                    if fname.endswith('.gcda') or fname.endswith('.gcno'):
                        copy('-f', '-t', cover_dir, fname)

        elif coverage == 'lcov':
            local['lcov']('-c', '-d', '.', '-o', cover_dir + os.sep + 'coverage.info')

        elif coverage == 'html':
            local['lcov']('-c', '-d', '.', '-o', 'coverage.info')
            local['genhtml']('-o', cover_dir, 'coverage.info')

        else:
            raise NotImplementedError('coverage output type %s' % coverage)

    # Open GUI if requested.
    if gui:
        vcd_file = None
        if len(results) == 1:
            vcd_file = results[0][2]
        else:
            for code, _, vcd in sorted(results):
                if code and vcd:
                    vcd_file = vcd
                    break
        if vcd_file is None:
            print('No data available to open gtkwave for.')
        else:
            local['gtkwave'][vcd_file] & FG #pylint: disable=W0104

    return int(failed)

def run(vhd_list, output_file, no_tempdir=False, cover_dir=None, vcd_dir=None, **kwargs):
    """Runs this backend."""
    try:
        from plumbum import local
    except ImportError:
        raise ImportError('the GHDL backend requires plumbum to be installed '
                          '(pip3 install plumbum).')

    # Set the default value for the coverage output directory before moving to
    # a temporary working directory.
    if cover_dir is None:
        cover_dir = os.getcwd() + os.sep + 'coverage'
    else:
        cover_dir = os.path.realpath(cover_dir)
    kwargs['cover_dir'] = cover_dir

    # Convert the waveform output directory to an absolute path so it is not
    # affected by running from a temporary directory.
    if vcd_dir is not None:
        vcd_dir = os.path.realpath(vcd_dir)
    kwargs['vcd_dir'] = vcd_dir

    # Run this backend in a temporary working directory unless the user
    # specifically requested that we don't do that.
    if no_tempdir:
        return _run(vhd_list, output_file, **kwargs)
    with tempfile.TemporaryDirectory() as tempdir:
        with local.cwd(tempdir):
            return _run(vhd_list, output_file, **kwargs)
