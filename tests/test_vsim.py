"""Tests the vsim backend."""

from unittest import TestCase, skipIf
import os
import tempfile
from plumbum import local
from .common import run_vhdeps, MockMissingImport

DIR = os.path.realpath(os.path.dirname(__file__))

def vsim_installed():
    """Returns whether vsim is installed."""
    try:
        from plumbum.cmd import vsim #pylint: disable=W0611
        return True
    except ImportError:
        return False

@skipIf(not vsim_installed(), 'missing vsim')
class TestVsimReal(TestCase):
    """Tests the vsim backend by actually invoking vsim and checking the test
    suite result."""

    def test_all_good(self):
        """Test running vsim on a single passing test case"""
        code, out, _ = run_vhdeps('vsim', '-i', DIR+'/simple/all-good')
        self.assertEqual(code, 0)
        self.assertTrue('working!' in out)

    def test_multiple_per_file(self):
        """Test running vsim on a file with multiple test cases"""
        code, out, _ = run_vhdeps('ghdl', '-i', DIR+'/complex/multi-tc-per-file')
        self.assertEqual(code, 0)
        self.assertTrue('working!' in out)

    def test_failure(self):
        """Test running vsim on a single failing test case"""
        code, out, _ = run_vhdeps('vsim', '-i', DIR+'/simple/failure')
        self.assertNotEqual(code, 0)
        self.assertTrue('uh oh!' in out)

    def test_timeout(self):
        """Test running vsim on a single test case that times out"""
        code, _, _ = run_vhdeps('vsim', '-i', DIR+'/simple/timeout')
        self.assertNotEqual(code, 0)

    def test_error(self):
        """Test running vsim on a single test case that failes to
        elaborate"""
        code, _, _ = run_vhdeps('vsim', '-i', DIR+'/simple/elab-error')
        self.assertNotEqual(code, 0)

    def parse_error(self):
        """Test running vsim on a single test case that failes to compile"""
        code, _, _ = run_vhdeps('vsim', '-i', DIR+'/simple/parse-error')
        self.assertNotEqual(code, 0)

    def test_default_timeout_success(self):
        """Test running vsim on a single test case that does not have a
        timeout specified, but succeeds within 1 ms"""
        code, _, _ = run_vhdeps('vsim', '-i', DIR+'/simple/default-timeout-success')
        self.assertEqual(code, 0)

    def test_default_timeout_too_short(self):
        """Test running vsim on a single test case that does not have a
        timeout specified and takes longer than that to complete"""
        code, _, _ = run_vhdeps('vsim', '-i', DIR+'/simple/default-timeout-too-short')
        self.assertNotEqual(code, 0)

    def test_multiple_ok(self):
        """Test running vsim on a test suite with multiple test cases that all
        succeed"""
        code, out, _ = run_vhdeps('vsim', '-i', DIR+'/simple/multiple-ok')
        self.assertEqual(code, 0)
        self.assertTrue('working!' in out)
        self.assertTrue('PASSED work.foo_tc' in out)
        self.assertTrue('PASSED work.bar_tc' in out)
        self.assertTrue('2/2 test(s) passed' in out)

    def test_partial_failure(self):
        """Test running vsim on a test suite with multiple test cases of which
        one fails"""
        code, out, _ = run_vhdeps('vsim', '-i', DIR+'/simple/partial-failure')
        self.assertEqual(code, 1)
        self.assertTrue('working!' in out)
        self.assertTrue('uh oh!' in out)
        self.assertTrue('FAILED work.fail_tc' in out)
        self.assertTrue('PASSED work.pass_tc' in out)
        self.assertTrue('1/2 test(s) passed' in out)

