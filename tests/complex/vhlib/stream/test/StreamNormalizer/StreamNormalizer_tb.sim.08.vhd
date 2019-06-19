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

entity StreamNormalizer_tb is
  generic (
    COUNT_MAX                   : natural := 4;
    COUNT_WIDTH                 : natural := 3
  );
end StreamNormalizer_tb;

architecture TestBench of StreamNormalizer_tb is

  signal clk                    : std_logic;
  signal reset                  : std_logic;

  signal a_valid                : std_logic;
  signal a_ready                : std_logic;
  signal a_dvalid               : std_logic;
  signal a_data                 : std_logic_vector(8*COUNT_MAX-1 downto 0);
  signal a_count                : std_logic_vector(COUNT_WIDTH-1 downto 0);
  signal a_last                 : std_logic;

  signal b_valid                : std_logic;
  signal b_ready                : std_logic;
  signal o_valid                : std_logic;
  signal o_ready                : std_logic;
  signal r_valid                : std_logic;
  signal r_ready                : std_logic;
  signal bor_dvalid             : std_logic;
  signal bor_data               : std_logic_vector(8*COUNT_MAX-1 downto 0);
  signal bor_req_count          : std_logic_vector(COUNT_WIDTH-1 downto 0);
  signal bor_count              : std_logic_vector(COUNT_WIDTH-1 downto 0);
  signal bor_last               : std_logic;

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
      COUNT_MAX                 => COUNT_MAX,
      COUNT_WIDTH               => COUNT_WIDTH
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

  r_source: StreamSource_mdl
    generic map (
      NAME                      => "r",
      ELEMENT_WIDTH             => COUNT_WIDTH
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      valid                     => r_valid,
      ready                     => r_ready,
      data                      => bor_req_count
    );

  uut: StreamNormalizer
    generic map (
      ELEMENT_WIDTH             => 8,
      COUNT_MAX                 => COUNT_MAX,
      COUNT_WIDTH               => COUNT_WIDTH,
      REQ_COUNT_WIDTH           => COUNT_WIDTH
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => a_valid,
      in_ready                  => a_ready,
      in_dvalid                 => a_dvalid,
      in_data                   => a_data,
      in_count                  => a_count,
      in_last                   => a_last,
      req_count                 => bor_req_count,
      out_valid                 => o_valid,
      out_ready                 => o_ready,
      out_dvalid                => bor_dvalid,
      out_data                  => bor_data,
      out_count                 => bor_count,
      out_last                  => bor_last
    );

  bor_sync: StreamSync
    generic map (
      NUM_INPUTS                => 2,
      NUM_OUTPUTS               => 1
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid(1)               => r_valid,
      in_valid(0)               => o_valid,
      in_ready(1)               => r_ready,
      in_ready(0)               => o_ready,
      out_valid(0)              => b_valid,
      out_ready(0)              => b_ready
    );

  b_sink: StreamSink_mdl
    generic map (
      NAME                      => "b",
      ELEMENT_WIDTH             => 8,
      COUNT_MAX                 => COUNT_MAX,
      COUNT_WIDTH               => COUNT_WIDTH
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      valid                     => b_valid,
      ready                     => b_ready,
      dvalid                    => bor_dvalid,
      data                      => bor_data,
      count                     => bor_count,
      last                      => bor_last
    );

end TestBench;

