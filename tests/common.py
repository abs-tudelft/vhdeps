"""Common methods shared between test cases."""

import sys
import io
import vhdeps

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
