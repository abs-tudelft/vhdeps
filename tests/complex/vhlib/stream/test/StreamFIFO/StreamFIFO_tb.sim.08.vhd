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

entity StreamFIFO_tb is
  generic (
    IN_CLK_PERIOD               : in  time;
    OUT_CLK_PERIOD              : in  time
  );
end StreamFIFO_tb;

architecture TestBench of StreamFIFO_tb is

  constant DATA_WIDTH           : natural := 8;

  signal in_clk                 : std_logic;
  signal in_reset               : std_logic;

  signal out_clk                : std_logic;
  signal out_reset              : std_logic;

  signal a_valid                : std_logic;
  signal a_ready                : std_logic;
  signal a_data                 : std_logic_vector(DATA_WIDTH-1 downto 0);

  signal b_valid                : std_logic;
  signal b_ready                : std_logic;
  signal b_data                 : std_logic_vector(DATA_WIDTH-1 downto 0);

begin

  clkgen_in: ClockGen_mdl
    generic map (
      NAME                      => "in",
      INIT_PERIOD               => IN_CLK_PERIOD
    )
    port map (
      clk                       => in_clk,
      reset                     => in_reset
    );

  clkgen_out: ClockGen_mdl
    generic map (
      NAME                      => "out",
      INIT_PERIOD               => OUT_CLK_PERIOD
    )
    port map (
      clk                       => out_clk,
      reset                     => out_reset
    );

  a_source: StreamSource_mdl
    generic map (
      NAME                      => "a",
      ELEMENT_WIDTH             => DATA_WIDTH
    )
    port map (
      clk                       => in_clk,
      reset                     => in_reset,
      valid                     => a_valid,
      ready                     => a_ready,
      data                      => a_data
    );

  uut: StreamFIFO
    generic map (
      DATA_WIDTH                => DATA_WIDTH,
      DEPTH_LOG2                => 5,
      XCLK_STAGES               => 2
    )
    port map (
      in_clk                    => in_clk,
      in_reset                  => in_reset,
      in_valid                  => a_valid,
      in_ready                  => a_ready,
      in_data                   => a_data,
      out_clk                   => out_clk,
      out_reset                 => out_reset,
      out_valid                 => b_valid,
      out_ready                 => b_ready,
      out_data                  => b_data
    );

  b_sink: StreamSink_mdl
    generic map (
      NAME                      => "b",
      ELEMENT_WIDTH             => DATA_WIDTH
    )
    port map (
      clk                       => out_clk,
      reset                     => out_reset,
      valid                     => b_valid,
      ready                     => b_ready,
      data                      => b_data
    );

end TestBench;

