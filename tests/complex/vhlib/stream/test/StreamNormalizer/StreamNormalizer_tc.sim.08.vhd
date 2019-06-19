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

entity StreamNormalizer_tc is
end StreamNormalizer_tc;

architecture TestCase of StreamNormalizer_tc is
begin

  random_tc: process is
    constant TEST_STR : string(1 to 48) := "The quick brown fox jumps over the lazy dog.....";
    variable a        : streamsource_type;
    variable r        : streamsource_type;
    variable b        : streamsink_type;
    variable remain   : integer;
    variable request  : integer;
    variable expect   : integer;
  begin
    tc_open("StreamNormalizer-random", "tests normalization of randomized input.");
    a.initialize("a");
    r.initialize("r");
    b.initialize("b");

    a.set_total_cyc(-5, 5);
    a.set_count(0, 4);
    a.set_last_greed(true); -- non-greedy last is not supported!
    for i in 1 to 4 loop
      a.push_str(TEST_STR(1 to 44 + i));
      a.transmit;
    end loop;

    for i in 1 to 50 loop
      for j in 0 to 4 loop
        r.push_int(j);
      end loop;
    end loop;
    r.transmit;

    b.set_total_cyc(-5, 5);
    b.unblock;

    tc_wait_for(10 us);

    for i in 1 to 4 loop

      -- Check packet data.
      tc_check(a.pq_get_str, TEST_STR(1 to 44 + i));

      -- Check packet shape.
      remain := 44 + i;
      while remain > 0 loop
        request := r.cq_get_d_nat;
        expect := imin(request, remain);
        remain := remain - expect;
        tc_check(b.cq_get_ecount, expect, "element count");
        r.cq_next;
        b.cq_next;
      end loop;

    end loop;
    tc_check(a.pq_ready, false);

    tc_pass;
    wait;
  end process;

  tb: entity work.StreamNormalizer_tb
    generic map (
      COUNT_MAX     => 4,
      COUNT_WIDTH   => 3
    );

end TestCase;

