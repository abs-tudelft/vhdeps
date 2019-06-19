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

entity StreamBuffer_tb is
  generic (
    MIN_DEPTH                   : natural
  );
end StreamBuffer_tb;

architecture TestBench of StreamBuffer_tb is

  constant DATA_WIDTH           : natural := 8;

  signal clk                    : std_logic;
  signal reset                  : std_logic;

  signal a_valid                : std_logic;
  signal a_ready                : std_logic;
  signal a_data                 : std_logic_vector(DATA_WIDTH-1 downto 0);

  signal b_valid                : std_logic;
  signal b_ready                : std_logic;
  signal b_data                 : std_logic_vector(DATA_WIDTH-1 downto 0);

begin

  clkgen: ClockGen_mdl
    port map (
      clk                       => clk,
      reset                     => reset
    );

  a_source: StreamSource_mdl
    generic map (
      NAME                      => "a",
      ELEMENT_WIDTH             => DATA_WIDTH
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      valid                     => a_valid,
      ready                     => a_ready,
      data                      => a_data
    );

  uut: StreamBuffer
    generic map (
      MIN_DEPTH                 => MIN_DEPTH,
      DATA_WIDTH                => DATA_WIDTH
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => a_valid,
      in_ready                  => a_ready,
      in_data                   => a_data,
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
      clk                       => clk,
      reset                     => reset,
      valid                     => b_valid,
      ready                     => b_ready,
      data                      => b_data
    );

end TestBench;

