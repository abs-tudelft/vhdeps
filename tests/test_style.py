"""Tests the style rules (-I flag)."""

from unittest import TestCase
import os
from .common import run_vhdeps

DIR = os.path.realpath(os.path.dirname(__file__))

class TestStyle(TestCase):
    """Tests the style rules (-I flag)."""

    def test_correct(self):
        """Test input that passes all style checks"""
        code, _, _ = run_vhdeps('dump', '-I', DIR + '/style/correct')
        self.assertEqual(code, 0)

    def test_package_suffix_enforce(self):
        """Test the error message for a missing _pkg suffix"""
        code, _, err = run_vhdeps('dump', '-I', DIR + '/style/missing-pkg-suffix')
        self.assertEqual(code, 1)
        self.assertTrue('test_pk.vhd contains package without _pkg prefix' in err)

    def test_package_suffix_ignore(self):
        """Test ignoring a missing _pkg suffix when including non-strictly"""
        code, _, _ = run_vhdeps('dump', '-i', DIR + '/style/missing-pkg-suffix')
        self.assertEqual(code, 0)

    def test_multi_design_enforce(self):
        """Test the error message for having multiple design units per
        file"""
        code, _, err = run_vhdeps('dump', '-I', DIR + '/style/multi-design')
        self.assertEqual(code, 1)
        self.assertTrue('test_tc.vhd contains multiple or zero design units' in err)

    def test_multi_design_ignore(self):
        """Test ignoring a multiple design units per file when including
        non-strictly"""
        code, _, _ = run_vhdeps('dump', '-i', DIR + '/style/multi-design')
        self.assertEqual(code, 0)

    def test_wrong_filename_enforce(self):
        """Test the error message for an inconsistent filename"""
        code, _, err = run_vhdeps('dump', '-I', DIR + '/style/wrong-filename')
        self.assertEqual(code, 1)
        self.assertTrue('Filename does not match design unit for' in err)

    def test_wrong_filename_ignore(self):
        """Test ignoring an inconsistent filename when including
        non-strictly"""
        code, _, _ = run_vhdeps('dump', '-i', DIR + '/style/wrong-filename')
        self.assertEqual(code, 0)
