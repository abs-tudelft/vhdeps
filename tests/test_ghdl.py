"""Tests the GHDL backend."""

from unittest import TestCase, skipIf
from unittest.mock import patch
import os
import tempfile
from plumbum import local
from .common import run_vhdeps, MockMissingImport

DIR = os.path.realpath(os.path.dirname(__file__))

def ghdl_installed():
    """Returns whether GHDL is installed."""
    try:
        from plumbum.cmd import ghdl #pylint: disable=W0611
        return True
    except ImportError:
        return False

def coverage_supported():
    """Returns whether all the dependencies for producing code coverage with
    GHDL are met."""
    try:
        from plumbum.cmd import ghdl, gcov, lcov, genhtml #pylint: disable=W0611
        import lcov_cobertura #pylint: disable=W0611
        return 'GCC back-end' in ghdl('--version')
    except ImportError:
        return False

@skipIf(not ghdl_installed(), 'missing ghdl')
class TestGhdlSimple(TestCase):
    """Basic tests for the GHDL backend, testing whether the test suite results
    are returned properly."""

    def test_all_good(self):
        """Test that a single passing test case results in success (GHDL)"""
        code, out, _ = run_vhdeps('ghdl', '-i', DIR+'/simple/all-good')
        self.assertEqual(code, 0)
        self.assertTrue('working!' in out)
        self.assertTrue('PASSED  test_tc' in out)
        self.assertTrue('Test suite PASSED' in out)

    def test_failure(self):
        """Test that a single failing test case results in failure (GHDL)"""
        code, out, _ = run_vhdeps('ghdl', '-i', DIR+'/simple/failure')
        self.assertEqual(code, 1)
        self.assertTrue('uh oh!' in out)
        self.assertTrue('FAILED  test_tc' in out)
        self.assertTrue('Test suite FAILED' in out)

    def test_partial_failure(self):
        """Test that a suite with both a passing and a failing test case
        results in failure (GHDL)"""
        code, out, _ = run_vhdeps('ghdl', '-i', DIR+'/simple/partial-failure')
        self.assertEqual(code, 1)
        self.assertTrue('working!' in out)
        self.assertTrue('uh oh!' in out)
        self.assertTrue('FAILED  fail_tc' in out)
        self.assertTrue('PASSED  pass_tc' in out)
        self.assertTrue('Test suite FAILED' in out)

    def test_timeout(self):
        """Test that a timeout results in failure (GHDL)"""
        code, out, _ = run_vhdeps('ghdl', '-i', DIR+'/simple/timeout')
        self.assertEqual(code, 1)
        self.assertTrue('TIMEOUT test_tc' in out)
        self.assertTrue('Test suite FAILED' in out)

    def test_error(self):
        """Test that an elaboration error results in failure (GHDL)"""
        code, out, _ = run_vhdeps('ghdl', '-i', DIR+'/simple/elab-error')
        self.assertEqual(code, 1)
        self.assertTrue('error during elaboration' in out)
        self.assertTrue('Test suite FAILED' in out)

    def parse_error(self):
        """Test that a compile error results in failure (GHDL)"""
        code, out, _ = run_vhdeps('ghdl', '-i', DIR+'/simple/parse-error')
        self.assertEqual(code, 1)
        self.assertTrue('error during elaboration' in out)
        self.assertTrue('Test suite FAILED' in out)

    def test_default_timeout_success(self):
        """Test the default timeout in GHDL (pass)"""
        code, out, err = run_vhdeps('ghdl', '-i', DIR+'/simple/default-timeout-success')
        self.assertEqual(code, 0)
        self.assertTrue('Warning: no simulation timeout specified for work.test_tc' in err)
        self.assertTrue('working!' in out)
        self.assertTrue('PASSED  test_tc' in out)
        self.assertTrue('Test suite PASSED' in out)

    def test_default_timeout_too_short(self):
        """Test the default timeout in GHDL (fail)"""
        code, out, err = run_vhdeps('ghdl', '-i', DIR+'/simple/default-timeout-too-short')
        self.assertEqual(code, 1)
        self.assertTrue('Warning: no simulation timeout specified for work.test_tc' in err)
        self.assertTrue('TIMEOUT test_tc' in out)
        self.assertTrue('Test suite FAILED' in out)

