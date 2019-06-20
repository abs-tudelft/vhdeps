from unittest import TestCase, skipIf
import os
import sys
import io
import re
import tempfile
from plumbum import local

import vhdeps

workdir = os.path.realpath(os.path.dirname(__file__))

def run_vhdeps(*args):
    orig_out = sys.stdout
    orig_err = sys.stderr
    try:
        sys.stdout = io.StringIO()
        sys.stderr = io.StringIO()
        try:
            code = vhdeps.run_cli(args)
        finally:
            out = sys.stdout.getvalue()
            err = sys.stderr.getvalue()
            print(out, file=orig_out)
            print(err, file=orig_out)
        return code, out, err
    finally:
        sys.stdout = orig_out
        sys.stderr = orig_err

def ghdl_installed():
    try:
        from plumbum.cmd import ghdl
        return True
    except:
        return False

def coverage_supported():
    try:
        from plumbum.cmd import ghdl, gcov, lcov, genhtml
        return 'GCC back-end' in ghdl('--version')
    except:
        return False

@skipIf(not ghdl_installed(), 'missing ghdl')
class TestGhdlSimple(TestCase):

    def test_all_good(self):
        code, out, err = run_vhdeps('ghdl', '-i', workdir+'/simple/all-good')
        self.assertEquals(code, 0)
        self.assertTrue('working!' in out)
        self.assertTrue('PASSED  test_tc' in out)
        self.assertTrue('Test suite PASSED' in out)

    def test_failure(self):
        code, out, err = run_vhdeps('ghdl', '-i', workdir+'/simple/failure')
        self.assertEquals(code, 1)
        self.assertTrue('uh oh!' in out)
        self.assertTrue('FAILED  test_tc' in out)
        self.assertTrue('Test suite FAILED' in out)

    def test_partial_failure(self):
        code, out, err = run_vhdeps('ghdl', '-i', workdir+'/simple/partial-failure')
        self.assertEquals(code, 1)
        self.assertTrue('working!' in out)
        self.assertTrue('uh oh!' in out)
        self.assertTrue('FAILED  fail_tc' in out)
        self.assertTrue('PASSED  pass_tc' in out)
        self.assertTrue('Test suite FAILED' in out)

    def test_timeout(self):
        code, out, err = run_vhdeps('ghdl', '-i', workdir+'/simple/timeout')
        self.assertEquals(code, 1)
        self.assertTrue('TIMEOUT test_tc' in out)
        self.assertTrue('Test suite FAILED' in out)

    def test_error(self):
        code, out, err = run_vhdeps('ghdl', '-i', workdir+'/simple/elab-error')
        self.assertEquals(code, 1)
        self.assertTrue('error during elaboration' in out)
        self.assertTrue('Test suite FAILED' in out)

    def parse_error(self):
        code, out, err = run_vhdeps('ghdl', '-i', workdir+'/simple/parse-error')
        self.assertEquals(code, 1)
        self.assertTrue('error during elaboration' in out)
        self.assertTrue('Test suite FAILED' in out)

    def test_default_timeout_success(self):
        code, out, err = run_vhdeps('ghdl', '-i', workdir+'/simple/default-timeout-success')
        self.assertEquals(code, 0)
        self.assertTrue('Warning: no simulation timeout specified for work.test_tc' in err)
        self.assertTrue('working!' in out)
        self.assertTrue('PASSED  test_tc' in out)
        self.assertTrue('Test suite PASSED' in out)

    def test_default_timeout_too_short(self):
        code, out, err = run_vhdeps('ghdl', '-i', workdir+'/simple/default-timeout-too-short')
        self.assertEquals(code, 1)
        self.assertTrue('Warning: no simulation timeout specified for work.test_tc' in err)
        self.assertTrue('TIMEOUT test_tc' in out)
        self.assertTrue('Test suite FAILED' in out)


