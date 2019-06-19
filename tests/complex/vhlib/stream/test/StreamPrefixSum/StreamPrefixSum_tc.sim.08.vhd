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

entity StreamPrefixSum_tc is
end StreamPrefixSum_tc;

architecture TestCase of StreamPrefixSum_tc is
begin

  basic_tc: process is
    variable a      : streamsource_type;
    variable b      : streamsink_type;
    variable accum  : unsigned(7 downto 0);
  begin
    tc_open("StreamPrefixSum-basic", "tests StreamPrefixSum basic functionality.");
    a.initialize("a");
    b.initialize("b");

    a.set_x("0");
    a.set_y("00000000");
    for i in 1 to 10 loop
      a.push_int(i);
    end loop;
    a.transmit;

    b.unblock;

    tc_wait_for(1 us);

    accum := "00000000";
    for i in 1 to 10 loop
      accum := accum + i;
      tc_check(b.pq_get_nat, to_integer(accum));
    end loop;
    tc_check(not b.pq_avail);

    tc_pass;
    wait;
  end process;

  offset_tc: process is
    variable a      : streamsource_type;
    variable b      : streamsink_type;
    variable accum  : unsigned(7 downto 0);
  begin
    tc_open("StreamPrefixSum-offset", "tests StreamPrefixSum with an initial offset.");
    a.initialize("a");
    b.initialize("b");

    a.set_x("0");
    a.set_y("00001010");
    for i in 10 downto 1 loop
      a.push_int(i);
    end loop;

    a.transmit;

    b.unblock;

    tc_wait_for(1 us);

    accum := "00001010";
    for i in 10 downto 1 loop
      accum := accum + i;
      tc_check(b.pq_get_nat, to_integer(accum));
    end loop;
    tc_check(not b.pq_avail);

    tc_pass;
    wait;
  end process;

  random_tc: process is
    variable a      : streamsource_type;
    variable b      : streamsink_type;
    variable accum  : unsigned(7 downto 0);
  begin
    tc_open("StreamPrefixSum-random", "tests StreamPrefixSum with randomized handshake/shape.");
    a.initialize("a");
    b.initialize("b");

    a.set_total_cyc(-5, 5);
    a.set_count(0, a.g_count_max);
    a.set_x("0");
    a.set_y("00000000");
    for j in 1 to 10 loop
      for i in 1 to 10 loop
        a.push_int(i);
      end loop;
      a.transmit;
    end loop;

    b.set_total_cyc(-5, 5);
    b.unblock;

    tc_wait_for(10 us);

    for j in 1 to 10 loop
      accum := "00000000";
      for i in 1 to 10 loop
        accum := accum + i;
        tc_check(b.pq_get_nat, to_integer(accum));
      end loop;
      tc_check(not b.pq_avail);
      b.pq_next;
    end loop;

    tc_pass;
    wait;
  end process;


  tb: entity work.StreamPrefixSum_tb
    generic map (
      ELEMENT_WIDTH   => 8,
      COUNT_MAX       => 4,
      COUNT_WIDTH     => 3
    );

end TestCase;

