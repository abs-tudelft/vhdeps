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

entity StreamFIFO_Same_tc is
end StreamFIFO_Same_tc;

architecture TestCase of StreamFIFO_Same_tc is
begin

  tv: entity work.StreamFIFO_tv
    generic map (
      IN_CLK_PERIOD             => 10 ns,
      OUT_CLK_PERIOD            => 10 ns
    );

  tb: entity work.StreamFIFO_tb
    generic map (
      IN_CLK_PERIOD             => 10 ns,
      OUT_CLK_PERIOD            => 10 ns
    );

end TestCase;

