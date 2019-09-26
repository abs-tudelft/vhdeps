"""Tests the dependency analyzer and `dump` backend."""

from unittest import TestCase
import os
import tempfile
from plumbum import local
from .common import run_vhdeps

DIR = os.path.realpath(os.path.dirname(__file__))

class TestDump(TestCase):
    """Tests the dependency analyzer and `dump` backend."""

    def test_basic(self):
        """Test basic functionality of the dump backend"""
        code, out, _ = run_vhdeps('dump', '-i', DIR + '/simple/multiple-ok')
        self.assertEqual(code, 0)
        self.assertEqual(out, '\n'.join([
            'top work 2008 ' + DIR + '/simple/multiple-ok/bar_tc.vhd',
            'top work 2008 ' + DIR + '/simple/multiple-ok/baz.vhd',
            'top work 2008 ' + DIR + '/simple/multiple-ok/foo_tc.vhd',
        ]) + '\n')

    def test_to_file(self):
        """Test outputting a dependency dump to a file"""
        with tempfile.TemporaryDirectory() as tempdir:
            code, _, _ = run_vhdeps(
                'dump',
                '-i', DIR + '/simple/multiple-ok',
                '-o', tempdir+'/output')
            self.assertEqual(code, 0)
            with open(tempdir+'/output', 'r') as fildes:
                self.assertEqual(fildes.read(), '\n'.join([
                    'top work 2008 ' + DIR + '/simple/multiple-ok/bar_tc.vhd',
                    'top work 2008 ' + DIR + '/simple/multiple-ok/baz.vhd',
                    'top work 2008 ' + DIR + '/simple/multiple-ok/foo_tc.vhd',
                ]) + '\n')

    def test_default_include(self):
        """Test implicit working directory inclusion"""
        with local.cwd(DIR + '/simple/multiple-ok'):
            code, out, err = run_vhdeps('dump')
        self.assertEqual(code, 0)
        self.assertTrue('Including the current working directory recursively by default' in err)
        self.assertEqual(out, '\n'.join([
            'top work 2008 ' + DIR + '/simple/multiple-ok/bar_tc.vhd',
            'top work 2008 ' + DIR + '/simple/multiple-ok/baz.vhd',
            'top work 2008 ' + DIR + '/simple/multiple-ok/foo_tc.vhd',
        ]) + '\n')

    def test_default_include_by_file(self):
        """Test including files instead of directories"""
        code, out, _ = run_vhdeps(
            'dump',
            '-i', DIR + '/simple/multiple-ok',
            '-i', DIR + '/simple/all-good/test_tc.vhd')
        self.assertEqual(code, 0)
        self.assertEqual(out, '\n'.join([
            'top work 2008 ' + DIR + '/simple/multiple-ok/bar_tc.vhd',
            'top work 2008 ' + DIR + '/simple/multiple-ok/baz.vhd',
            'top work 2008 ' + DIR + '/simple/multiple-ok/foo_tc.vhd',
            'top work 2008 ' + DIR + '/simple/all-good/test_tc.vhd',
        ]) + '\n')

    def test_default_include_by_glob(self):
        """Test including files using glob syntax"""
        code, out, _ = run_vhdeps(
            'dump',
            '-i', DIR + '/simple/multiple-ok/ba*.vhd')
        self.assertEqual(code, 0)
        self.assertEqual(out, '\n'.join([
            'top work 2008 ' + DIR + '/simple/multiple-ok/bar_tc.vhd',
            'top work 2008 ' + DIR + '/simple/multiple-ok/baz.vhd',
        ]) + '\n')

    def test_default_filters(self):
        """Test the default version/mode filters"""
        code, out, _ = run_vhdeps('dump', '-i', DIR + '/simple/filtering')
        self.assertEqual(code, 0)
        self.assertEqual(out, '\n'.join([
            'top work 2008 ' + DIR + '/simple/filtering/new.08.vhd',
            'top work 1993 ' + DIR + '/simple/filtering/old.93.vhd',
            'top work 2008 ' + DIR + '/simple/filtering/simulation.sim.vhd',
        ]) + '\n')

    def test_fixed_version_1993(self):
        """Test the required version filter"""
        code, out, _ = run_vhdeps('dump', '-i', DIR + '/simple/filtering', '-v93')
        self.assertEqual(code, 0)
        self.assertEqual(out, '\n'.join([
            'top work 1993 ' + DIR + '/simple/filtering/old.93.vhd',
            'top work 1993 ' + DIR + '/simple/filtering/simulation.sim.vhd',
        ]) + '\n')

    def test_desired_version(self):
        """Test the desired version filter"""
        code, out, _ = run_vhdeps('dump', '-i', DIR + '/simple/filtering', '-d93')
        self.assertEqual(code, 0)
        self.assertEqual(out, '\n'.join([
            'top work 2008 ' + DIR + '/simple/filtering/new.08.vhd',
            'top work 1993 ' + DIR + '/simple/filtering/old.93.vhd',
            'top work 1993 ' + DIR + '/simple/filtering/simulation.sim.vhd',
        ]) + '\n')

    def test_synthesis(self):
        """Test the synthesis filter"""
        code, out, _ = run_vhdeps('dump', '-i', DIR + '/simple/filtering', '-msyn')
        self.assertEqual(code, 0)
        self.assertEqual(out, '\n'.join([
            'top work 2008 ' + DIR + '/simple/filtering/new.08.vhd',
            'top work 1993 ' + DIR + '/simple/filtering/old.93.vhd',
            'top work 2008 ' + DIR + '/simple/filtering/synthesis.syn.vhd',
        ]) + '\n')

    def test_no_filtering(self):
        """Test all filters disabled"""
        code, out, _ = run_vhdeps('dump', '-i', DIR + '/simple/filtering', '-mall')
        self.assertEqual(code, 0)
        self.assertEqual(out, '\n'.join([
            'top work 2008 ' + DIR + '/simple/filtering/new.08.vhd',
            'top work 1993 ' + DIR + '/simple/filtering/old.93.vhd',
            'top work 2008 ' + DIR + '/simple/filtering/simulation.sim.vhd',
            'top work 2008 ' + DIR + '/simple/filtering/synthesis.syn.vhd',
        ]) + '\n')

    def test_selected_entities(self):
        """Test toplevel entity selection"""
        code, out, _ = run_vhdeps('dump', 'new', 'old', '-i', DIR + '/simple/filtering')
        self.assertEqual(code, 0)
        self.assertEqual(out, '\n'.join([
            'top work 2008 ' + DIR + '/simple/filtering/new.08.vhd',
            'top work 1993 ' + DIR + '/simple/filtering/old.93.vhd',
        ]) + '\n')

    def test_selected_entity_glob(self):
        """Test toplevel entity selection with fnmatch globs"""
        code, out, _ = run_vhdeps('dump', 's*', '-i', DIR + '/simple/filtering')
        self.assertEqual(code, 0)
        self.assertEqual(out, '\n'.join([
            'top work 2008 ' + DIR + '/simple/filtering/simulation.sim.vhd',
        ]) + '\n')

    def test_selected_entity_no_match(self):
        """Test toplevel entity selection with globs that don't match
        anything"""
        code, out, err = run_vhdeps('dump', 's*', 'x*', '-i', DIR + '/simple/filtering')
        self.assertEqual(code, 0)
        self.assertTrue('Warning: work.x* did not match anything.' in err)
        self.assertEqual(out, '\n'.join([
            'top work 2008 ' + DIR + '/simple/filtering/simulation.sim.vhd',
        ]) + '\n')

    def test_conflict(self):
        """Test conflicting entities (defined in multiple files)"""
        code, _, err = run_vhdeps(
            'dump',
            '-i', DIR + '/simple/all-good',
            '-i', DIR + '/simple/timeout')
        self.assertEqual(code, 1)
        self.assertTrue('ResolutionError: entity work.test_tc is defined in '
                        'multiple, ambiguous files:' in err)

    def test_ignore_pragmas(self):
        """Test ignore-use pragmas"""
        code, _, _ = run_vhdeps('dump', '-i', DIR + '/complex/ignore-use')
        self.assertEqual(code, 0)

    def test_missing_package(self):
        """Test missing package detection/error"""
        code, _, err = run_vhdeps('dump', '-i', DIR + '/complex/vhlib/util/UtilMem64_pkg.vhd')
        self.assertEqual(code, 1)
        self.assertTrue('complex/vhlib/util/UtilMem64_pkg.vhd' in err)
        self.assertTrue('could not find package work.utilstr_pkg' in err)

    def test_missing_component(self):
        """Test missing component detection/error"""
        code, _, err = run_vhdeps('dump', '-i', DIR + '/complex/missing-component')
        self.assertEqual(code, 1)
        self.assertTrue('could not find component declaration for missing' in err)

    def test_black_box_enforce(self):
        """Test black box detection/error"""
        code, _, err = run_vhdeps(
            'dump',
            '-i', DIR + '/complex/vhlib/util',
            '-i', DIR + '/complex/vhlib/stream/Stream_pkg.vhd',
            '-i', DIR + '/complex/vhlib/stream/StreamBuffer.vhd')
        self.assertEqual(code, 1)
        self.assertTrue('complex/vhlib/stream/StreamBuffer.vhd' in err)
        self.assertTrue('black box: could not find entity work.streamfifo' in err)

    def test_black_box_ignore(self):
        """Test ignoring a black box through the -x flag"""
        code, _, _ = run_vhdeps(
            'dump',
            '-i', DIR + '/complex/vhlib/util',
            '-x', DIR + '/complex/vhlib/stream/Stream_pkg.vhd',
            '-i', DIR + '/complex/vhlib/stream/StreamBuffer.vhd')
        self.assertEqual(code, 0)

    def test_missing_filtered(self):
        """Test detection of missing dependencies due to active filters"""
        code, _, err = run_vhdeps('dump', '-i', DIR + '/complex/missing-filtered')
        self.assertEqual(code, 1)
        self.assertTrue('entity work.synth_only is defined, but only in files '
                        'that were filtered out:' in err)
        self.assertTrue('synth_only.syn.vhd is synthesis-only' in err)

    def test_libraries(self):
        """Test multiple libraries"""
        code, out, _ = run_vhdeps(
            'dump',
            '-i', DIR + '/simple/all-good',
            '-i', 'timeout:' + DIR + '/simple/timeout')
        self.assertEqual(code, 0)
        self.assertEqual(out, '\n'.join([
            'top timeout 2008 ' + DIR + '/simple/timeout/test_tc.vhd',
            'top work 2008 ' + DIR + '/simple/all-good/test_tc.vhd',
        ]) + '\n')

    def test_version_override(self):
        """Test version overrides in the include flag"""
        code, out, _ = run_vhdeps(
            'dump',
            '-i', DIR + '/simple/all-good',
            '-i', '93:timeout:' + DIR + '/simple/timeout')
        self.assertEqual(code, 0)
        self.assertEqual(out, '\n'.join([
            'top timeout 1993 ' + DIR + '/simple/timeout/test_tc.vhd',
            'top work 2008 ' + DIR + '/simple/all-good/test_tc.vhd',
        ]) + '\n')

    def test_ambiguous_08(self):
        """Test disambiguation by default desired version"""
        code, out, _ = run_vhdeps('dump', '-i', DIR + '/simple/ambiguous')
        self.assertEqual(code, 0)
        self.assertEqual(out, '\n'.join([
            'top work 2008 ' + DIR + '/simple/ambiguous/test.08.sim.vhd',
        ]) + '\n')

    def test_ambiguous_93(self):
        """Test disambiguation by specific desired version"""
        code, out, _ = run_vhdeps('dump', '-i', DIR + '/simple/ambiguous', '-d', '93')
        self.assertEqual(code, 0)
        self.assertEqual(out, '\n'.join([
            'top work 1993 ' + DIR + '/simple/ambiguous/test.93.sim.vhd',
        ]) + '\n')

    def test_ambiguous_syn(self):
        """Test disambiguation by synthesis vs. simulation mode"""
        code, out, _ = run_vhdeps('dump', '-i', DIR + '/simple/ambiguous', '-m', 'syn')
        self.assertEqual(code, 0)
        self.assertEqual(out, '\n'.join([
            'top work 2008 ' + DIR + '/simple/ambiguous/test.syn.vhd',
        ]) + '\n')

    def test_component_circle(self):
        """Test recursive instantiation using components"""
        code, out, _ = run_vhdeps('dump', '-i', DIR + '/complex/component-circle')
        self.assertEqual(code, 0)
        self.assertEqual(out, '\n'.join([
            'dep work 2008 ' + DIR + '/complex/component-circle/a.vhd',
            'dep work 2008 ' + DIR + '/complex/component-circle/b.vhd',
        ]) + '\n')

    def test_component_in_inst(self):
        """Test component keyword in instantiation"""
        code, out, _ = run_vhdeps('dump', '-i', DIR + '/complex/component-in-inst')
        self.assertEqual(code, 0)
        self.assertEqual(out, '\n'.join([
            'top work 2008 ' + DIR + '/complex/component-in-inst/a.vhd',
            'dep work 2008 ' + DIR + '/complex/component-in-inst/b.vhd',
        ]) + '\n')

    def test_entity_circle(self):
        """Test the error message for a true circular dependency"""
        code, _, err = run_vhdeps('dump', '-i', DIR + '/complex/entity-circle')
        self.assertEqual(code, 1)
        self.assertTrue('ResolutionError: circular dependency:' in err)

    def test_multi_unit_circle(self):
        """Test circular dependencies caused by multiple design units per
        file"""
        code, _, err = run_vhdeps('dump', '-i', DIR + '/complex/multi-unit-circle')
        self.assertEqual(code, 1)
        self.assertTrue('ResolutionError: circular dependency:' in err)

    def test_multi_unit_design(self):
        """Test dependency analysis when multiple entities are defined per
        file"""
        code, out, _ = run_vhdeps('dump', '-i', DIR + '/complex/multi-unit-design')
        self.assertEqual(code, 0)
        self.assertEqual(out, '\n'.join([
            'dep work 2008 ' + DIR + '/complex/multi-unit-design/ab.vhd',
            'dep work 2008 ' + DIR + '/complex/multi-unit-design/cd.vhd',
            'top work 2008 ' + DIR + '/complex/multi-unit-design/test_tc.vhd',
        ]) + '\n')

    def test_multi_tc_per_file(self):
        """Test the dump backend with multiple test cases per file"""
        code, out, _ = run_vhdeps('dump', '-i', DIR + '/complex/multi-tc-per-file')
        self.assertEqual(code, 0)
        self.assertEqual(out, '\n'.join([
            'top work 2008 ' + DIR + '/complex/multi-tc-per-file/test_tc.vhd',
        ]) + '\n')

    def test_vhlib_default(self):
        """Test the dependency analyzer with vhlib, default filters"""
        #pylint: disable=C0301
        self.maxDiff = None #pylint: disable=C0103
        code, out, _ = run_vhdeps('dump', '-i', DIR + '/complex/vhlib')
        self.assertEqual(code, 0)
        self.assertEqual(out, '\n'.join([
            'dep work 2008 ' + DIR + '/complex/vhlib/sim/TestCase_pkg.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/sim/SimDataComms_pkg.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/sim/SimDataComms_tc.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/model/StreamMonitor_pkg.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/model/StreamSource_pkg.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/model/StreamSink_pkg.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamArb/StreamArb_tv.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/Stream_pkg.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/sim/ClockGen_pkg.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamArb/StreamArb_tb.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamArb/StreamArb_Fixed_tc.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamArb/StreamArb_RoundRobin_tc.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamArb/StreamArb_RRSticky_tc.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/StreamArb.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamBuffer/StreamBuffer_tv.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamBuffer/StreamBuffer_tb.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamBuffer/StreamBuffer_0_tc.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamBuffer/StreamBuffer_200_tc.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamBuffer/StreamBuffer_2_tc.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamBuffer/StreamBuffer_4_tc.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamBuffer/StreamBuffer_6_tc.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/util/UtilInt_pkg.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamElementCounter/StreamElementCounter_tv.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamElementCounter/StreamElementCounter_tb.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamElementCounter/StreamElementCounter_16_5_32_9_tc.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamElementCounter/StreamElementCounter_8_3_63_6_tc.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/StreamElementCounter.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamFIFO/StreamFIFO_tv.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamFIFO/StreamFIFO_tb.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamFIFO/StreamFIFO_Increase_tc.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamFIFO/StreamFIFO_Reduce_tc.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamFIFO/StreamFIFO_Same_tc.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamGearbox/StreamGearbox_tv.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamGearbox/StreamGearbox_tb.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamGearbox/StreamGearbox_2_2_8_3_tc.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamGearbox/StreamGearbox_32_5_16_4_tc.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamGearbox/StreamGearbox_5_4_3_2_tc.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamGearbox/StreamGearbox_8_4_8_3_tc.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/StreamGearbox.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/StreamGearboxParallelizer.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/StreamGearboxSerializer.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/StreamNormalizer.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamNormalizer/StreamNormalizer_tb.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamNormalizer/StreamNormalizer_tc.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/util/UtilMisc_pkg.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/StreamPipelineBarrel.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamPipelineBarrel/StreamPipelineBarrel_tb.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamPipelineBarrel/StreamPipelineBarrel_tc.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamPipelineControl/StreamPipelineControl_tv.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamPipelineControl/StreamPipelineControl_tb.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamPipelineControl/StreamPipelineControl_20_3_t_tc.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamPipelineControl/StreamPipelineControl_5_1_f_tc.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/StreamPrefixSum.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamPrefixSum/StreamPrefixSum_tb.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamPrefixSum/StreamPrefixSum_tc.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamPRNG/StreamPRNG_tv.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamPRNG/StreamPRNG_tb.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamPRNG/StreamPRNG_12_tc.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamPRNG/StreamPRNG_8_tc.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/StreamPRNG.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamReshaper/StreamReshaperCtrl_tv.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamReshaper/StreamReshaperCtrl_tb.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamReshaper/StreamReshaperCtrl_1_1_7_3_tc.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamReshaper/StreamReshaperCtrl_4_3_4_3_tc.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamReshaper/StreamReshaperCtrl_8_3_4_2_tc.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamReshaper/StreamReshaperLast_tv.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamReshaper/StreamReshaperLast_tb.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamReshaper/StreamReshaperLast_1_1_7_3_tc.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamReshaper/StreamReshaperLast_4_3_4_3_tc.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamReshaper/StreamReshaperLast_8_3_4_2_tc.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/StreamPipelineControl.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/StreamFIFOCounter.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/util/UtilRam_pkg.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/StreamFIFO.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/StreamBuffer.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/StreamReshaper.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamSink/StreamSink_tc.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/StreamSlice.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamSlice/StreamSlice_tb.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamSlice/StreamSlice_tc.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamSource/StreamSource_tc.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/model/StreamSource_mdl.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/model/StreamMonitor_mdl.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/model/StreamSink_mdl.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/StreamSync.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/sim/ClockGen_mdl.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamSync/StreamSync_tb.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamSync/StreamSync_tc.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/util/UtilRam1R1W.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/util/UtilConv_pkg.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/util/UtilStr_pkg.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/util/UtilMem64_pkg.vhd',
        ]) + '\n')

    def test_vhlib_93_desired(self):
        """Test the dependency analyzer with vhlib, preferring v93"""
        #pylint: disable=C0301
        self.maxDiff = None #pylint: disable=C0103
        code, out, _ = run_vhdeps('dump', '-i', DIR + '/complex/vhlib', '-d', '93')
        self.assertEqual(code, 0)
        self.assertEqual(out, '\n'.join([
            'dep work 2008 ' + DIR + '/complex/vhlib/sim/TestCase_pkg.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/sim/SimDataComms_pkg.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/sim/SimDataComms_tc.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/model/StreamMonitor_pkg.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/model/StreamSource_pkg.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/model/StreamSink_pkg.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamArb/StreamArb_tv.sim.08.vhd',
            'dep work 1993 ' + DIR + '/complex/vhlib/stream/Stream_pkg.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/sim/ClockGen_pkg.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamArb/StreamArb_tb.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamArb/StreamArb_Fixed_tc.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamArb/StreamArb_RoundRobin_tc.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamArb/StreamArb_RRSticky_tc.sim.08.vhd',
            'dep work 1993 ' + DIR + '/complex/vhlib/stream/StreamArb.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamBuffer/StreamBuffer_tv.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamBuffer/StreamBuffer_tb.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamBuffer/StreamBuffer_0_tc.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamBuffer/StreamBuffer_200_tc.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamBuffer/StreamBuffer_2_tc.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamBuffer/StreamBuffer_4_tc.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamBuffer/StreamBuffer_6_tc.sim.08.vhd',
            'dep work 1993 ' + DIR + '/complex/vhlib/util/UtilInt_pkg.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamElementCounter/StreamElementCounter_tv.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamElementCounter/StreamElementCounter_tb.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamElementCounter/StreamElementCounter_16_5_32_9_tc.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamElementCounter/StreamElementCounter_8_3_63_6_tc.sim.08.vhd',
            'dep work 1993 ' + DIR + '/complex/vhlib/stream/StreamElementCounter.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamFIFO/StreamFIFO_tv.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamFIFO/StreamFIFO_tb.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamFIFO/StreamFIFO_Increase_tc.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamFIFO/StreamFIFO_Reduce_tc.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamFIFO/StreamFIFO_Same_tc.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamGearbox/StreamGearbox_tv.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamGearbox/StreamGearbox_tb.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamGearbox/StreamGearbox_2_2_8_3_tc.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamGearbox/StreamGearbox_32_5_16_4_tc.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamGearbox/StreamGearbox_5_4_3_2_tc.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamGearbox/StreamGearbox_8_4_8_3_tc.sim.08.vhd',
            'dep work 1993 ' + DIR + '/complex/vhlib/stream/StreamGearbox.vhd',
            'dep work 1993 ' + DIR + '/complex/vhlib/stream/StreamGearboxParallelizer.vhd',
            'dep work 1993 ' + DIR + '/complex/vhlib/stream/StreamGearboxSerializer.vhd',
            'dep work 1993 ' + DIR + '/complex/vhlib/stream/StreamNormalizer.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamNormalizer/StreamNormalizer_tb.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamNormalizer/StreamNormalizer_tc.sim.08.vhd',
            'dep work 1993 ' + DIR + '/complex/vhlib/util/UtilMisc_pkg.vhd',
            'dep work 1993 ' + DIR + '/complex/vhlib/stream/StreamPipelineBarrel.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamPipelineBarrel/StreamPipelineBarrel_tb.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamPipelineBarrel/StreamPipelineBarrel_tc.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamPipelineControl/StreamPipelineControl_tv.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamPipelineControl/StreamPipelineControl_tb.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamPipelineControl/StreamPipelineControl_20_3_t_tc.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamPipelineControl/StreamPipelineControl_5_1_f_tc.sim.08.vhd',
            'dep work 1993 ' + DIR + '/complex/vhlib/stream/StreamPrefixSum.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamPrefixSum/StreamPrefixSum_tb.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamPrefixSum/StreamPrefixSum_tc.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamPRNG/StreamPRNG_tv.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamPRNG/StreamPRNG_tb.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamPRNG/StreamPRNG_12_tc.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamPRNG/StreamPRNG_8_tc.sim.08.vhd',
            'dep work 1993 ' + DIR + '/complex/vhlib/stream/StreamPRNG.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamReshaper/StreamReshaperCtrl_tv.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamReshaper/StreamReshaperCtrl_tb.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamReshaper/StreamReshaperCtrl_1_1_7_3_tc.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamReshaper/StreamReshaperCtrl_4_3_4_3_tc.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamReshaper/StreamReshaperCtrl_8_3_4_2_tc.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamReshaper/StreamReshaperLast_tv.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamReshaper/StreamReshaperLast_tb.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamReshaper/StreamReshaperLast_1_1_7_3_tc.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamReshaper/StreamReshaperLast_4_3_4_3_tc.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamReshaper/StreamReshaperLast_8_3_4_2_tc.sim.08.vhd',
            'dep work 1993 ' + DIR + '/complex/vhlib/stream/StreamPipelineControl.vhd',
            'dep work 1993 ' + DIR + '/complex/vhlib/stream/StreamFIFOCounter.vhd',
            'dep work 1993 ' + DIR + '/complex/vhlib/util/UtilRam_pkg.vhd',
            'dep work 1993 ' + DIR + '/complex/vhlib/stream/StreamFIFO.vhd',
            'dep work 1993 ' + DIR + '/complex/vhlib/stream/StreamBuffer.vhd',
            'dep work 1993 ' + DIR + '/complex/vhlib/stream/StreamReshaper.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamSink/StreamSink_tc.sim.08.vhd',
            'dep work 1993 ' + DIR + '/complex/vhlib/stream/StreamSlice.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamSlice/StreamSlice_tb.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamSlice/StreamSlice_tc.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamSource/StreamSource_tc.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/model/StreamSource_mdl.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/model/StreamMonitor_mdl.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/model/StreamSink_mdl.sim.08.vhd',
            'dep work 1993 ' + DIR + '/complex/vhlib/stream/StreamSync.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/sim/ClockGen_mdl.sim.08.vhd',
            'dep work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamSync/StreamSync_tb.sim.08.vhd',
            'top work 2008 ' + DIR + '/complex/vhlib/stream/test/StreamSync/StreamSync_tc.sim.08.vhd',
            'dep work 1993 ' + DIR + '/complex/vhlib/util/UtilRam1R1W.vhd',
            'dep work 1993 ' + DIR + '/complex/vhlib/util/UtilConv_pkg.vhd',
            'dep work 1993 ' + DIR + '/complex/vhlib/util/UtilStr_pkg.vhd',
            'dep work 1993 ' + DIR + '/complex/vhlib/util/UtilMem64_pkg.vhd',
        ]) + '\n')

    def test_vhlib_93_required(self):
        """Test the dependency analyzer with vhlib, synthesis only"""
        self.maxDiff = None
        code, out, _ = run_vhdeps('dump', '-i', DIR + '/complex/vhlib', '-v', '93')
        self.assertEqual(code, 0)
        self.assertEqual(out, '\n'.join([
            'top work 1993 ' + DIR + '/complex/vhlib/stream/StreamArb.vhd',
            'dep work 1993 ' + DIR + '/complex/vhlib/util/UtilInt_pkg.vhd',
            'dep work 1993 ' + DIR + '/complex/vhlib/stream/Stream_pkg.vhd',
            'top work 1993 ' + DIR + '/complex/vhlib/stream/StreamElementCounter.vhd',
            'top work 1993 ' + DIR + '/complex/vhlib/stream/StreamGearbox.vhd',
            'dep work 1993 ' + DIR + '/complex/vhlib/stream/StreamGearboxParallelizer.vhd',
            'dep work 1993 ' + DIR + '/complex/vhlib/stream/StreamGearboxSerializer.vhd',
            'top work 1993 ' + DIR + '/complex/vhlib/stream/StreamNormalizer.vhd',
            'top work 1993 ' + DIR + '/complex/vhlib/stream/StreamPrefixSum.vhd',
            'top work 1993 ' + DIR + '/complex/vhlib/stream/StreamPRNG.vhd',
            'dep work 1993 ' + DIR + '/complex/vhlib/stream/StreamPipelineControl.vhd',
            'dep work 1993 ' + DIR + '/complex/vhlib/util/UtilMisc_pkg.vhd',
            'dep work 1993 ' + DIR + '/complex/vhlib/stream/StreamPipelineBarrel.vhd',
            'dep work 1993 ' + DIR + '/complex/vhlib/stream/StreamFIFOCounter.vhd',
            'dep work 1993 ' + DIR + '/complex/vhlib/util/UtilRam_pkg.vhd',
            'dep work 1993 ' + DIR + '/complex/vhlib/stream/StreamFIFO.vhd',
            'dep work 1993 ' + DIR + '/complex/vhlib/stream/StreamBuffer.vhd',
            'top work 1993 ' + DIR + '/complex/vhlib/stream/StreamReshaper.vhd',
            'dep work 1993 ' + DIR + '/complex/vhlib/stream/StreamSlice.vhd',
            'top work 1993 ' + DIR + '/complex/vhlib/stream/StreamSync.vhd',
            'dep work 1993 ' + DIR + '/complex/vhlib/util/UtilRam1R1W.vhd',
            'dep work 1993 ' + DIR + '/complex/vhlib/util/UtilConv_pkg.vhd',
            'dep work 1993 ' + DIR + '/complex/vhlib/util/UtilStr_pkg.vhd',
            'dep work 1993 ' + DIR + '/complex/vhlib/util/UtilMem64_pkg.vhd',
        ]) + '\n')
