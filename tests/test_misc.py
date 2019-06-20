"""Miscellaneous test cases."""

from unittest import TestCase
import os

from vhdeps.vhdl import VhdFile

DIR = os.path.realpath(os.path.dirname(__file__))

class TestVhdFile(TestCase):
    """Miscellaneous test cases."""

    def test_compare_different_types(self):
        """Test VhdFile comparison with different type"""
        vhd = VhdFile(DIR + '/simple/all-good/test_tc.vhd')
        self.assertFalse(vhd == 'foo')
        self.assertTrue(vhd != 'foo')
        with self.assertRaisesRegex(TypeError, 'str'):
            self.assertFalse(vhd > 'foo')
        with self.assertRaisesRegex(TypeError, 'str'):
            self.assertFalse(vhd >= 'foo')
        with self.assertRaisesRegex(TypeError, 'str'):
            self.assertFalse(vhd < 'foo')
        with self.assertRaisesRegex(TypeError, 'str'):
            self.assertFalse(vhd <= 'foo')

    def test_file_not_found(self):
        """Test VhdFile error message when read fails"""
        fname = 'does-not-exist'
        with self.assertRaisesRegex(RuntimeError, fname):
            VhdFile(fname)
