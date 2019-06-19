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

entity StreamReshaperLast_tv is
end StreamReshaperLast_tv;

architecture TestVector of StreamReshaperLast_tv is
begin

  random_tc: process is
    constant TEST_STR : string(1 to 44) := "The quick brown fox jumps over the lazy dog.";
    variable a        : streamsource_type;
    variable b        : streamsink_type;
    variable remain   : integer;
    variable expect   : integer;
  begin
    tc_open("StreamReshaper-random", "tests normalization of randomized input.");
    a.initialize("a");
    b.initialize("b");

    a.set_total_cyc(-5, 5);
    a.set_count(0, a.g_count_max);
    a.set_last_greed(0.5);
    for i in 0 to 15 loop
      a.push_str(TEST_STR(1 to 44 - i));
      a.transmit;
    end loop;

    b.set_total_cyc(-5, 5);
    b.unblock;

    tc_wait_for(50 us);

    for i in 0 to 15 loop

      -- Check packet data.
      tc_check(b.pq_get_str, TEST_STR(1 to 44 - i));

      -- Check packet shape.
      remain := 44 - i;
      while remain > 0 loop
        expect := imin(b.g_count_max, remain);
        remain := remain - expect;
        tc_check(b.cq_get_ecount, expect, "element count");
        b.cq_next;
      end loop;
      loop
        exit when not b.cq_ready;
        exit when b.cq_get_ecount > 0;
        b.cq_next;
      end loop;

    end loop;
    tc_check(b.pq_ready, false);

    tc_pass;
    wait;
  end process;

end TestVector;

