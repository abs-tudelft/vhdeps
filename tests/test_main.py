"""Tests the vhdeps module when run as __main__."""

from unittest import TestCase
import sys
import io

def run_vhdeps_main(mod, *args):
    """Runs the given vhdeps module as `'__main__'` with mockup `sys.stdout`,
    `sys.stderr`, and `sys.argv`, while capturing the exit code from any
    resulting `SystemExit`. Returns a three-tuple of the exit code, the
    captured stdout string, and the captured stderr string."""
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
                mod._init() #pylint: disable=W0212
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

class TestMain(TestCase):
    """Tests the vhdeps module when run as __main__."""

    def test_no_args_main(self):
        """Test `vhdeps` without arguments (exit code 1)"""
        import vhdeps #pylint: disable=C0415
        code, _, err = run_vhdeps_main(vhdeps)
        self.assertEqual(code, 1)
        self.assertTrue('Error: no target specified.' in err)

    def test_help_main(self):
        """Test `vhdeps` with the --help argument (exit code 0)"""
        import vhdeps #pylint: disable=C0415
        code, out, _ = run_vhdeps_main(vhdeps, '--help')
        self.assertEqual(code, 0)
        self.assertTrue('vhdeps <target> [entities...] [flags...] [--] [target-flags...]' in out)

    def test_no_args_module(self):
        """Test `vhdeps.__main__` without arguments (exit code 1)"""
        import vhdeps.__main__ as mod #pylint: disable=C0415
        code, _, err = run_vhdeps_main(mod)
        self.assertEqual(code, 1)
        self.assertTrue('Error: no target specified.' in err)

    def test_help_module(self):
        """Test `vhdeps.__main__` with the --help argument (exit code 0)"""
        import vhdeps.__main__ as mod #pylint: disable=C0415
        code, out, _ = run_vhdeps_main(mod, '--help')
        self.assertEqual(code, 0)
        self.assertTrue('vhdeps <target> [entities...] [flags...] [--] [target-flags...]' in out)
