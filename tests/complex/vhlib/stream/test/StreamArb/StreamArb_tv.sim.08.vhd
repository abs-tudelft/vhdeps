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
use work.StreamMonitor_pkg.all;
use work.StreamSink_pkg.all;

entity StreamArb_tv is
  generic (
    ARB_METHOD                  : string
  );
end StreamArb_tv;

architecture TestVector of StreamArb_tv is
begin

  indep_speed_tc: process is
    variable x        : streamsource_type;
    variable d        : streamsink_type;
    variable i        : streammonitor_type;
    constant X_NAMES  : string(1 to 3) := "abc";
    constant INDICES  : string(1 to 3) := "012";
    constant TEST_STR : string := "The quick brown fox jumps over the lazy dog.";
  begin
    tc_open("StreamArb-" & ARB_METHOD & "-indep-speed", "speed-tests the StreamArb for each stream independently.");
    d.initialize("d");
    i.initialize("i");
    d.unblock;

    for idx in 1 to 3 loop
      x.initialize(X_NAMES(idx to idx));
      x.push_str(TEST_STR);
      x.transmit;

      tc_wait_for(2 us);

      for si in TEST_STR'range loop
        tc_check(x.cq_ready, "missing data on input stream");
        tc_check(d.cq_ready, "missing data on output stream");
        tc_check(i.cq_ready, "missing data on index stream");
        tc_check(d.cq_get_d_nat mod 256, character'pos(TEST_STR(si)), "incorrect data on output stream");
        tc_check(i.cq_get_d_nat mod 256, character'pos(INDICES(idx)), "incorrect data on index stream");
        if si > TEST_STR'low then
          tc_check(x.cq_cyc_total, 1, "input stream < 1 xfer/cycle");
          tc_check(d.cq_cyc_total, 1, "output stream < 1 xfer/cycle");
        end if;
        x.cq_next;
        d.cq_next;
        i.cq_next;
      end loop;
      tc_check(not x.cq_ready, "unexpected data on input stream");
      tc_check(not d.cq_ready, "unexpected data on output stream");
      tc_check(not i.cq_ready, "unexpected data on index stream");
    end loop;

    tc_pass;
    wait;
  end process;

  indep_random_tc: process is
    variable x        : streamsource_type;
    variable d        : streamsink_type;
    constant X_NAMES  : string(1 to 3) := "abc";
    constant TEST_STR : string := "The quick brown fox jumps over the lazy dog.";
  begin
    tc_open("StreamArb-" & ARB_METHOD & "-indep-random",
        "tests the StreamArb for each stream independently with randomized handshaking.");
    d.initialize("d");
    d.set_total_cyc(-5, 5);
    d.unblock;

    for idx in 1 to 3 loop
      x.initialize(X_NAMES(idx to idx));
      x.set_total_cyc(-5, 5);
      x.push_str(TEST_STR);
      x.transmit;

      tc_wait_for(5 us);

      tc_check(x.cq_get_d_str, TEST_STR);
      tc_check(d.cq_get_d_str, TEST_STR);
    end loop;

    tc_pass;
    wait;
  end process;

  method_tc: process is
    variable a        : streamsource_type;
    variable b        : streamsource_type;
    variable c        : streamsource_type;
    variable d        : streamsink_type;
    variable i        : streammonitor_type;

    procedure packet_burst(ss : inout streamsource_type) is
    begin
      ss.push_str("abc");
      ss.transmit;
      ss.push_str("uvw");
      ss.transmit;
      ss.push_str("xyz");
      ss.transmit;
    end procedure;
  begin
    tc_open("StreamArb-" & ARB_METHOD & "-method",
        "tests the " & ARB_METHOD & " arbitration method.");

    a.initialize("a");
    b.initialize("b");
    c.initialize("c");
    d.initialize("d");
    i.initialize("i");

    d.set_total_cyc(-5, 5);
    d.unblock;

    packet_burst(a);
    packet_burst(b);

    tc_wait_for(5 us);

    packet_burst(b);
    packet_burst(c);

    tc_wait_for(5 us);

    packet_burst(a);
    packet_burst(b);
    packet_burst(c);

    tc_wait_for(5 us);

    if ARB_METHOD = "ROUND-ROBIN" then

      tc_check(d.pq_get_str & i.pq_get_str, "abc111", "a");
      tc_check(d.pq_get_str & i.pq_get_str, "abc000", "b");
      tc_check(d.pq_get_str & i.pq_get_str, "uvw111", "c");
      tc_check(d.pq_get_str & i.pq_get_str, "uvw000", "d");
      tc_check(d.pq_get_str & i.pq_get_str, "xyz111", "e");
      tc_check(d.pq_get_str & i.pq_get_str, "xyz000", "f");

      tc_check(d.pq_get_str & i.pq_get_str, "abc111", "g");
      tc_check(d.pq_get_str & i.pq_get_str, "abc222", "h");
      tc_check(d.pq_get_str & i.pq_get_str, "uvw111", "i");
      tc_check(d.pq_get_str & i.pq_get_str, "uvw222", "j");
      tc_check(d.pq_get_str & i.pq_get_str, "xyz111", "k");
      tc_check(d.pq_get_str & i.pq_get_str, "xyz222", "l");

      tc_check(d.pq_get_str & i.pq_get_str, "abc000", "m");
      tc_check(d.pq_get_str & i.pq_get_str, "abc111", "n");
      tc_check(d.pq_get_str & i.pq_get_str, "abc222", "o");
      tc_check(d.pq_get_str & i.pq_get_str, "uvw000", "p");
      tc_check(d.pq_get_str & i.pq_get_str, "uvw111", "q");
      tc_check(d.pq_get_str & i.pq_get_str, "uvw222", "r");
      tc_check(d.pq_get_str & i.pq_get_str, "xyz000", "s");
      tc_check(d.pq_get_str & i.pq_get_str, "xyz111", "t");
      tc_check(d.pq_get_str & i.pq_get_str, "xyz222", "u");

    elsif ARB_METHOD = "RR-STICKY" then

      tc_check(d.pq_get_str & i.pq_get_str, "abc000", "a");
      tc_check(d.pq_get_str & i.pq_get_str, "uvw000", "b");
      tc_check(d.pq_get_str & i.pq_get_str, "xyz000", "c");
      tc_check(d.pq_get_str & i.pq_get_str, "abc111", "d");
      tc_check(d.pq_get_str & i.pq_get_str, "uvw111", "e");
      tc_check(d.pq_get_str & i.pq_get_str, "xyz111", "f");

      tc_check(d.pq_get_str & i.pq_get_str, "abc111", "g");
      tc_check(d.pq_get_str & i.pq_get_str, "uvw111", "h");
      tc_check(d.pq_get_str & i.pq_get_str, "xyz111", "i");
      tc_check(d.pq_get_str & i.pq_get_str, "abc222", "j");
      tc_check(d.pq_get_str & i.pq_get_str, "uvw222", "k");
      tc_check(d.pq_get_str & i.pq_get_str, "xyz222", "l");

      tc_check(d.pq_get_str & i.pq_get_str, "abc222", "m");
      tc_check(d.pq_get_str & i.pq_get_str, "uvw222", "n");
      tc_check(d.pq_get_str & i.pq_get_str, "xyz222", "o");
      tc_check(d.pq_get_str & i.pq_get_str, "abc000", "p");
      tc_check(d.pq_get_str & i.pq_get_str, "uvw000", "q");
      tc_check(d.pq_get_str & i.pq_get_str, "xyz000", "r");
      tc_check(d.pq_get_str & i.pq_get_str, "abc111", "s");
      tc_check(d.pq_get_str & i.pq_get_str, "uvw111", "t");
      tc_check(d.pq_get_str & i.pq_get_str, "xyz111", "u");

    elsif ARB_METHOD = "FIXED" then

      tc_check(d.pq_get_str & i.pq_get_str, "abc000", "a");
      tc_check(d.pq_get_str & i.pq_get_str, "uvw000", "b");
      tc_check(d.pq_get_str & i.pq_get_str, "xyz000", "c");
      tc_check(d.pq_get_str & i.pq_get_str, "abc111", "d");
      tc_check(d.pq_get_str & i.pq_get_str, "uvw111", "e");
      tc_check(d.pq_get_str & i.pq_get_str, "xyz111", "f");

      tc_check(d.pq_get_str & i.pq_get_str, "abc111", "g");
      tc_check(d.pq_get_str & i.pq_get_str, "uvw111", "h");
      tc_check(d.pq_get_str & i.pq_get_str, "xyz111", "i");
      tc_check(d.pq_get_str & i.pq_get_str, "abc222", "j");
      tc_check(d.pq_get_str & i.pq_get_str, "uvw222", "k");
      tc_check(d.pq_get_str & i.pq_get_str, "xyz222", "l");

      tc_check(d.pq_get_str & i.pq_get_str, "abc000", "m");
      tc_check(d.pq_get_str & i.pq_get_str, "uvw000", "n");
      tc_check(d.pq_get_str & i.pq_get_str, "xyz000", "o");
      tc_check(d.pq_get_str & i.pq_get_str, "abc111", "p");
      tc_check(d.pq_get_str & i.pq_get_str, "uvw111", "q");
      tc_check(d.pq_get_str & i.pq_get_str, "xyz111", "r");
      tc_check(d.pq_get_str & i.pq_get_str, "abc222", "s");
      tc_check(d.pq_get_str & i.pq_get_str, "uvw222", "t");
      tc_check(d.pq_get_str & i.pq_get_str, "xyz222", "u");

    end if;

    tc_pass;
    wait;
  end process;

end TestVector;

