"""Tests the GHDL backend."""

from unittest import TestCase
import os
import re
from plumbum import local
from .common import run_vhdeps

DIR = os.path.realpath(os.path.dirname(__file__))

class TestPatterns(TestCase):
    """Tests the test case pattern matching logic (also used by the vsim
    backend)."""

    def test_no_patterns(self):
        """Test the default test case pattern (`*.tc`)"""
        with local.env(PATH=DIR+'/ghdl/fake-ghdl:' + local.env['PATH']):
            code, out, _ = run_vhdeps('ghdl', '-i', DIR+'/simple/multiple-ok')
        self.assertEqual(code, 0)
        self.assertTrue(bool(re.search(r'ghdl -a [^\n]*foo_tc.vhd', out)))
        self.assertTrue(bool(re.search(r'ghdl -a [^\n]*bar_tc.vhd', out)))
        self.assertTrue(bool(re.search(r'ghdl -a [^\n]*baz.vhd', out)))
        self.assertTrue(bool(re.search(r'ghdl -e [^\n]*foo_tc', out)))
        self.assertTrue(bool(re.search(r'ghdl -e [^\n]*bar_tc', out)))
        self.assertFalse(bool(re.search(r'ghdl -e [^\n]*baz', out)))
        self.assertTrue(bool(re.search(r'ghdl -r [^\n]*foo_tc', out)))
        self.assertTrue(bool(re.search(r'ghdl -r [^\n]*bar_tc', out)))
        self.assertFalse(bool(re.search(r'ghdl -r [^\n]*baz', out)))

    def test_positive_name(self):
        """Test positive entity name test case patterns"""
        with local.env(PATH=DIR+'/ghdl/fake-ghdl:' + local.env['PATH']):
            code, out, _ = run_vhdeps(
                'ghdl', '-i', DIR+'/simple/multiple-ok', '-pfoo_tc', '-pbaz')
        self.assertEqual(code, 0)
        self.assertTrue(bool(re.search(r'ghdl -a [^\n]*foo_tc.vhd', out)))
        self.assertTrue(bool(re.search(r'ghdl -a [^\n]*bar_tc.vhd', out)))
        self.assertTrue(bool(re.search(r'ghdl -a [^\n]*baz.vhd', out)))
        self.assertTrue(bool(re.search(r'ghdl -e [^\n]*foo_tc', out)))
        self.assertFalse(bool(re.search(r'ghdl -e [^\n]*bar_tc', out)))
        self.assertTrue(bool(re.search(r'ghdl -e [^\n]*baz', out)))
        self.assertTrue(bool(re.search(r'ghdl -r [^\n]*foo_tc', out)))
        self.assertFalse(bool(re.search(r'ghdl -r [^\n]*bar_tc', out)))
        self.assertTrue(bool(re.search(r'ghdl -r [^\n]*baz', out)))

    def test_negative_name(self):
        """Test negative entity name test case patterns"""
        with local.env(PATH=DIR+'/ghdl/fake-ghdl:' + local.env['PATH']):
            code, out, _ = run_vhdeps(
                'ghdl', '-i', DIR+'/simple/multiple-ok', '-p*_tc', '-p!foo*')
        self.assertEqual(code, 0)
        self.assertTrue(bool(re.search(r'ghdl -a [^\n]*foo_tc.vhd', out)))
        self.assertTrue(bool(re.search(r'ghdl -a [^\n]*bar_tc.vhd', out)))
        self.assertTrue(bool(re.search(r'ghdl -a [^\n]*baz.vhd', out)))
        self.assertFalse(bool(re.search(r'ghdl -e [^\n]*foo_tc', out)))
        self.assertTrue(bool(re.search(r'ghdl -e [^\n]*bar_tc', out)))
        self.assertFalse(bool(re.search(r'ghdl -e [^\n]*baz', out)))
        self.assertFalse(bool(re.search(r'ghdl -r [^\n]*foo_tc', out)))
        self.assertTrue(bool(re.search(r'ghdl -r [^\n]*bar_tc', out)))
        self.assertFalse(bool(re.search(r'ghdl -r [^\n]*baz', out)))

    def test_positive_filename(self):
        """Test positive filename test case patterns"""
        with local.env(PATH=DIR+'/ghdl/fake-ghdl:' + local.env['PATH']):
            code, out, _ = run_vhdeps(
                'ghdl', '-i', DIR+'/simple/multiple-ok', '-p:*_tc.vhd', '-pbaz')
        self.assertEqual(code, 0)
        self.assertTrue(bool(re.search(r'ghdl -a [^\n]*foo_tc.vhd', out)))
        self.assertTrue(bool(re.search(r'ghdl -a [^\n]*bar_tc.vhd', out)))
        self.assertTrue(bool(re.search(r'ghdl -a [^\n]*baz.vhd', out)))
        self.assertTrue(bool(re.search(r'ghdl -e [^\n]*foo_tc', out)))
        self.assertTrue(bool(re.search(r'ghdl -e [^\n]*bar_tc', out)))
        self.assertTrue(bool(re.search(r'ghdl -e [^\n]*baz', out)))
        self.assertTrue(bool(re.search(r'ghdl -r [^\n]*foo_tc', out)))
        self.assertTrue(bool(re.search(r'ghdl -r [^\n]*bar_tc', out)))
        self.assertTrue(bool(re.search(r'ghdl -r [^\n]*baz', out)))

    def test_negative_filename(self):
        """Test negative filename test case patterns"""
        with local.env(PATH=DIR+'/ghdl/fake-ghdl:' + local.env['PATH']):
            code, out, _ = run_vhdeps(
                'ghdl', '-i', DIR+'/simple/multiple-ok', '-p:*.vhd', '-p:!*baz.vhd')
        self.assertEqual(code, 0)
        self.assertTrue(bool(re.search(r'ghdl -a [^\n]*foo_tc.vhd', out)))
        self.assertTrue(bool(re.search(r'ghdl -a [^\n]*bar_tc.vhd', out)))
        self.assertTrue(bool(re.search(r'ghdl -a [^\n]*baz.vhd', out)))
        self.assertTrue(bool(re.search(r'ghdl -e [^\n]*foo_tc', out)))
        self.assertTrue(bool(re.search(r'ghdl -e [^\n]*bar_tc', out)))
        self.assertFalse(bool(re.search(r'ghdl -e [^\n]*baz', out)))
        self.assertTrue(bool(re.search(r'ghdl -r [^\n]*foo_tc', out)))
        self.assertTrue(bool(re.search(r'ghdl -r [^\n]*bar_tc', out)))
        self.assertFalse(bool(re.search(r'ghdl -r [^\n]*baz', out)))

    def test_multi_tc_per_file(self):
        """Test multiple test cases per file"""
        with local.env(PATH=DIR+'/ghdl/fake-ghdl:' + local.env['PATH']):
            code, out, _ = run_vhdeps('ghdl', '-i', DIR+'/complex/multi-tc-per-file')
        self.assertEqual(code, 0)
        self.assertTrue(bool(re.search(r'ghdl -a [^\n]*test_tc.vhd', out)))
        self.assertTrue(bool(re.search(r'ghdl -e [^\n]*foo_tc', out)))
        self.assertTrue(bool(re.search(r'ghdl -e [^\n]*bar_tc', out)))
        self.assertFalse(bool(re.search(r'ghdl -e [^\n]*baz', out)))
        self.assertTrue(bool(re.search(r'ghdl -r [^\n]*foo_tc', out)))
        self.assertTrue(bool(re.search(r'ghdl -r [^\n]*bar_tc', out)))
        self.assertFalse(bool(re.search(r'ghdl -r [^\n]*baz', out)))
