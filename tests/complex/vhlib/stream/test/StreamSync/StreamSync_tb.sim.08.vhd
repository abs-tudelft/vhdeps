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

entity StreamSync_tb is
end StreamSync_tb;

architecture TestBench of StreamSync_tb is

  signal clk                    : std_logic;
  signal reset                  : std_logic;

  signal a_valid                : std_logic;
  signal a_ready                : std_logic;
  signal a_data                 : std_logic_vector(7 downto 0);
  signal a_x, a_y, a_z          : std_logic_vector(0 downto 0);
  signal a_advance_other        : std_logic;
  signal a_use_other            : std_logic;
  signal a_out_enable           : std_logic;

  signal b_valid                : std_logic;
  signal b_ready                : std_logic;
  signal b_data                 : std_logic_vector(7 downto 0);
  signal b_x, b_y, b_z          : std_logic_vector(0 downto 0);
  signal b_advance_other        : std_logic;
  signal b_use_other            : std_logic;
  signal b_out_enable           : std_logic;

  signal c_valid                : std_logic;
  signal c_ready                : std_logic;
  signal c_data                 : std_logic_vector(7 downto 0);

  signal d_valid                : std_logic;
  signal d_ready                : std_logic;
  signal d_data                 : std_logic_vector(7 downto 0);

begin

  clkgen: ClockGen_mdl
    port map (
      clk                       => clk,
      reset                     => reset
    );

  a_source: StreamSource_mdl
    generic map (
      NAME                      => "a",
      ELEMENT_WIDTH             => 8,
      X_WIDTH                   => 1,
      Y_WIDTH                   => 1,
      Z_WIDTH                   => 1
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      valid                     => a_valid,
      ready                     => a_ready,
      data                      => a_data,
      x                         => a_x,
      y                         => a_y,
      z                         => a_z
    );

  a_advance_other <= a_x(0) or not a_valid;
  a_use_other     <= a_y(0) or not a_valid;
  a_out_enable    <= a_z(0) or not a_valid;

  b_source: StreamSource_mdl
    generic map (
      NAME                      => "b",
      ELEMENT_WIDTH             => 8,
      X_WIDTH                   => 1,
      Y_WIDTH                   => 1,
      Z_WIDTH                   => 1
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      valid                     => b_valid,
      ready                     => b_ready,
      data                      => b_data,
      x                         => b_x,
      y                         => b_y,
      z                         => b_z
    );

  b_advance_other <= b_x(0) or not b_valid;
  b_use_other     <= b_y(0) or not b_valid;
  b_out_enable    <= b_z(0) or not b_valid;

  uut: StreamSync
    generic map (
      NUM_INPUTS                => 2,
      NUM_OUTPUTS               => 2
    )
    port map (
      clk                       => clk,
      reset                     => reset,

      in_valid(1)               => b_valid,
      in_valid(0)               => a_valid,
      in_ready(1)               => b_ready,
      in_ready(0)               => a_ready,
      in_advance(1)             => a_advance_other,
      in_advance(0)             => b_advance_other,
      in_use(1)                 => a_use_other,
      in_use(0)                 => b_use_other,

      out_valid(1)              => d_valid,
      out_valid(0)              => c_valid,
      out_ready(1)              => d_ready,
      out_ready(0)              => c_ready,
      out_enable(1)             => b_out_enable,
      out_enable(0)             => a_out_enable
    );

  mix_proc: process (a_data, b_data) is
  begin
    -- C = text from A, capitalization from B.
    c_data <= a_data;
    if a_data(6) = '1' then
      c_data(5) <= b_data(5);
    end if;

    -- D = text from B, capitalization from A.
    d_data <= b_data;
    if b_data(6) = '1' then
      d_data(5) <= a_data(5);
    end if;
  end process;

  c_sink: StreamSink_mdl
    generic map (
      NAME                      => "c",
      ELEMENT_WIDTH             => 8
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      valid                     => c_valid,
      ready                     => c_ready,
      data                      => c_data
    );

  d_sink: StreamSink_mdl
    generic map (
      NAME                      => "d",
      ELEMENT_WIDTH             => 8
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      valid                     => d_valid,
      ready                     => d_ready,
      data                      => d_data
    );

end TestBench;

