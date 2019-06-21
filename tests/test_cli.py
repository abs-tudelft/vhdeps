"""Tests the command-line interface."""

from unittest import TestCase
from unittest.mock import patch
import os
from .common import run_vhdeps

DIR = os.path.realpath(os.path.dirname(__file__))

class TestCommandLine(TestCase):
    """Tests the command-line interface."""

    def test_no_args(self):
        """Test vhdeps CLI with no arguments"""
        code, _, err = run_vhdeps()
        self.assertEqual(code, 1)
        self.assertTrue('Error: no target specified.' in err)

    def test_help(self):
        """Test vhdeps CLI --help switch"""
        code, out, _ = run_vhdeps('--help')
        self.assertEqual(code, 0)
        self.assertTrue('vhdeps <target> [entities...] [flags...] [--] [target-flags...]' in out)

    def test_target_list(self):
        """Test vhdeps CLI --targets switch"""
        code, out, _ = run_vhdeps('--targets')
        self.assertEqual(code, 0)
        self.assertTrue('ghdl' in out)
        self.assertTrue('vsim' in out)
        self.assertTrue('dump' in out)

    def test_target_help(self):
        """Test vhdeps CLI --help switch for targets and -- syntax"""
        code, out, _ = run_vhdeps('dump', '--', '--help')
        self.assertEqual(code, 0)
        self.assertTrue('Generic compile order output to stdout' in out)

    def test_style_help(self):
        """Test vhdeps CLI --style switch"""
        code, out, _ = run_vhdeps('--style')
        self.assertEqual(code, 0)
        self.assertTrue('The following style rules are enforced' in out)

    def test_bad_target(self):
        """Test vhdeps CLI unknown target error"""
        code, _, err = run_vhdeps('not-a-target')
        self.assertEqual(code, 1)
        self.assertTrue('Error: unknown target "not-a-target".' in err)

    def test_bad_path(self):
        """Test vhdeps CLI bad path include error"""
        code, _, err = run_vhdeps('dump', '-i', 'not-a-path')
        self.assertEqual(code, 1)
        self.assertTrue('ValueError: file/directory not found:' in err)

    def test_empty_path(self):
        """Test vhdeps no-files warning"""
        code, _, err = run_vhdeps('dump', '-i', DIR+'/simple/empty')
        self.assertEqual(code, 0)
        self.assertTrue('Warning: no VHDL files found.' in err)

    def test_stacktrace(self):
        """Test vhdeps CLI --stacktrace switch"""
        with self.assertRaises(ValueError):
            run_vhdeps('dump', '-i', 'not-a-path', '--stacktrace')

    def test_interrupt(self):
        """Test the KeyboardInterrupt handler"""
        with patch('vhdeps.vhdl.VhdList.add_dir', side_effect=KeyboardInterrupt):
            code, _, _ = run_vhdeps('dump', '-i', DIR+'/simple/empty')
            self.assertEqual(code, 1)

    def test_interrupt_stacktrace(self):
        """Test the KeyboardInterrupt handler with --stacktrace"""
        with patch('vhdeps.vhdl.VhdList.add_dir', side_effect=KeyboardInterrupt):
            with self.assertRaises(KeyboardInterrupt):
                run_vhdeps('dump', '-i', DIR+'/simple/empty', '--stacktrace')

    def test_no_design_units(self):
        """Test the no design units warning"""
        code, _, err = run_vhdeps('dump', 'nothing', '-i', DIR+'/simple/all-good')
        self.assertEqual(code, 0)
        self.assertTrue('Warning: no design units found.' in err)
