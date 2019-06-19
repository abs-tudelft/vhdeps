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
use work.StreamMonitor_pkg.all;
use work.StreamSink_pkg.all;

entity StreamArb_tb is
  generic (
    ARB_METHOD                  : string
  );
end StreamArb_tb;

architecture TestBench of StreamArb_tb is

  signal clk                    : std_logic;
  signal reset                  : std_logic;

  signal a_data                 : std_logic_vector(7 downto 0);
  signal a_last                 : std_logic;
  signal a_valid                : std_logic;
  signal a_ready                : std_logic;

  signal b_data                 : std_logic_vector(7 downto 0);
  signal b_last                 : std_logic;
  signal b_valid                : std_logic;
  signal b_ready                : std_logic;

  signal c_data                 : std_logic_vector(7 downto 0);
  signal c_last                 : std_logic;
  signal c_valid                : std_logic;
  signal c_ready                : std_logic;

  signal d_data                 : std_logic_vector(7 downto 0);
  signal d_last                 : std_logic;
  signal d_index                : std_logic_vector(1 downto 0);
  signal d_index_ascii          : std_logic_vector(7 downto 0);
  signal d_valid                : std_logic;
  signal d_ready                : std_logic;

begin

  clkgen: ClockGen_mdl
    port map (
      clk                       => clk,
      reset                     => reset
    );

  a_source: StreamSource_mdl
    generic map (
      NAME                      => "a",
      ELEMENT_WIDTH             => 8
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      valid                     => a_valid,
      ready                     => a_ready,
      data                      => a_data,
      last                      => a_last
    );

  b_source: StreamSource_mdl
    generic map (
      NAME                      => "b",
      ELEMENT_WIDTH             => 8
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      valid                     => b_valid,
      ready                     => b_ready,
      data                      => b_data,
      last                      => b_last
    );

  c_source: StreamSource_mdl
    generic map (
      NAME                      => "c",
      ELEMENT_WIDTH             => 8
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      valid                     => c_valid,
      ready                     => c_ready,
      data                      => c_data,
      last                      => c_last
    );

  uut: StreamArb
    generic map (
      NUM_INPUTS                => 3,
      INDEX_WIDTH               => 2,
      DATA_WIDTH                => 8,
      ARB_METHOD                => ARB_METHOD
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid(2)               => c_valid,
      in_valid(1)               => b_valid,
      in_valid(0)               => a_valid,
      in_ready(2)               => c_ready,
      in_ready(1)               => b_ready,
      in_ready(0)               => a_ready,
      in_data(23 downto 16)     => c_data,
      in_data(15 downto 8)      => b_data,
      in_data(7 downto 0)       => a_data,
      in_last(2)                => c_last,
      in_last(1)                => b_last,
      in_last(0)                => a_last,
      out_valid                 => d_valid,
      out_ready                 => d_ready,
      out_data                  => d_data,
      out_last                  => d_last,
      out_index                 => d_index
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
      data                      => d_data,
      last                      => d_last
    );

  d_index_ascii <= "001100" & d_index;

  d_index_mon: StreamMonitor_mdl
    generic map (
      NAME                      => "i",
      ELEMENT_WIDTH             => 8
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      valid                     => d_valid,
      ready                     => d_ready,
      data                      => d_index_ascii,
      last                      => d_last
    );

end TestBench;

