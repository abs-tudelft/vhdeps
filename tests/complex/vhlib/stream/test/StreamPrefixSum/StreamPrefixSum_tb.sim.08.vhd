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

entity StreamPrefixSum_tb is
  generic (
    ELEMENT_WIDTH               : natural;
    COUNT_MAX                   : natural;
    COUNT_WIDTH                 : natural
  );
end StreamPrefixSum_tb;

architecture TestBench of StreamPrefixSum_tb is

  signal clk                    : std_logic;
  signal reset                  : std_logic;

  signal a_valid                : std_logic;
  signal a_ready                : std_logic;
  signal a_dvalid               : std_logic;
  signal a_data                 : std_logic_vector(ELEMENT_WIDTH*COUNT_MAX-1 downto 0);
  signal a_count                : std_logic_vector(COUNT_WIDTH-1 downto 0);
  signal a_last                 : std_logic;
  signal a_clear                : std_logic;
  signal a_initial              : std_logic_vector(ELEMENT_WIDTH-1 downto 0);

  signal b_valid                : std_logic;
  signal b_ready                : std_logic;
  signal b_dvalid               : std_logic;
  signal b_data                 : std_logic_vector(ELEMENT_WIDTH*COUNT_MAX-1 downto 0);
  signal b_count                : std_logic_vector(COUNT_WIDTH-1 downto 0);
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
      ELEMENT_WIDTH             => ELEMENT_WIDTH,
      COUNT_MAX                 => COUNT_MAX,
      COUNT_WIDTH               => COUNT_WIDTH,
      X_WIDTH                   => 1,
      Y_WIDTH                   => ELEMENT_WIDTH
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      valid                     => a_valid,
      ready                     => a_ready,
      dvalid                    => a_dvalid,
      data                      => a_data,
      count                     => a_count,
      last                      => a_last,
      x(0)                      => a_clear,
      y                         => a_initial
    );

  uut: StreamPrefixSum
    generic map (
      ELEMENT_WIDTH             => ELEMENT_WIDTH,
      COUNT_MAX                 => COUNT_MAX,
      COUNT_WIDTH               => COUNT_WIDTH
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
      in_clear                  => a_clear,
      in_initial                => a_initial,
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
      ELEMENT_WIDTH             => ELEMENT_WIDTH,
      COUNT_MAX                 => COUNT_MAX,
      COUNT_WIDTH               => COUNT_WIDTH
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

