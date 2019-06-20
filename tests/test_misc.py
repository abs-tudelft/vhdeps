from unittest import TestCase
import os

from vhdeps.vhdl import VhdFile

workdir = os.path.realpath(os.path.dirname(__file__))

class TestVhdFile(TestCase):
    def test_compare_different_types(self):
        vhd = VhdFile(workdir + '/simple/all-good/test_tc.vhd')
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
        fname = 'does-not-exist'
        with self.assertRaisesRegex(RuntimeError, fname):
            VhdFile(fname)
