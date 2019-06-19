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

entity StreamReshaperCtrl_4_3_4_3_tc is
end StreamReshaperCtrl_4_3_4_3_tc;

architecture TestBench of StreamReshaperCtrl_4_3_4_3_tc is
begin

  tv: entity work.StreamReshaperCtrl_tv;

  tb: entity work.StreamReshaperCtrl_tb
    generic map (
      IN_COUNT_MAX              => 4,
      IN_COUNT_WIDTH            => 3,
      OUT_COUNT_MAX             => 4,
      OUT_COUNT_WIDTH           => 3
    );

end TestBench;

