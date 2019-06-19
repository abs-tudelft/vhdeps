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

entity StreamPipelineControl_tv is
end StreamPipelineControl_tv;

architecture TestCase of StreamPipelineControl_tv is
begin

  main_tc: process is
    constant INPUT_STR  : string := "The Quick Brown Fox jumps over the Lazy Dog.";
    constant OUTPUT_STR : string := "T!heQ!uickB!rownF!oxjumpsovertheL!azyD!og.";
    variable a : streamsource_type;
    variable b : streamsink_type;
  begin
    tc_open("StreamPipelineControl", "tests StreamPipelineControl.");
    a.initialize("a");
    b.initialize("b");

    a.set_total_cyc(-5, 5);
    a.push_str(INPUT_STR & INPUT_STR & INPUT_STR & INPUT_STR);
    a.transmit;

    b.set_total_cyc(-5, 5);
    b.unblock;

    tc_wait_for(20 us);

    tc_check(b.cq_get_d_str, OUTPUT_STR & OUTPUT_STR & OUTPUT_STR & OUTPUT_STR);

    tc_pass;
    wait;
  end process;

end TestCase;