@skipIf(not ghdl_installed(), 'missing ghdl')
class TestGhdlSpecific(TestCase):

    def test_multi_version(self):
        code, out, err = run_vhdeps('ghdl', '-i', workdir+'/simple/multi-version')
        self.assertEquals(code, 1)
        self.assertTrue('GHDL does not support mixing VHDL versions.' in err)

    def test_unknown_version(self):
        code, out, err = run_vhdeps('ghdl', '-i', workdir+'/ghdl/unknown-version')
        self.assertEquals(code, 1)
        self.assertTrue('GHDL supports only the following versions:' in err)

    def test_analyze_error(self):
        with local.env(PATH=workdir+'/ghdl/fake-analyze-error:' + local.env['PATH']):
            code, out, err = run_vhdeps('ghdl', '-i', workdir+'/simple/all-good')
        self.assertEquals(code, 2)
        self.assertTrue('dummy ghdl: error' in out)
        self.assertTrue('Analysis failed!' in out)

    def test_elaborate_error(self):
        with local.env(PATH=workdir+'/ghdl/fake-elaborate-error:' + local.env['PATH']):
            code, out, err = run_vhdeps('ghdl', '-i', workdir+'/simple/all-good')
        self.assertEquals(code, 1)
        self.assertTrue('dummy ghdl: error' in out)
        self.assertTrue('ERROR   test_tc' in out)
        self.assertTrue('Test suite FAILED' in out)

    def test_no_tempdir(self):
        with tempfile.TemporaryDirectory() as tempdir:
            with local.cwd(tempdir):
                code, out, err = run_vhdeps('ghdl', '-i', workdir+'/simple/all-good', '--no-tempdir')
            self.assertEquals(code, 0)
            self.assertTrue('work-obj08.cf' in os.listdir(tempdir))

    def test_vcd_dir(self):
        with tempfile.TemporaryDirectory() as tempdir:
            with local.cwd(tempdir):
                code, out, err = run_vhdeps('ghdl', '-i', workdir+'/simple/all-good', '-w', 'wave')
            self.assertEquals(code, 0)
            self.assertTrue('work.test_tc.vcd' in os.listdir(tempdir + '/wave'))

    def test_gtkwave_single_fail(self):
        with tempfile.TemporaryDirectory() as tempdir:
            with local.env(PATH=workdir+'/ghdl/fake-gtkwave:' + local.env['PATH'], GTKWAVE_CMD_LINE=tempdir+'/gtkwave'):
                code, out, err = run_vhdeps('ghdl', '-i', workdir+'/simple/failure', '--gui')
            self.assertEquals(code, 1)
            with open(tempdir+'/gtkwave', 'r') as fildes:
                self.assertTrue('work.test_tc.vcd' in fildes.read())

    def test_gtkwave_single_success(self):
        with tempfile.TemporaryDirectory() as tempdir:
            with local.env(PATH=workdir+'/ghdl/fake-gtkwave:' + local.env['PATH'], GTKWAVE_CMD_LINE=tempdir+'/gtkwave'):
                code, out, err = run_vhdeps('ghdl', '-i', workdir+'/simple/all-good', '--gui')
            self.assertEquals(code, 0)
            with open(tempdir+'/gtkwave', 'r') as fildes:
                self.assertTrue('work.test_tc.vcd' in fildes.read())

    def test_gtkwave_multi_fail(self):
        with tempfile.TemporaryDirectory() as tempdir:
            with local.env(PATH=workdir+'/ghdl/fake-gtkwave:' + local.env['PATH'], GTKWAVE_CMD_LINE=tempdir+'/gtkwave'):
                code, out, err = run_vhdeps('ghdl', '-i', workdir+'/simple/partial-failure', '--gui')
            self.assertEquals(code, 1)
            with open(tempdir+'/gtkwave', 'r') as fildes:
                self.assertTrue('work.fail_tc.vcd' in fildes.read())

    def test_gtkwave_multi_success(self):
        with tempfile.TemporaryDirectory() as tempdir:
            with local.env(PATH=workdir+'/ghdl/fake-gtkwave:' + local.env['PATH'], GTKWAVE_CMD_LINE=tempdir+'/gtkwave'):
                code, out, err = run_vhdeps('ghdl', '-i', workdir+'/simple/multiple-ok', '--gui')
            self.assertEquals(code, 0)
            self.assertTrue('No data available to open gtkwave for.' in out)
            self.assertFalse(os.path.isfile(tempdir+'/gtkwave'))

    def test_parallel_failure(self):
        code, out, err = run_vhdeps('ghdl', '-i', workdir+'/simple/partial-failure', '-j')
        self.assertEquals(code, 1)
        self.assertTrue('working!' in out)
        self.assertTrue('uh oh!' in out)
        self.assertTrue('FAILED  fail_tc' in out)
        self.assertTrue('PASSED  pass_tc' in out)
        self.assertTrue('Test suite FAILED' in out)

    def test_parallel_success(self):
        code, out, err = run_vhdeps('ghdl', '-i', workdir+'/simple/multiple-ok', '-j')
        self.assertEquals(code, 0)
        self.assertTrue('working!' in out)
        self.assertTrue('PASSED  foo_tc' in out)
        self.assertTrue('PASSED  bar_tc' in out)
        self.assertTrue('Test suite PASSED' in out)

    def test_multi_tc_per_file(self):
        code, out, err = run_vhdeps('ghdl', '-i', workdir+'/complex/multi-tc-per-file')
        self.assertEquals(code, 1)
        self.assertTrue('NotImplementedError: vhdeps\' test case runners currently do '
                        'not support having multiple test cases per VHDL file.' in err)


