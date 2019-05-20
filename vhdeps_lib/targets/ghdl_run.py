# Copyright 2018 Delft University of Technology
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Runs the given VHDL files as a vhlib test suite using GHDL. Requires GHDL
to be on the system path and that the Plumbum Python library is installed."""

def is_simulation():
    return True

def run(l, order, f):
    from plumbum import local, ProcessExecutionError, FG
    from plumbum.cmd import ghdl

    f.write("Analyzing...\n")
    failed = False
    for vhd in order:
        # TODO vhd.lib, vhd.version!
        rc, stdout, stderr = (ghdl["-a"]["-g"]["--std=08"]["--ieee=synopsys"][vhd.fname]).run(retcode=None)
        if rc != 0:
            failed = True
        f.write(stdout)
        f.write(stderr)
    if failed:
        f.write("Analysis failed!\n")
        return
    summary = []
    for top in l.top:
        if top.unit.endswith("_tc"):
            f.write("Elaborating %s...\n" % top.unit)
            # TODO vhd.lib, vhd.version!
            rc, stdout, stderr = (ghdl["-e"]["-g"]["--std=08"]["--ieee=synopsys"][top.unit]).run(retcode=None)
            f.write(stdout)
            f.write(stderr)
            if rc != 0:
                f.write("Elaboration for %s failed!\n" % top.unit)
            else:
                f.write("Running %s...\n" % top.unit)
                # TODO vhd.lib, vhd.version!
                rc, stdout, stderr = (ghdl["-r"]["-g"]["--std=08"]["--ieee=synopsys"][top.unit]).run(retcode=None)
                f.write(stdout)
                f.write(stderr)
                if rc != 0:
                    summary.append(" * FAILED %s" % top.unit)
                    failed = True
                else:
                    summary.append(" * PASSED %s" % top.unit)
    f.write("\nFinal summary:\n" + "\n".join(summary) + "\n")
    if failed:
        f.write("Test suite FAILED\n")
    else:
        f.write("Test suite PASSED\n")

