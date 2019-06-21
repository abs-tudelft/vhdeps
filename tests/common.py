"""Common methods shared between test cases."""

import sys
import io
import vhdeps

try:
    import builtins
except ImportError:
    import __builtin__ as builtins

def run_vhdeps(*args):
    """Runs the given vhdeps CLI with mockup `sys.stdout` and `sys.stderr`.
    Returns a three-tuple of the exit code, the captured stdout string, and the
    captured stderr string."""
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

class MockMissingImport:
    """Patches Python's `__import__` function to raise an `ImportError` when
    one of the given module names is loaded."""

    def __init__(self, *names):
        super().__init__()
        self._names = names
        self._real_import = builtins.__import__

    def _patched_import(self, name, *args, **kwargs):
        for disabled_name in self._names:
            if name.startswith(disabled_name):
                raise ImportError(name)
        return self._real_import(name, *args, **kwargs)

    def __enter__(self):
        builtins.__import__ = self._patched_import

    def __exit__(self, *_):
        builtins.__import__ = self._real_import
