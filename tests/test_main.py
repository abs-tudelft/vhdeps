from unittest import TestCase, skipIf
import os
import sys
import io
import re
import tempfile
from plumbum import local

def run_vhdeps(mod, *args):
    orig_out = sys.stdout
    orig_err = sys.stderr
    try:
        sys.stdout = io.StringIO()
        sys.stderr = io.StringIO()
        try:
            sys.argv = ['vhdeps']
            sys.argv.extend(args)
            mod.__name__ = '__main__'
            try:
                mod._init()
                code = 0
            except SystemExit as exc:
                code = exc.code
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
    def test_no_args_main(self):
        import vhdeps
        code, out, err = run_vhdeps(vhdeps)
        self.assertEquals(code, 1)
        self.assertTrue('Error: no target specified.' in err)

    def test_help_main(self):
        import vhdeps
        code, out, err = run_vhdeps(vhdeps, '--help')
        self.assertEquals(code, 0)
        self.assertTrue('vhdeps <target> [entities...] [flags...] [--] [target-flags...]' in out)

    def test_no_args_module(self):
        import vhdeps.__main__ as mod
        code, out, err = run_vhdeps(mod)
        self.assertEquals(code, 1)
        self.assertTrue('Error: no target specified.' in err)

    def test_help_module(self):
        import vhdeps.__main__ as mod
        code, out, err = run_vhdeps(mod, '--help')
        self.assertEquals(code, 0)
        self.assertTrue('vhdeps <target> [entities...] [flags...] [--] [target-flags...]' in out)