@skipIf(not ghdl_installed(), 'missing ghdl')
@skipIf(not coverage_supported(), 'missing gcov, lcov, or genhtml, or ghdl does not use gcc backend')
class TestGhdlWithCoverage(TestCase):
    def test_gcov(self):
        with tempfile.TemporaryDirectory() as tempdir:
            code, out, err = run_vhdeps('ghdl', '-i', workdir+'/simple/multiple-ok', '-c', '--cover-dir', tempdir)
            self.assertEquals(code, 0)
            print(os.listdir(tempdir))
            self.assertTrue('foo_tc.gcda' in os.listdir(tempdir))
            self.assertTrue('bar_tc.gcda' in os.listdir(tempdir))
            self.assertTrue('foo_tc.gcno' in os.listdir(tempdir))
            self.assertTrue('bar_tc.gcno' in os.listdir(tempdir))

    def test_lcov(self):
        with tempfile.TemporaryDirectory() as tempdir:
            code, out, err = run_vhdeps('ghdl', '-i', workdir+'/simple/multiple-ok', '-clcov', '--cover-dir', tempdir)
            self.assertEquals(code, 0)
            print(os.listdir(tempdir))
            self.assertTrue('coverage.info' in os.listdir(tempdir))

    def test_html(self):
        with tempfile.TemporaryDirectory() as tempdir:
            code, out, err = run_vhdeps('ghdl', '-i', workdir+'/simple/multiple-ok', '-chtml', '--cover-dir', tempdir)
            self.assertEquals(code, 0)
            print(os.listdir(tempdir))
            self.assertTrue('index.html' in os.listdir(tempdir))