class TestGhdlSpecific(TestCase):
    """Tests more advanced features of the GHDL backend that are
    GHDL-specific."""

    def test_multi_version(self):
        """Test the error message for mixing VHDL versions with GHDL"""
        with local.env(PATH=DIR+'/ghdl/fake-ghdl:' + local.env['PATH']):
            code, _, err = run_vhdeps('ghdl', '-i', DIR+'/simple/multi-version')
        self.assertEqual(code, 1)
        self.assertTrue('GHDL does not support mixing VHDL versions.' in err)

    def test_unknown_version(self):
        """Test the error message for VHDL versions unknown to GHDL"""
        with local.env(PATH=DIR+'/ghdl/fake-ghdl:' + local.env['PATH']):
            code, _, err = run_vhdeps('ghdl', '-i', DIR+'/ghdl/unknown-version')
        self.assertEqual(code, 1)
        self.assertTrue('GHDL supports only the following versions:' in err)

    def test_analyze_error(self):
        """Test the error message for when GHDL analysis fails"""
        with local.env(PATH=DIR+'/ghdl/fake-analyze-error:' + local.env['PATH']):
            code, out, _ = run_vhdeps('ghdl', '-i', DIR+'/simple/all-good')
        self.assertEqual(code, 2)
        self.assertTrue('dummy ghdl: error' in out)
        self.assertTrue('Analysis failed!' in out)

    def test_elaborate_error(self):
        """Test the error message for when GHDL elaboration fails"""
        with local.env(PATH=DIR+'/ghdl/fake-elaborate-error:' + local.env['PATH']):
            code, out, _ = run_vhdeps('ghdl', '-i', DIR+'/simple/all-good')
        self.assertEqual(code, 1)
        self.assertTrue('dummy ghdl: error' in out)
        self.assertTrue('ERROR   test_tc' in out)
        self.assertTrue('Test suite FAILED' in out)

    def test_no_wc(self):
        """Test the error message for when GHDL does not understand -Wc"""
        with local.env(PATH=DIR+'/ghdl/fake-wc-error:' + local.env['PATH']):
            code, out, _ = run_vhdeps('ghdl', '-i', DIR+'/simple/all-good', '-c')
        self.assertEqual(code, 2)
        self.assertTrue('GHDL did not understand -Wc option! You need a version '
                        'of GHDL that was\ncompiled with the GCC backend' in out)

    def test_no_ghdl(self):
        """Test the error message that is generated when ghdl is missing"""
        with local.env(PATH=''):
            code, _, err = run_vhdeps('ghdl', '-i', DIR+'/simple/all-good')
            self.assertEqual(code, 1)
            self.assertTrue('ghdl was not found.' in err)

    def test_no_plumbum(self):
        """Test the error message that is generated when plumbum is missing"""
        with MockMissingImport('plumbum'):
            code, _, err = run_vhdeps('ghdl', '-i', DIR+'/simple/all-good')
            self.assertEqual(code, 1)
            self.assertTrue('the GHDL backend requires plumbum to be installed' in err)

    @skipIf(not ghdl_installed(), 'missing ghdl')
    def test_no_tempdir(self):
        """Test the --no-tempdir flag for GHDL"""
        with tempfile.TemporaryDirectory() as tempdir:
            with local.cwd(tempdir):
                code, _, _ = run_vhdeps('ghdl', '-i', DIR+'/simple/all-good', '--no-tempdir')
            self.assertEqual(code, 0)
            self.assertTrue('work-obj08.cf' in os.listdir(tempdir))

    @skipIf(not ghdl_installed(), 'missing ghdl')
    def test_vcd_dir(self):
        """Test VCD output with GHDL"""
        with tempfile.TemporaryDirectory() as tempdir:
            with local.cwd(tempdir):
                code, _, _ = run_vhdeps('ghdl', '-i', DIR+'/simple/all-good', '-w', 'wave')
            self.assertEqual(code, 0)
            self.assertTrue('work.test_tc.vcd' in os.listdir(tempdir + '/wave'))

    @skipIf(not ghdl_installed(), 'missing ghdl')
    def test_gtkwave_single_fail(self):
        """Test launching gtkwave for a single test case that fails"""
        with tempfile.TemporaryDirectory() as tempdir:
            with local.env(PATH=DIR+'/ghdl/fake-gtkwave:' + local.env['PATH'],
                           GTKWAVE_CMD_LINE=tempdir+'/gtkwave'):
                code, _, _ = run_vhdeps('ghdl', '-i', DIR+'/simple/failure', '--gui')
            self.assertEqual(code, 1)
            with open(tempdir+'/gtkwave', 'r') as fildes:
                self.assertTrue('work.test_tc.vcd' in fildes.read())

    @skipIf(not ghdl_installed(), 'missing ghdl')
    def test_gtkwave_single_success(self):
        """Test launching gtkwave for a single test case that passes"""
        with tempfile.TemporaryDirectory() as tempdir:
            with local.env(PATH=DIR+'/ghdl/fake-gtkwave:' + local.env['PATH'],
                           GTKWAVE_CMD_LINE=tempdir+'/gtkwave'):
                code, _, _ = run_vhdeps('ghdl', '-i', DIR+'/simple/all-good', '--gui')
            self.assertEqual(code, 0)
            with open(tempdir+'/gtkwave', 'r') as fildes:
                self.assertTrue('work.test_tc.vcd' in fildes.read())

    @skipIf(not ghdl_installed(), 'missing ghdl')
    def test_gtkwave_multi_fail(self):
        """Test launching gtkwave for a test suite with a failure"""
        with tempfile.TemporaryDirectory() as tempdir:
            with local.env(PATH=DIR+'/ghdl/fake-gtkwave:' + local.env['PATH'],
                           GTKWAVE_CMD_LINE=tempdir+'/gtkwave'):
                code, _, _ = run_vhdeps('ghdl', '-i', DIR+'/simple/partial-failure', '--gui')
            self.assertEqual(code, 1)
            with open(tempdir+'/gtkwave', 'r') as fildes:
                self.assertTrue('work.fail_tc.vcd' in fildes.read())

    @skipIf(not ghdl_installed(), 'missing ghdl')
    def test_gtkwave_multi_success(self):
        """Test NOT launching gtkwave for a test suite that passes"""
        with tempfile.TemporaryDirectory() as tempdir:
            with local.env(PATH=DIR+'/ghdl/fake-gtkwave:' + local.env['PATH'],
                           GTKWAVE_CMD_LINE=tempdir+'/gtkwave'):
                code, out, _ = run_vhdeps('ghdl', '-i', DIR+'/simple/multiple-ok', '--gui')
            self.assertEqual(code, 0)
            self.assertTrue('No data available to open gtkwave for.' in out)
            self.assertFalse(os.path.isfile(tempdir+'/gtkwave'))

    @skipIf(not ghdl_installed(), 'missing ghdl')
    def test_parallel_failure(self):
        """Test GHDL parallel elab/execute with a failing test suite"""
        code, out, _ = run_vhdeps('ghdl', '-i', DIR+'/simple/partial-failure', '-j')
        self.assertEqual(code, 1)
        self.assertTrue('working!' in out)
        self.assertTrue('uh oh!' in out)
        self.assertTrue('FAILED  fail_tc' in out)
        self.assertTrue('PASSED  pass_tc' in out)
        self.assertTrue('Test suite FAILED' in out)

    @skipIf(not ghdl_installed(), 'missing ghdl')
    def test_parallel_success(self):
        """Test GHDL parallel elab/execute with a passing test suite"""
        code, out, _ = run_vhdeps('ghdl', '-i', DIR+'/simple/multiple-ok', '-j')
        self.assertEqual(code, 0)
        self.assertTrue('working!' in out)
        self.assertTrue('PASSED  foo_tc' in out)
        self.assertTrue('PASSED  bar_tc' in out)
        self.assertTrue('Test suite PASSED' in out)

    @skipIf(not ghdl_installed(), 'missing ghdl')
    def test_parallel_interrupt(self):
        """Test GHDL parallel elab/execute interrupted with ctrl+C"""
        with patch('queue.Queue.join', side_effect=KeyboardInterrupt):
            code, _, _ = run_vhdeps('ghdl', '-i', DIR+'/simple/multiple-ok', '-j')
            self.assertEqual(code, 1)


