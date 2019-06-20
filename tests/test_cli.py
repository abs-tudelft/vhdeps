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

class TestCommandLine(TestCase):
    def test_no_args(self):
        code, out, err = run_vhdeps()
        self.assertEquals(code, 1)
        self.assertTrue('Error: no target specified.' in err)

    def test_help(self):
        code, out, err = run_vhdeps('--help')
        self.assertEquals(code, 0)
        self.assertTrue('vhdeps <target> [entities...] [flags...] [--] [target-flags...]' in out)

    def test_target_list(self):
        code, out, err = run_vhdeps('--targets')
        self.assertEquals(code, 0)
        self.assertTrue('ghdl' in out)
        self.assertTrue('vsim' in out)
        self.assertTrue('dump' in out)

    def test_target_help(self):
        code, out, err = run_vhdeps('dump', '--', '--help')
        self.assertEquals(code, 0)
        self.assertTrue('Generic compile order output to stdout' in out)

    def test_style_help(self):
        code, out, err = run_vhdeps('--style')
        self.assertEquals(code, 0)
        self.assertTrue('The following style rules are enforced' in out)

    def test_bad_target(self):
        code, out, err = run_vhdeps('not-a-target')
        self.assertEquals(code, 1)
        self.assertTrue('Error: unknown target "not-a-target".' in err)

    def test_bad_path(self):
        code, out, err = run_vhdeps('dump', '-i', 'not-a-path')
        self.assertEquals(code, 1)
        self.assertTrue('ValueError: file/directory not found:' in err)

    def test_empty_path(self):
        code, out, err = run_vhdeps('dump', '-i', workdir+'/simple/empty')
        self.assertEquals(code, 0)
        self.assertTrue('Warning: no VHDL files found.' in err)

    def test_stacktrace(self):
        with self.assertRaises(ValueError):
            run_vhdeps('dump', '-i', 'not-a-path', '--stacktrace')

