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

class TestStyle(TestCase):
    def test_correct(self):
        code, out, err = run_vhdeps('dump', '-I', workdir + '/style/correct')
        self.assertEquals(code, 0)

    def test_package_suffix_enforce(self):
        code, out, err = run_vhdeps('dump', '-I', workdir + '/style/missing-pkg-suffix')
        self.assertEquals(code, 1)
        self.assertTrue('test_pk.vhd contains package without _pkg prefix' in err)

    def test_package_suffix_ignore(self):
        code, out, err = run_vhdeps('dump', '-i', workdir + '/style/missing-pkg-suffix')
        self.assertEquals(code, 0)

    def test_multi_design_enforce(self):
        code, out, err = run_vhdeps('dump', '-I', workdir + '/style/multi-design')
        self.assertEquals(code, 1)
        self.assertTrue('test_tc.vhd contains multiple or zero design units' in err)

    def test_multi_design_ignore(self):
        code, out, err = run_vhdeps('dump', '-i', workdir + '/style/multi-design')
        self.assertEquals(code, 0)

    def test_wrong_filename_enforce(self):
        code, out, err = run_vhdeps('dump', '-I', workdir + '/style/wrong-filename')
        self.assertEquals(code, 1)
        self.assertTrue('Filename does not match design unit for' in err)

    def test_wrong_filename_ignore(self):
        code, out, err = run_vhdeps('dump', '-i', workdir + '/style/wrong-filename')
        self.assertEquals(code, 0)