@skipIf(
    not coverage_supported(),
    'missing gcov, lcov, genhtml, or lcov_cobertura, or ghdl with gcc backend')
class TestGhdlWithCoverage(TestCase):
    """Tests the code coverage features of the GHDL backend."""

    def test_cobertura(self):
        """Test writing Cobertura coverage data with GHDL"""
        with tempfile.TemporaryDirectory() as tempdir:
            code, _, _ = run_vhdeps(
                'ghdl',
                '-i', DIR+'/simple/multiple-ok',
                '-c', '--cover-dir', tempdir)
            self.assertEqual(code, 0)
            print(os.listdir(tempdir))
            self.assertTrue('coverage.xml' in os.listdir(tempdir))

    def test_no_lcov_cobertura(self):
        """Test the error message that is generated when lcov_cobertura is missing"""
        with MockMissingImport('lcov_cobertura'):
            with tempfile.TemporaryDirectory() as tempdir:
                code, _, err = run_vhdeps(
                    'ghdl',
                    '-i', DIR+'/simple/multiple-ok',
                    '-c', '--cover-dir', tempdir)
                self.assertEqual(code, 1)
                self.assertTrue(
                    'ImportError: the GHDL backend requires lcov_cobertura to '
                    'generate Cobertura XML coverage data' in err)

    def test_gcov(self):
        """Test writing gcov coverage data with GHDL"""
        with tempfile.TemporaryDirectory() as tempdir:
            code, _, _ = run_vhdeps(
                'ghdl',
                '-i', DIR+'/simple/multiple-ok',
                '-cgcov', '--cover-dir', tempdir)
            self.assertEqual(code, 0)
            print(os.listdir(tempdir))
            self.assertTrue('foo_tc.gcda' in os.listdir(tempdir))
            self.assertTrue('bar_tc.gcda' in os.listdir(tempdir))
            self.assertTrue('foo_tc.gcno' in os.listdir(tempdir))
            self.assertTrue('bar_tc.gcno' in os.listdir(tempdir))

    def test_lcov(self):
        """Test writing lcov coverage data with GHDL"""
        with tempfile.TemporaryDirectory() as tempdir:
            code, _, _ = run_vhdeps(
                'ghdl',
                '-i', DIR+'/simple/multiple-ok',
                '-clcov', '--cover-dir', tempdir)
            self.assertEqual(code, 0)
            print(os.listdir(tempdir))
            self.assertTrue('coverage.info' in os.listdir(tempdir))

    def test_html(self):
        """Test writing coverage data in HTML form with GHDL"""
        with tempfile.TemporaryDirectory() as tempdir:
            code, _, _ = run_vhdeps(
                'ghdl',
                '-i', DIR+'/simple/multiple-ok',
                '-chtml', '--cover-dir', tempdir)
            self.assertEqual(code, 0)
            print(os.listdir(tempdir))
            self.assertTrue('index.html' in os.listdir(tempdir))
