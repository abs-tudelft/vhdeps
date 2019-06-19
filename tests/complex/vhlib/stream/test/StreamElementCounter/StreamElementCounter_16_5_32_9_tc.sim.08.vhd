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
use work.Stream_pkg.all;
use work.ClockGen_pkg.all;
use work.StreamSource_pkg.all;
use work.StreamSink_pkg.all;

entity StreamElementCounter_16_5_32_9_tc is
end StreamElementCounter_16_5_32_9_tc;

architecture TestBench of StreamElementCounter_16_5_32_9_tc is
begin

  tv: entity work.StreamElementCounter_tv
    generic map (
      OUT_COUNT_MAX             => 32,
      OUT_COUNT_WIDTH           => 9
    );

  tb: entity work.StreamElementCounter_tb
    generic map (
      IN_COUNT_MAX              => 16,
      IN_COUNT_WIDTH            => 5,
      OUT_COUNT_MAX             => 32,
      OUT_COUNT_WIDTH           => 9
    );

end TestBench;