class TestPatterns(TestCase):
    def test_no_patterns(self):
        with local.env(PATH=workdir+'/ghdl/fake-ghdl:' + local.env['PATH']):
            code, out, err = run_vhdeps('ghdl', '-i', workdir+'/simple/multiple-ok')
        self.assertEquals(code, 0)
        self.assertTrue(bool(re.search(r'ghdl -a [^\n]*foo_tc.vhd', out)))
        self.assertTrue(bool(re.search(r'ghdl -a [^\n]*bar_tc.vhd', out)))
        self.assertTrue(bool(re.search(r'ghdl -a [^\n]*baz.vhd', out)))
        self.assertTrue(bool(re.search(r'ghdl -e [^\n]*foo_tc', out)))
        self.assertTrue(bool(re.search(r'ghdl -e [^\n]*bar_tc', out)))
        self.assertFalse(bool(re.search(r'ghdl -e [^\n]*baz', out)))
        self.assertTrue(bool(re.search(r'ghdl -r [^\n]*foo_tc', out)))
        self.assertTrue(bool(re.search(r'ghdl -r [^\n]*bar_tc', out)))
        self.assertFalse(bool(re.search(r'ghdl -r [^\n]*baz', out)))

    def test_positive_name(self):
        with local.env(PATH=workdir+'/ghdl/fake-ghdl:' + local.env['PATH']):
            code, out, err = run_vhdeps('ghdl', '-i', workdir+'/simple/multiple-ok', '-pfoo_tc', '-pbaz')
        self.assertEquals(code, 0)
        self.assertTrue(bool(re.search(r'ghdl -a [^\n]*foo_tc.vhd', out)))
        self.assertTrue(bool(re.search(r'ghdl -a [^\n]*bar_tc.vhd', out)))
        self.assertTrue(bool(re.search(r'ghdl -a [^\n]*baz.vhd', out)))
        self.assertTrue(bool(re.search(r'ghdl -e [^\n]*foo_tc', out)))
        self.assertFalse(bool(re.search(r'ghdl -e [^\n]*bar_tc', out)))
        self.assertTrue(bool(re.search(r'ghdl -e [^\n]*baz', out)))
        self.assertTrue(bool(re.search(r'ghdl -r [^\n]*foo_tc', out)))
        self.assertFalse(bool(re.search(r'ghdl -r [^\n]*bar_tc', out)))
        self.assertTrue(bool(re.search(r'ghdl -r [^\n]*baz', out)))

    def test_negative_name(self):
        with local.env(PATH=workdir+'/ghdl/fake-ghdl:' + local.env['PATH']):
            code, out, err = run_vhdeps('ghdl', '-i', workdir+'/simple/multiple-ok', '-p*_tc', '-p!foo*')
        self.assertEquals(code, 0)
        self.assertTrue(bool(re.search(r'ghdl -a [^\n]*foo_tc.vhd', out)))
        self.assertTrue(bool(re.search(r'ghdl -a [^\n]*bar_tc.vhd', out)))
        self.assertTrue(bool(re.search(r'ghdl -a [^\n]*baz.vhd', out)))
        self.assertFalse(bool(re.search(r'ghdl -e [^\n]*foo_tc', out)))
        self.assertTrue(bool(re.search(r'ghdl -e [^\n]*bar_tc', out)))
        self.assertFalse(bool(re.search(r'ghdl -e [^\n]*baz', out)))
        self.assertFalse(bool(re.search(r'ghdl -r [^\n]*foo_tc', out)))
        self.assertTrue(bool(re.search(r'ghdl -r [^\n]*bar_tc', out)))
        self.assertFalse(bool(re.search(r'ghdl -r [^\n]*baz', out)))

    def test_positive_filename(self):
        with local.env(PATH=workdir+'/ghdl/fake-ghdl:' + local.env['PATH']):
            code, out, err = run_vhdeps('ghdl', '-i', workdir+'/simple/multiple-ok', '-p:*_tc.vhd', '-pbaz')
        self.assertEquals(code, 0)
        self.assertTrue(bool(re.search(r'ghdl -a [^\n]*foo_tc.vhd', out)))
        self.assertTrue(bool(re.search(r'ghdl -a [^\n]*bar_tc.vhd', out)))
        self.assertTrue(bool(re.search(r'ghdl -a [^\n]*baz.vhd', out)))
        self.assertTrue(bool(re.search(r'ghdl -e [^\n]*foo_tc', out)))
        self.assertTrue(bool(re.search(r'ghdl -e [^\n]*bar_tc', out)))
        self.assertTrue(bool(re.search(r'ghdl -e [^\n]*baz', out)))
        self.assertTrue(bool(re.search(r'ghdl -r [^\n]*foo_tc', out)))
        self.assertTrue(bool(re.search(r'ghdl -r [^\n]*bar_tc', out)))
        self.assertTrue(bool(re.search(r'ghdl -r [^\n]*baz', out)))

    def test_negative_filename(self):
        with local.env(PATH=workdir+'/ghdl/fake-ghdl:' + local.env['PATH']):
            code, out, err = run_vhdeps('ghdl', '-i', workdir+'/simple/multiple-ok', '-p:*.vhd', '-p:!*baz.vhd')
        self.assertEquals(code, 0)
        self.assertTrue(bool(re.search(r'ghdl -a [^\n]*foo_tc.vhd', out)))
        self.assertTrue(bool(re.search(r'ghdl -a [^\n]*bar_tc.vhd', out)))
        self.assertTrue(bool(re.search(r'ghdl -a [^\n]*baz.vhd', out)))
        self.assertTrue(bool(re.search(r'ghdl -e [^\n]*foo_tc', out)))
        self.assertTrue(bool(re.search(r'ghdl -e [^\n]*bar_tc', out)))
        self.assertFalse(bool(re.search(r'ghdl -e [^\n]*baz', out)))
        self.assertTrue(bool(re.search(r'ghdl -r [^\n]*foo_tc', out)))
        self.assertTrue(bool(re.search(r'ghdl -r [^\n]*bar_tc', out)))
        self.assertFalse(bool(re.search(r'ghdl -r [^\n]*baz', out)))
