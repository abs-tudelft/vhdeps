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
use ieee.std_logic_misc.all;

package UtilRam_pkg is

  -- 1-read 1-write RAM.
  component UtilRam1R1W is
    generic (
      WIDTH                     : natural;
      DEPTH_LOG2                : natural;
      RAM_CONFIG                : string := ""
    );
    port (
      w_clk                     : in  std_logic;
      w_ena                     : in  std_logic;
      w_addr                    : in  std_logic_vector(DEPTH_LOG2-1 downto 0);
      w_data                    : in  std_logic_vector(WIDTH-1 downto 0);
      r_clk                     : in  std_logic;
      r_ena                     : in  std_logic := '1';
      r_addr                    : in  std_logic_vector(DEPTH_LOG2-1 downto 0);
      r_data                    : out std_logic_vector(WIDTH-1 downto 0)
    );
  end component;

end UtilRam_pkg;
