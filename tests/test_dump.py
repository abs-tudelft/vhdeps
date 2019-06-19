from unittest import TestCase, skipIf
import os
import sys
import io
import re
import tempfile
from plumbum import local

import vhdeps

workdir = os.path.realpath(os.path.dirname(__file__))

def run_vhdeps(*args):
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

class TestDump(TestCase):
    def test_basic(self):
        code, out, err = run_vhdeps('dump', '-i', workdir + '/simple/multiple-ok')
        self.assertEquals(code, 0)
        self.assertEquals(out, '\n'.join([
            'top work 2008 ' + workdir + '/simple/multiple-ok/bar_tc.vhd',
            'top work 2008 ' + workdir + '/simple/multiple-ok/baz.vhd',
            'top work 2008 ' + workdir + '/simple/multiple-ok/foo_tc.vhd',
        ]) + '\n')

    def test_to_file(self):
        with tempfile.TemporaryDirectory() as tempdir:
            code, out, err = run_vhdeps('dump', '-i', workdir + '/simple/multiple-ok', '-o', tempdir+'/output')
            self.assertEquals(code, 0)
            with open(tempdir+'/output', 'r') as fildes:
                self.assertEquals(fildes.read(), '\n'.join([
                    'top work 2008 ' + workdir + '/simple/multiple-ok/bar_tc.vhd',
                    'top work 2008 ' + workdir + '/simple/multiple-ok/baz.vhd',
                    'top work 2008 ' + workdir + '/simple/multiple-ok/foo_tc.vhd',
                ]) + '\n')

    def test_default_include(self):
        with local.cwd(workdir + '/simple/multiple-ok'):
            code, out, err = run_vhdeps('dump')
        self.assertEquals(code, 0)
        self.assertTrue('Including the current working directory recursively by default' in err)
        self.assertEquals(out, '\n'.join([
            'top work 2008 ' + workdir + '/simple/multiple-ok/bar_tc.vhd',
            'top work 2008 ' + workdir + '/simple/multiple-ok/baz.vhd',
            'top work 2008 ' + workdir + '/simple/multiple-ok/foo_tc.vhd',
        ]) + '\n')

    def test_default_include_by_file(self):
        code, out, err = run_vhdeps('dump', '-i', workdir + '/simple/multiple-ok', '-i', workdir + '/simple/all-good/test_tc.vhd')
        self.assertEquals(code, 0)
        self.assertEquals(out, '\n'.join([
            'top work 2008 ' + workdir + '/simple/multiple-ok/bar_tc.vhd',
            'top work 2008 ' + workdir + '/simple/multiple-ok/baz.vhd',
            'top work 2008 ' + workdir + '/simple/multiple-ok/foo_tc.vhd',
            'top work 2008 ' + workdir + '/simple/all-good/test_tc.vhd',
        ]) + '\n')

    def test_default_filters(self):
        code, out, err = run_vhdeps('dump', '-i', workdir + '/simple/filtering')
        self.assertEquals(code, 0)
        self.assertEquals(out, '\n'.join([
            'top work 2008 ' + workdir + '/simple/filtering/new.08.vhd',
            'top work 1993 ' + workdir + '/simple/filtering/old.93.vhd',
            'top work 2008 ' + workdir + '/simple/filtering/simulation.sim.vhd',
        ]) + '\n')

    def test_fixed_version_1993(self):
        code, out, err = run_vhdeps('dump', '-i', workdir + '/simple/filtering', '-v93')
        self.assertEquals(code, 0)
        self.assertEquals(out, '\n'.join([
            'top work 1993 ' + workdir + '/simple/filtering/old.93.vhd',
            'top work 1993 ' + workdir + '/simple/filtering/simulation.sim.vhd',
        ]) + '\n')

    def test_desired_version(self):
        code, out, err = run_vhdeps('dump', '-i', workdir + '/simple/filtering', '-d93')
        self.assertEquals(code, 0)
        self.assertEquals(out, '\n'.join([
            'top work 2008 ' + workdir + '/simple/filtering/new.08.vhd',
            'top work 1993 ' + workdir + '/simple/filtering/old.93.vhd',
            'top work 1993 ' + workdir + '/simple/filtering/simulation.sim.vhd',
        ]) + '\n')

    def test_synthesis(self):
        code, out, err = run_vhdeps('dump', '-i', workdir + '/simple/filtering', '-msyn')
        self.assertEquals(code, 0)
        self.assertEquals(out, '\n'.join([
            'top work 2008 ' + workdir + '/simple/filtering/new.08.vhd',
            'top work 1993 ' + workdir + '/simple/filtering/old.93.vhd',
            'top work 2008 ' + workdir + '/simple/filtering/synthesis.syn.vhd',
        ]) + '\n')

    def test_no_filtering(self):
        code, out, err = run_vhdeps('dump', '-i', workdir + '/simple/filtering', '-mall')
        self.assertEquals(code, 0)
        self.assertEquals(out, '\n'.join([
            'top work 2008 ' + workdir + '/simple/filtering/new.08.vhd',
            'top work 1993 ' + workdir + '/simple/filtering/old.93.vhd',
            'top work 2008 ' + workdir + '/simple/filtering/simulation.sim.vhd',
            'top work 2008 ' + workdir + '/simple/filtering/synthesis.syn.vhd',
        ]) + '\n')

    def test_selected_entities(self):
        code, out, err = run_vhdeps('dump', 'new', 'old', '-i', workdir + '/simple/filtering')
        self.assertEquals(code, 0)
        self.assertEquals(out, '\n'.join([
            'top work 2008 ' + workdir + '/simple/filtering/new.08.vhd',
            'top work 1993 ' + workdir + '/simple/filtering/old.93.vhd',
        ]) + '\n')

    def test_selected_entity_glob(self):
        code, out, err = run_vhdeps('dump', 's*', '-i', workdir + '/simple/filtering')
        self.assertEquals(code, 0)
        self.assertEquals(out, '\n'.join([
            'top work 2008 ' + workdir + '/simple/filtering/simulation.sim.vhd',
        ]) + '\n')

    def test_selected_entity_no_match(self):
        code, out, err = run_vhdeps('dump', 's*', 'x*', '-i', workdir + '/simple/filtering')
        self.assertEquals(code, 0)
        self.assertTrue('Warning: work.x* did not match anything.' in err)
        self.assertEquals(out, '\n'.join([
            'top work 2008 ' + workdir + '/simple/filtering/simulation.sim.vhd',
        ]) + '\n')

    def test_conflict(self):
        code, out, err = run_vhdeps('dump', '-i', workdir + '/simple/all-good', '-i', workdir + '/simple/timeout')
        self.assertEquals(code, 1)
        self.assertTrue('ResolutionError: entity work.test_tc is defined in multiple, ambiguous files:' in err)

    def test_libraries(self):
        code, out, err = run_vhdeps('dump', '-i', workdir + '/simple/all-good', '-i', 'timeout:' + workdir + '/simple/timeout')
        self.assertEquals(code, 0)
        self.assertEquals(out, '\n'.join([
            'top timeout 2008 ' + workdir + '/simple/timeout/test_tc.vhd',
            'top work 2008 ' + workdir + '/simple/all-good/test_tc.vhd',
        ]) + '\n')

    def test_version_override(self):
        code, out, err = run_vhdeps('dump', '-i', workdir + '/simple/all-good', '-i', '93:timeout:' + workdir + '/simple/timeout')
        self.assertEquals(code, 0)
        self.assertEquals(out, '\n'.join([
            'top timeout 1993 ' + workdir + '/simple/timeout/test_tc.vhd',
            'top work 2008 ' + workdir + '/simple/all-good/test_tc.vhd',
        ]) + '\n')

    def test_ambiguous_08(self):
        code, out, err = run_vhdeps('dump', '-i', workdir + '/simple/ambiguous')
        self.assertEquals(code, 0)
        self.assertEquals(out, '\n'.join([
            'top work 2008 ' + workdir + '/simple/ambiguous/test.08.sim.vhd',
        ]) + '\n')

    def test_ambiguous_93(self):
        code, out, err = run_vhdeps('dump', '-i', workdir + '/simple/ambiguous', '-d', '93')
        self.assertEquals(code, 0)
        self.assertEquals(out, '\n'.join([
            'top work 1993 ' + workdir + '/simple/ambiguous/test.93.sim.vhd',
        ]) + '\n')

    def test_ambiguous_syn(self):
        code, out, err = run_vhdeps('dump', '-i', workdir + '/simple/ambiguous', '-m', 'syn')
        self.assertEquals(code, 0)
        self.assertEquals(out, '\n'.join([
            'top work 2008 ' + workdir + '/simple/ambiguous/test.syn.vhd',
        ]) + '\n')

    def test_component_circle(self):
        code, out, err = run_vhdeps('dump', '-i', workdir + '/complex/component-circle')
        self.assertEquals(code, 0)
        self.assertEquals(out, '\n'.join([
            'dep work 2008 /ssddata/vhdeps/tests/complex/component-circle/a.vhd',
            'top work 2008 /ssddata/vhdeps/tests/complex/component-circle/b.vhd',
        ]) + '\n')

    def test_entity_circle(self):
        code, out, err = run_vhdeps('dump', '-i', workdir + '/complex/entity-circle')
        self.assertEquals(code, 1)
        self.assertTrue('ResolutionError: circular dependency:' in err)

    def test_vhlib_default(self):
        self.maxDiff = None
        code, out, err = run_vhdeps('dump', '-i', workdir + '/complex/vhlib')
        self.assertEquals(code, 0)
        self.assertEquals(out, '\n'.join([
            'dep work 2008 ' + workdir + '/complex/vhlib/sim/TestCase_pkg.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/sim/SimDataComms_pkg.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/sim/SimDataComms_tc.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/model/StreamMonitor_pkg.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/model/StreamSource_pkg.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/model/StreamSink_pkg.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamArb/StreamArb_tv.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/Stream_pkg.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/sim/ClockGen_pkg.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamArb/StreamArb_tb.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamArb/StreamArb_Fixed_tc.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamArb/StreamArb_RoundRobin_tc.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamArb/StreamArb_RRSticky_tc.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/StreamArb.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamBuffer/StreamBuffer_tv.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamBuffer/StreamBuffer_tb.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamBuffer/StreamBuffer_0_tc.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamBuffer/StreamBuffer_200_tc.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamBuffer/StreamBuffer_2_tc.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamBuffer/StreamBuffer_4_tc.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamBuffer/StreamBuffer_6_tc.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/util/UtilInt_pkg.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamElementCounter/StreamElementCounter_tv.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamElementCounter/StreamElementCounter_tb.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamElementCounter/StreamElementCounter_16_5_32_9_tc.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamElementCounter/StreamElementCounter_8_3_63_6_tc.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/StreamElementCounter.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamFIFO/StreamFIFO_tv.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamFIFO/StreamFIFO_tb.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamFIFO/StreamFIFO_Increase_tc.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamFIFO/StreamFIFO_Reduce_tc.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamFIFO/StreamFIFO_Same_tc.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamGearbox/StreamGearbox_tv.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamGearbox/StreamGearbox_tb.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamGearbox/StreamGearbox_2_2_8_3_tc.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamGearbox/StreamGearbox_32_5_16_4_tc.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamGearbox/StreamGearbox_5_4_3_2_tc.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamGearbox/StreamGearbox_8_4_8_3_tc.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/StreamGearbox.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/StreamGearboxParallelizer.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/StreamGearboxSerializer.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/StreamNormalizer.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamNormalizer/StreamNormalizer_tb.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamNormalizer/StreamNormalizer_tc.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/util/UtilMisc_pkg.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/StreamPipelineBarrel.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamPipelineBarrel/StreamPipelineBarrel_tb.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamPipelineBarrel/StreamPipelineBarrel_tc.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamPipelineControl/StreamPipelineControl_tv.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamPipelineControl/StreamPipelineControl_tb.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamPipelineControl/StreamPipelineControl_20_3_t_tc.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamPipelineControl/StreamPipelineControl_5_1_f_tc.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/StreamPrefixSum.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamPrefixSum/StreamPrefixSum_tb.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamPrefixSum/StreamPrefixSum_tc.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamPRNG/StreamPRNG_tv.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamPRNG/StreamPRNG_tb.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamPRNG/StreamPRNG_12_tc.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamPRNG/StreamPRNG_8_tc.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/StreamPRNG.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamReshaper/StreamReshaperCtrl_tv.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamReshaper/StreamReshaperCtrl_tb.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamReshaper/StreamReshaperCtrl_1_1_7_3_tc.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamReshaper/StreamReshaperCtrl_4_3_4_3_tc.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamReshaper/StreamReshaperCtrl_8_3_4_2_tc.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamReshaper/StreamReshaperLast_tv.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamReshaper/StreamReshaperLast_tb.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamReshaper/StreamReshaperLast_1_1_7_3_tc.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamReshaper/StreamReshaperLast_4_3_4_3_tc.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamReshaper/StreamReshaperLast_8_3_4_2_tc.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/StreamPipelineControl.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/StreamFIFOCounter.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/util/UtilRam_pkg.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/StreamFIFO.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/StreamBuffer.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/StreamReshaper.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamSink/StreamSink_tc.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/StreamSlice.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamSlice/StreamSlice_tb.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamSlice/StreamSlice_tc.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamSource/StreamSource_tc.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/model/StreamSource_mdl.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/model/StreamMonitor_mdl.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/model/StreamSink_mdl.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/StreamSync.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/sim/ClockGen_mdl.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamSync/StreamSync_tb.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamSync/StreamSync_tc.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/util/UtilRam1R1W.vhd',
        ]) + '\n')

    def test_vhlib_93_desired(self):
        self.maxDiff = None
        code, out, err = run_vhdeps('dump', '-i', workdir + '/complex/vhlib', '-d', '93')
        self.assertEquals(code, 0)
        self.assertEquals(out, '\n'.join([
            'dep work 2008 ' + workdir + '/complex/vhlib/sim/TestCase_pkg.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/sim/SimDataComms_pkg.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/sim/SimDataComms_tc.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/model/StreamMonitor_pkg.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/model/StreamSource_pkg.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/model/StreamSink_pkg.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamArb/StreamArb_tv.sim.08.vhd',
            'dep work 1993 ' + workdir + '/complex/vhlib/stream/Stream_pkg.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/sim/ClockGen_pkg.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamArb/StreamArb_tb.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamArb/StreamArb_Fixed_tc.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamArb/StreamArb_RoundRobin_tc.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamArb/StreamArb_RRSticky_tc.sim.08.vhd',
            'dep work 1993 ' + workdir + '/complex/vhlib/stream/StreamArb.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamBuffer/StreamBuffer_tv.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamBuffer/StreamBuffer_tb.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamBuffer/StreamBuffer_0_tc.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamBuffer/StreamBuffer_200_tc.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamBuffer/StreamBuffer_2_tc.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamBuffer/StreamBuffer_4_tc.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamBuffer/StreamBuffer_6_tc.sim.08.vhd',
            'dep work 1993 ' + workdir + '/complex/vhlib/util/UtilInt_pkg.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamElementCounter/StreamElementCounter_tv.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamElementCounter/StreamElementCounter_tb.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamElementCounter/StreamElementCounter_16_5_32_9_tc.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamElementCounter/StreamElementCounter_8_3_63_6_tc.sim.08.vhd',
            'dep work 1993 ' + workdir + '/complex/vhlib/stream/StreamElementCounter.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamFIFO/StreamFIFO_tv.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamFIFO/StreamFIFO_tb.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamFIFO/StreamFIFO_Increase_tc.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamFIFO/StreamFIFO_Reduce_tc.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamFIFO/StreamFIFO_Same_tc.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamGearbox/StreamGearbox_tv.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamGearbox/StreamGearbox_tb.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamGearbox/StreamGearbox_2_2_8_3_tc.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamGearbox/StreamGearbox_32_5_16_4_tc.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamGearbox/StreamGearbox_5_4_3_2_tc.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamGearbox/StreamGearbox_8_4_8_3_tc.sim.08.vhd',
            'dep work 1993 ' + workdir + '/complex/vhlib/stream/StreamGearbox.vhd',
            'dep work 1993 ' + workdir + '/complex/vhlib/stream/StreamGearboxParallelizer.vhd',
            'dep work 1993 ' + workdir + '/complex/vhlib/stream/StreamGearboxSerializer.vhd',
            'dep work 1993 ' + workdir + '/complex/vhlib/stream/StreamNormalizer.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamNormalizer/StreamNormalizer_tb.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamNormalizer/StreamNormalizer_tc.sim.08.vhd',
            'dep work 1993 ' + workdir + '/complex/vhlib/util/UtilMisc_pkg.vhd',
            'dep work 1993 ' + workdir + '/complex/vhlib/stream/StreamPipelineBarrel.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamPipelineBarrel/StreamPipelineBarrel_tb.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamPipelineBarrel/StreamPipelineBarrel_tc.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamPipelineControl/StreamPipelineControl_tv.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamPipelineControl/StreamPipelineControl_tb.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamPipelineControl/StreamPipelineControl_20_3_t_tc.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamPipelineControl/StreamPipelineControl_5_1_f_tc.sim.08.vhd',
            'dep work 1993 ' + workdir + '/complex/vhlib/stream/StreamPrefixSum.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamPrefixSum/StreamPrefixSum_tb.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamPrefixSum/StreamPrefixSum_tc.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamPRNG/StreamPRNG_tv.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamPRNG/StreamPRNG_tb.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamPRNG/StreamPRNG_12_tc.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamPRNG/StreamPRNG_8_tc.sim.08.vhd',
            'dep work 1993 ' + workdir + '/complex/vhlib/stream/StreamPRNG.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamReshaper/StreamReshaperCtrl_tv.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamReshaper/StreamReshaperCtrl_tb.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamReshaper/StreamReshaperCtrl_1_1_7_3_tc.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamReshaper/StreamReshaperCtrl_4_3_4_3_tc.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamReshaper/StreamReshaperCtrl_8_3_4_2_tc.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamReshaper/StreamReshaperLast_tv.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamReshaper/StreamReshaperLast_tb.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamReshaper/StreamReshaperLast_1_1_7_3_tc.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamReshaper/StreamReshaperLast_4_3_4_3_tc.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamReshaper/StreamReshaperLast_8_3_4_2_tc.sim.08.vhd',
            'dep work 1993 ' + workdir + '/complex/vhlib/stream/StreamPipelineControl.vhd',
            'dep work 1993 ' + workdir + '/complex/vhlib/stream/StreamFIFOCounter.vhd',
            'dep work 1993 ' + workdir + '/complex/vhlib/util/UtilRam_pkg.vhd',
            'dep work 1993 ' + workdir + '/complex/vhlib/stream/StreamFIFO.vhd',
            'dep work 1993 ' + workdir + '/complex/vhlib/stream/StreamBuffer.vhd',
            'dep work 1993 ' + workdir + '/complex/vhlib/stream/StreamReshaper.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamSink/StreamSink_tc.sim.08.vhd',
            'dep work 1993 ' + workdir + '/complex/vhlib/stream/StreamSlice.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamSlice/StreamSlice_tb.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamSlice/StreamSlice_tc.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamSource/StreamSource_tc.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/model/StreamSource_mdl.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/model/StreamMonitor_mdl.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/model/StreamSink_mdl.sim.08.vhd',
            'dep work 1993 ' + workdir + '/complex/vhlib/stream/StreamSync.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/sim/ClockGen_mdl.sim.08.vhd',
            'dep work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamSync/StreamSync_tb.sim.08.vhd',
            'top work 2008 ' + workdir + '/complex/vhlib/stream/test/StreamSync/StreamSync_tc.sim.08.vhd',
            'dep work 1993 ' + workdir + '/complex/vhlib/util/UtilRam1R1W.vhd',
        ]) + '\n')

    def test_vhlib_93_required(self):
        self.maxDiff = None
        code, out, err = run_vhdeps('dump', '-i', workdir + '/complex/vhlib', '-v', '93')
        self.assertEquals(code, 0)
        self.assertEquals(out, '\n'.join([
            'top work 1993 ' + workdir + '/complex/vhlib/stream/StreamArb.vhd',
            'dep work 1993 ' + workdir + '/complex/vhlib/util/UtilInt_pkg.vhd',
            'dep work 1993 ' + workdir + '/complex/vhlib/stream/Stream_pkg.vhd',
            'top work 1993 ' + workdir + '/complex/vhlib/stream/StreamElementCounter.vhd',
            'top work 1993 ' + workdir + '/complex/vhlib/stream/StreamGearbox.vhd',
            'dep work 1993 ' + workdir + '/complex/vhlib/stream/StreamGearboxParallelizer.vhd',
            'dep work 1993 ' + workdir + '/complex/vhlib/stream/StreamGearboxSerializer.vhd',
            'top work 1993 ' + workdir + '/complex/vhlib/stream/StreamNormalizer.vhd',
            'top work 1993 ' + workdir + '/complex/vhlib/stream/StreamPrefixSum.vhd',
            'top work 1993 ' + workdir + '/complex/vhlib/stream/StreamPRNG.vhd',
            'dep work 1993 ' + workdir + '/complex/vhlib/stream/StreamPipelineControl.vhd',
            'dep work 1993 ' + workdir + '/complex/vhlib/util/UtilMisc_pkg.vhd',
            'dep work 1993 ' + workdir + '/complex/vhlib/stream/StreamPipelineBarrel.vhd',
            'dep work 1993 ' + workdir + '/complex/vhlib/stream/StreamFIFOCounter.vhd',
            'dep work 1993 ' + workdir + '/complex/vhlib/util/UtilRam_pkg.vhd',
            'dep work 1993 ' + workdir + '/complex/vhlib/stream/StreamFIFO.vhd',
            'dep work 1993 ' + workdir + '/complex/vhlib/stream/StreamBuffer.vhd',
            'top work 1993 ' + workdir + '/complex/vhlib/stream/StreamReshaper.vhd',
            'dep work 1993 ' + workdir + '/complex/vhlib/stream/StreamSlice.vhd',
            'top work 1993 ' + workdir + '/complex/vhlib/stream/StreamSync.vhd',
            'dep work 1993 ' + workdir + '/complex/vhlib/util/UtilRam1R1W.vhd',
        ]) + '\n')

