-- Copyright 2018 Delft University of Technology
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.TestCase_pkg.all;
use work.StreamSource_pkg.all;
use work.StreamSink_pkg.all;

entity StreamFIFO_tv is
  generic (
    IN_CLK_PERIOD               : in  time;
    OUT_CLK_PERIOD              : in  time
  );
end StreamFIFO_tv;

architecture TestVector of StreamFIFO_tv is
begin

  speed_tc: process is
    constant TEST_STR : string := "The quick brown fox jumps over the lazy dog.";
    variable a : streamsource_type;
    variable b : streamsink_type;
  begin
    tc_open("StreamFIFO-speed", "tests that StreamFIFO reaches 1 transfer/cycle.");
    a.initialize("a");
    b.initialize("b");

    a.push_str(TEST_STR);
    a.transmit;
    b.unblock;

    tc_wait_for(2 us);

    for i in TEST_STR'range loop
      tc_check(a.cq_ready, "missing data on input stream");
      tc_check(b.cq_ready, "missing data on output stream");
      tc_check(b.cq_get_d_nat mod 256, character'pos(TEST_STR(i)), "incorrect data on output stream");
      if i > TEST_STR'low then
        if OUT_CLK_PERIOD <= IN_CLK_PERIOD then
          tc_check(a.cq_cyc_total, 1, "input stream < 1 xfer/cycle");
        end if;
        if OUT_CLK_PERIOD >= IN_CLK_PERIOD then
          tc_check(b.cq_cyc_total, 1, "output stream < 1 xfer/cycle");
        end if;
      end if;
      a.cq_next;
      b.cq_next;
    end loop;
    tc_check(not a.cq_ready, "unexpected data on input stream");
    tc_check(not b.cq_ready, "unexpected data on output stream");

    tc_pass;
    wait;
  end process;

  backpressure_tc: process is
    constant TEST_STR : string := "The quick brown fox jumps over the lazy dog.";
    variable a : streamsource_type;
    variable b : streamsink_type;
  begin
    tc_open("StreamFIFO-backpressure", "tests that StreamFIFO's backpressure handling is correct.");
    a.initialize("a");
    b.initialize("b");

    a.push_str(TEST_STR);
    a.transmit;
    b.unblock;
    tc_wait_for(100 ns);
    b.reblock;
    tc_wait_for(100 ns);
    b.unblock;
    tc_wait_for(2 us);

    for i in TEST_STR'range loop
      tc_check(a.cq_ready, "missing data on input stream");
      tc_check(b.cq_ready, "missing data on output stream");
      tc_check(b.cq_get_d_nat mod 256, character'pos(TEST_STR(i)), "incorrect data on output stream");
      a.cq_next;
      b.cq_next;
    end loop;
    tc_check(not a.cq_ready, "unexpected data on input stream");
    tc_check(not b.cq_ready, "unexpected data on output stream");

    tc_pass;
    wait;
  end process;

  random_tc: process is
    constant TEST_STR_X : string := "The quick brown fox jumps over the lazy dog.";
    constant TEST_STR : string := TEST_STR_X & TEST_STR_X & TEST_STR_X & TEST_STR_X;
    variable a : streamsource_type;
    variable b : streamsink_type;
  begin
    tc_open("StreamFIFO-random", "tests randomized handshaking with StreamFIFO.");
    a.initialize("a");
    b.initialize("b");

    a.set_total_cyc(-5, 5);
    b.set_total_cyc(-5, 5);

    a.push_str(TEST_STR);
    a.transmit;
    b.unblock;
    tc_wait_for(10 us);

    for i in TEST_STR'range loop
      tc_check(a.cq_ready, "missing data on input stream");
      tc_check(b.cq_ready, "missing data on output stream");
      tc_check(b.cq_get_d_nat mod 256, character'pos(TEST_STR(i)), "incorrect data on output stream");
      a.cq_next;
      b.cq_next;
    end loop;
    tc_check(not a.cq_ready, "unexpected data on input stream");
    tc_check(not b.cq_ready, "unexpected data on output stream");

    tc_pass;
    wait;
  end process;

end TestVector;

