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

entity StreamElementCounter_tv is
  generic (
    OUT_COUNT_MAX               : natural;
    OUT_COUNT_WIDTH             : natural
  );
end StreamElementCounter_tv;

architecture TestVector of StreamElementCounter_tv is
begin

  random_tc: process is
    variable a        : streamsource_type;
    variable b        : streamsink_type;
    variable max_count: integer;
    variable remain   : integer;
    variable expect   : integer;
  begin
    tc_open("StreamElementCounter-random", "tests normalization of randomized input.");
    a.initialize("a");
    b.initialize("b");

    a.set_total_cyc(-5, 5);
    a.set_count(0, a.g_count_max);
    a.set_last_greed(0.5);
    for i in 5 to 15 loop
      for j in 1 to i*5 loop
        a.push_int(0);
      end loop;
      a.transmit;
    end loop;

    b.set_total_cyc(-5, 5);
    b.unblock;

    tc_wait_for(50 us);

    max_count := imin(OUT_COUNT_MAX, 2**OUT_COUNT_WIDTH-1);
    for i in 5 to 15 loop
      remain := i*5;
      while remain > 0 loop
        expect := imin(max_count, remain);
        remain := remain - expect;
        tc_check(b.cq_get_d_nat, expect, "count");
        if remain = 0 then
          tc_check(b.cq_get_last, '1', "last");
        else
          tc_check(b.cq_get_last, '0', "last");
        end if;
        b.cq_next;
      end loop;
    end loop;
    tc_check(b.cq_ready, false);

    tc_pass;
    wait;
  end process;

end TestVector;

