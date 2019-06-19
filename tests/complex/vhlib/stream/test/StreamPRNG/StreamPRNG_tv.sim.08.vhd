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

entity StreamPRNG_tv is
  generic (
    DATA_WIDTH                  : natural
  );
end StreamPRNG_tv;

architecture TestVector of StreamPRNG_tv is
begin

  test_tc: process is
    variable a        : streamsink_type;
    type boolean_array is array (natural range <>) of boolean;
    variable seen     : boolean_array(0 to 2**DATA_WIDTH-1) := (others => false);
    variable value    : integer;
  begin
    tc_open("StreamPRNG",
      "tests a full LFSR sequence.");
    a.initialize("a");

    a.set_total_cyc(-10, 2);
    a.unblock;

    for i in 0 to 2**DATA_WIDTH - 2 loop
      if not a.cq_ready then
        tc_wait_for(10 us);
      end if;
      value := a.cq_get_d_nat;
      tc_check(not seen(value), "duplicate " & integer'image(value));
      seen(value) := true;
      a.cq_next;
    end loop;

    tc_pass;
    wait;
  end process;

end TestVector;

