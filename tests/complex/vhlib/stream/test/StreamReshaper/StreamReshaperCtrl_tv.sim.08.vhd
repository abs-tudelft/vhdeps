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
use work.UtilInt_pkg.all;

entity StreamReshaperCtrl_tv is
end StreamReshaperCtrl_tv;

architecture TestVector of StreamReshaperCtrl_tv is
begin

  random_tc: process is
    constant TEST_STR : string(1 to 44) := "The quick brown fox jumps over the lazy dog.";
    variable a        : streamsource_type;
    variable c        : streamsource_type;
    variable b        : streamsink_type;
    variable remain   : integer;
    variable expect   : integer;
  begin
    tc_open("StreamReshaper-random", "tests normalization of randomized input.");
    a.initialize("a");
    c.initialize("c");
    b.initialize("b");

    a.set_total_cyc(-5, 5);
    a.set_count(0, a.g_count_max);
    for i in 0 to 15 loop
      a.push_str(TEST_STR(1 to 44 - i));
      a.transmit;
    end loop;

    -- FIXME: reshapers currently make no assumptions about the "last" flag of
    -- the data input stream, even if it's not connected. This leads to it
    -- needing to wait for additional input in some rare occasions. There
    -- should probably be some generic that can be used to indicate that
    -- din_last should be completely ignored to prevent unexpected stalls.
    a.push_str("garbage");
    a.transmit;

    c.set_total_cyc(-5, 5);
    c.set_count(0, c.g_count_max);
    c.set_last_greed(false);
    for i in 0 to 15 loop
      c.push_str(TEST_STR(1 to 44 - i));
      c.transmit;
    end loop;

    b.set_total_cyc(-5, 5);
    b.unblock;

    tc_wait_for(50 us);

    -- Check packet data.
--     for i in 0 to 15 loop
--       tc_check(b.pq_get_str, TEST_STR(1 to 44 - i));
--     end loop;
--     tc_check(b.pq_ready, false);

    -- Check packet shape.
    while b.cq_ready and c.cq_ready loop
      tc_check(b.cq_get_ecount, c.cq_get_ecount, "element count");
      tc_check(b.cq_get_last, c.cq_get_last, "last");
      b.cq_next;
      c.cq_next;
    end loop;
    tc_check(b.cq_ready, false, "out > cin");
    tc_check(c.cq_ready, false, "cin > out");

    tc_pass;
    wait;
  end process;

end TestVector;

