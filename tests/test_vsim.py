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

def vsim_installed():
    try:
        from plumbum.cmd import vsim
        return True
    except:
        return False

@skipIf(not vsim_installed(), 'missing vsim')
class TestVsimReal(TestCase):

    def test_all_good(self):
        code, out, err = run_vhdeps('vsim', '-i', workdir+'/simple/all-good')
        self.assertEquals(code, 0)
        self.assertTrue('working!' in out)

    def test_failure(self):
        code, out, err = run_vhdeps('vsim', '-i', workdir+'/simple/failure')
        self.assertNotEqual(code, 0)
        self.assertTrue('uh oh!' in out)

    def test_timeout(self):
        code, out, err = run_vhdeps('vsim', '-i', workdir+'/simple/timeout')
        self.assertNotEqual(code, 0)

    def test_error(self):
        code, out, err = run_vhdeps('vsim', '-i', workdir+'/simple/elab-error')
        self.assertNotEqual(code, 0)

    def parse_error(self):
        code, out, err = run_vhdeps('vsim', '-i', workdir+'/simple/parse-error')
        self.assertNotEqual(code, 0)

    def test_default_timeout_success(self):
        code, out, err = run_vhdeps('vsim', '-i', workdir+'/simple/default-timeout-success')
        self.assertEquals(code, 0)

    def test_default_timeout_too_short(self):
        code, out, err = run_vhdeps('vsim', '-i', workdir+'/simple/default-timeout-too-short')
        self.assertNotEqual(code, 0)

    def test_multiple_ok(self):
        code, out, err = run_vhdeps('vsim', '-i', workdir+'/simple/multiple-ok')
        self.assertEquals(code, 0)
        self.assertTrue('working!' in out)
        self.assertTrue('PASSED work.foo_tc' in out)
        self.assertTrue('PASSED work.bar_tc' in out)
        self.assertTrue('2/2 test(s) passed' in out)

    def test_partial_failure(self):
        code, out, err = run_vhdeps('vsim', '-i', workdir+'/simple/partial-failure')
        self.assertEquals(code, 1)
        self.assertTrue('working!' in out)
        self.assertTrue('uh oh!' in out)
        self.assertTrue('FAILED work.fail_tc' in out)
        self.assertTrue('PASSED work.pass_tc' in out)
        self.assertTrue('1/2 test(s) passed' in out)

class TestVsimMocked(TestCase):
    def test_tcl_single(self):
        code, out, err = run_vhdeps('vsim', '--tcl', '-i', workdir+'/simple/all-good')
        self.assertEquals(code, 0)
        self.assertTrue('simulate work test_tc' in out)

    def test_tcl_multi(self):
        code, out, err = run_vhdeps('vsim', '--tcl', '-i', workdir+'/simple/multi-version')
        self.assertEquals(code, 0)
        self.assertTrue('add_source {' + workdir + '/simple/multi-version/bar_tc.08.vhd} {-quiet -work work -2008}' in out)
        self.assertTrue('add_source {' + workdir + '/simple/multi-version/foo_tc.93.vhd} {-quiet -work work -93}' in out)
        self.assertTrue('lappend testcases [list work bar_tc "1 ms"]' in out)
        self.assertTrue('lappend testcases [list work foo_tc "1 ms"]' in out)
        self.assertTrue('regression' in out)

    def test_tcl_versions(self):
        code, out, err = run_vhdeps('vsim', '--tcl', '-i', workdir+'/vsim/supported-versions')
        self.assertEquals(code, 0)
        self.assertTrue('add_source {' + workdir + '/vsim/supported-versions/a.87.vhd} {-quiet -work work -87}' in out)
        self.assertTrue('add_source {' + workdir + '/vsim/supported-versions/b.93.vhd} {-quiet -work work -93}' in out)
        self.assertTrue('add_source {' + workdir + '/vsim/supported-versions/c.02.vhd} {-quiet -work work -2002}' in out)
        self.assertTrue('add_source {' + workdir + '/vsim/supported-versions/test_tc.08.vhd} {-quiet -work work -2008}' in out)
        self.assertTrue('lappend testcases [list work test_tc "3 ms"]' in out)
        self.assertTrue('simulate work test_tc "3 ms"' in out)

    def test_tcl_to_file(self):
        with tempfile.TemporaryDirectory() as tempdir:
            code, out, err = run_vhdeps('vsim', '--tcl', '-i', workdir+'/simple/all-good', '-o', tempdir + '/sim.do')
            self.assertEquals(code, 0)
            self.assertTrue(os.path.isfile(tempdir + '/sim.do'))

    def test_tcl_unsupported_version(self):
        code, out, err = run_vhdeps('vsim', '--tcl', '-i', workdir+'/vsim/unsupported-version')
        self.assertEquals(code, 1)
        self.assertTrue('VHDL version 2012 is not supported' in err)

    @skipIf(vsim_installed(), 'vsim is installed')
    def test_no_vsim(self):
        code, out, err = run_vhdeps('vsim', '-i', workdir+'/simple/all-good')
        self.assertEquals(code, 1)
        self.assertTrue('no vsim-compatible simulator was found.' in err)

    def test_gui_tempdir(self):
        with local.env(PATH=workdir+'/vsim/fake-vsim:' + local.env['PATH']):
            with tempfile.TemporaryDirectory() as tempdir:
                with local.cwd(tempdir):
                    code, out, err = run_vhdeps('vsim', '--gui', '-i', workdir+'/simple/all-good')
                    self.assertEquals(code, 0)
                    self.assertTrue('executing do file' in out)
                    self.assertFalse('vsim.do' in os.listdir(tempdir))
                    self.assertFalse('vsim.log' in os.listdir(tempdir))

    def test_gui_no_tempdir(self):
        with local.env(PATH=workdir+'/vsim/fake-vsim:' + local.env['PATH']):
            with tempfile.TemporaryDirectory() as tempdir:
                with local.cwd(tempdir):
                    code, out, err = run_vhdeps('vsim', '--gui', '--no-tempdir', '-i', workdir+'/simple/all-good')
                    self.assertEquals(code, 0)
                    self.assertTrue('executing do file' in out)
                    with open(tempdir + '/vsim.log', 'r') as log_fildes:
                        with open(tempdir + '/vsim.do', 'r') as do_fildes:
                            self.assertEquals(log_fildes.read(), do_fildes.read())

    def test_batch_no_tempdir(self):
        with local.env(PATH=workdir+'/vsim/fake-vsim:' + local.env['PATH']):
            with tempfile.TemporaryDirectory() as tempdir:
                with local.cwd(tempdir):
                    code, out, err = run_vhdeps('vsim', '--no-tempdir', '-i', workdir+'/simple/all-good')
                    self.assertEquals(code, 0)
                    self.assertTrue('executing from stdin' in out)
                    with open(tempdir + '/vsim.log', 'r') as log_fildes:
                        self.assertTrue('simulate work test_tc' in log_fildes.read())
