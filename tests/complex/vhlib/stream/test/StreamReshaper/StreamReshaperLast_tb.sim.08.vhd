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

entity StreamReshaperLast_tb is
  generic (
    IN_COUNT_MAX                : natural := 4;
    IN_COUNT_WIDTH              : natural := 3;
    OUT_COUNT_MAX               : natural := 4;
    OUT_COUNT_WIDTH             : natural := 3
  );
end StreamReshaperLast_tb;

architecture TestBench of StreamReshaperLast_tb is

  signal clk                    : std_logic;
  signal reset                  : std_logic;

  signal a_valid                : std_logic;
  signal a_ready                : std_logic;
  signal a_dvalid               : std_logic;
  signal a_data                 : std_logic_vector(8*IN_COUNT_MAX-1 downto 0);
  signal a_count                : std_logic_vector(IN_COUNT_WIDTH-1 downto 0);
  signal a_last                 : std_logic;

  signal b_valid                : std_logic;
  signal b_ready                : std_logic;
  signal b_dvalid               : std_logic;
  signal b_data                 : std_logic_vector(8*OUT_COUNT_MAX-1 downto 0);
  signal b_count                : std_logic_vector(OUT_COUNT_WIDTH-1 downto 0);
  signal b_last                 : std_logic;

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
      COUNT_MAX                 => IN_COUNT_MAX,
      COUNT_WIDTH               => IN_COUNT_WIDTH
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      valid                     => a_valid,
      ready                     => a_ready,
      dvalid                    => a_dvalid,
      data                      => a_data,
      count                     => a_count,
      last                      => a_last
    );

  uut: StreamReshaper
    generic map (
      ELEMENT_WIDTH             => 8,
      IN_COUNT_MAX              => IN_COUNT_MAX,
      IN_COUNT_WIDTH            => IN_COUNT_WIDTH,
      OUT_COUNT_MAX             => OUT_COUNT_MAX,
      OUT_COUNT_WIDTH           => OUT_COUNT_WIDTH
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      din_valid                 => a_valid,
      din_ready                 => a_ready,
      din_dvalid                => a_dvalid,
      din_data                  => a_data,
      din_count                 => a_count,
      din_last                  => a_last,
      out_valid                 => b_valid,
      out_ready                 => b_ready,
      out_dvalid                => b_dvalid,
      out_data                  => b_data,
      out_count                 => b_count,
      out_last                  => b_last
    );

  b_sink: StreamSink_mdl
    generic map (
      NAME                      => "b",
      ELEMENT_WIDTH             => 8,
      COUNT_MAX                 => OUT_COUNT_MAX,
      COUNT_WIDTH               => OUT_COUNT_WIDTH
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      valid                     => b_valid,
      ready                     => b_ready,
      dvalid                    => b_dvalid,
      data                      => b_data,
      count                     => b_count,
      last                      => b_last
    );

end TestBench;