class TestVsimMocked(TestCase):
    """Tests the vsim backend without calling a real vsim."""

    def test_tcl_single(self):
        """Test TCL output for a single test case to stdout"""
        code, out, _ = run_vhdeps('vsim', '--tcl', '-i', DIR+'/simple/all-good')
        self.assertEqual(code, 0)
        self.assertTrue('simulate work test_tc' in out)

    def test_tcl_multi(self):
        """Test TCL output for a test suite to stdout"""
        code, out, _ = run_vhdeps('vsim', '--tcl', '-i', DIR+'/simple/multi-version')
        self.assertEqual(code, 0)
        self.assertTrue('add_source {' + DIR + '/simple/multi-version/bar_tc.08.vhd} '
                        '{-quiet -work work -2008}' in out)
        self.assertTrue('add_source {' + DIR + '/simple/multi-version/foo_tc.93.vhd} '
                        '{-quiet -work work -93}' in out)
        self.assertTrue('lappend testcases [list work bar_tc "1 ms"]' in out)
        self.assertTrue('lappend testcases [list work foo_tc "1 ms"]' in out)
        self.assertTrue('regression' in out)

    def test_tcl_versions(self):
        """Test TCL output for a test suite with mixed VHDL versions to
        stdout"""
        code, out, _ = run_vhdeps('vsim', '--tcl', '-i', DIR+'/vsim/supported-versions')
        self.assertEqual(code, 0)
        self.assertTrue('add_source {' + DIR + '/vsim/supported-versions/a.87.vhd} '
                        '{-quiet -work work -87}' in out)
        self.assertTrue('add_source {' + DIR + '/vsim/supported-versions/b.93.vhd} '
                        '{-quiet -work work -93}' in out)
        self.assertTrue('add_source {' + DIR + '/vsim/supported-versions/c.02.vhd} '
                        '{-quiet -work work -2002}' in out)
        self.assertTrue('add_source {' + DIR + '/vsim/supported-versions/test_tc.08.vhd} '
                        '{-quiet -work work -2008}' in out)
        self.assertTrue('lappend testcases [list work test_tc "3 ms"]' in out)
        self.assertTrue('simulate work test_tc "3 ms"' in out)

    def test_tcl_to_file(self):
        """Test TCL output to a file"""
        with tempfile.TemporaryDirectory() as tempdir:
            code, _, _ = run_vhdeps(
                'vsim', '--tcl',
                '-i', DIR+'/simple/all-good',
                '-o', tempdir + '/sim.do')
            self.assertEqual(code, 0)
            self.assertTrue(os.path.isfile(tempdir + '/sim.do'))

    def test_unsupported_version(self):
        """Test unsupported VHDL versions"""
        code, _, err = run_vhdeps('vsim', '--tcl', '-i', DIR+'/vsim/unsupported-version')
        self.assertEqual(code, 1)
        self.assertTrue('VHDL version 2012 is not supported' in err)

    def test_no_vsim(self):
        """Test the error message that is generated when vsim is missing"""
        with local.env(PATH=''):
            code, _, err = run_vhdeps('vsim', '-i', DIR+'/simple/all-good')
            self.assertEqual(code, 1)
            self.assertTrue('no vsim-compatible simulator was found.' in err)

    def test_no_plumbum(self):
        """Test the error message that is generated when plumbum is missing"""
        with MockMissingImport('plumbum'):
            code, _, err = run_vhdeps('vsim', '-i', DIR+'/simple/all-good')
            self.assertEqual(code, 1)
            self.assertTrue('the vsim backend requires plumbum to be installed' in err)

    def test_gui_tempdir(self):
        """Test running (a fake) vsim in GUI mode in a temporary directory"""
        with local.env(PATH=DIR+'/vsim/fake-vsim:' + local.env['PATH']):
            with tempfile.TemporaryDirectory() as tempdir:
                with local.cwd(tempdir):
                    code, out, _ = run_vhdeps('vsim', '--gui', '-i', DIR+'/simple/all-good')
                    self.assertEqual(code, 0)
                    self.assertTrue('executing do file' in out)
                    self.assertFalse('vsim.do' in os.listdir(tempdir))
                    self.assertFalse('vsim.log' in os.listdir(tempdir))

    def test_gui_no_tempdir(self):
        """Test running (a fake) vsim in GUI mode in the working directory"""
        with local.env(PATH=DIR+'/vsim/fake-vsim:' + local.env['PATH']):
            with tempfile.TemporaryDirectory() as tempdir:
                with local.cwd(tempdir):
                    code, out, _ = run_vhdeps(
                        'vsim', '--gui', '--no-tempdir', '-i', DIR+'/simple/all-good')
                    self.assertEqual(code, 0)
                    self.assertTrue('executing do file' in out)
                    with open(tempdir + '/vsim.log', 'r') as log_fildes:
                        with open(tempdir + '/vsim.do', 'r') as do_fildes:
                            self.assertEqual(log_fildes.read(), do_fildes.read())

    def test_batch_no_tempdir(self):
        """Test running (a fake) vsim in batch mode in the working
        directory"""
        with local.env(PATH=DIR+'/vsim/fake-vsim:' + local.env['PATH']):
            with tempfile.TemporaryDirectory() as tempdir:
                with local.cwd(tempdir):
                    code, out, _ = run_vhdeps('vsim', '--no-tempdir', '-i', DIR+'/simple/all-good')
                    self.assertEqual(code, 0)
                    self.assertTrue('executing from stdin' in out)
                    with open(tempdir + '/vsim.log', 'r') as log_fildes:
                        self.assertTrue('simulate work test_tc' in log_fildes.read())
