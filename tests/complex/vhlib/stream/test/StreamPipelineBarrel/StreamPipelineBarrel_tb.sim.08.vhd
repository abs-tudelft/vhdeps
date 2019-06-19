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
use work.TestCase_pkg.all;

entity StreamPipelineBarrel_tb is
  generic (
    NUM_PIPE_REGS               : natural := 3
  );
end StreamPipelineBarrel_tb;

architecture TestBench of StreamPipelineBarrel_tb is

  signal clk                    : std_logic;
  signal reset                  : std_logic;

  signal a_valid                : std_logic;
  signal a_ready                : std_logic;
  signal a_data                 : std_logic_vector(11 downto 0);

  signal b_valid                : std_logic;
  signal b_ready                : std_logic;
  signal b_data                 : std_logic_vector(63 downto 0);

  signal pipe_input             : std_logic_vector(11 downto 0);
  signal pipe_output            : std_logic_vector(63 downto 0);

begin

  clkgen: ClockGen_mdl
    port map (
      clk                       => clk,
      reset                     => reset
    );

  a_source: StreamSource_mdl
    generic map (
      NAME                      => "a",
      ELEMENT_WIDTH             => 12
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      valid                     => a_valid,
      ready                     => a_ready,
      data                      => a_data
    );

  ctrl: StreamPipelineControl
    generic map (
      IN_DATA_WIDTH             => 12,
      OUT_DATA_WIDTH            => 64,
      NUM_PIPE_REGS             => NUM_PIPE_REGS
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => a_valid,
      in_ready                  => a_ready,
      in_data                   => a_data,
      out_valid                 => b_valid,
      out_ready                 => b_ready,
      out_data                  => b_data,
      pipe_input                => pipe_input,
      pipe_output               => pipe_output
    );

  uut_rotate_left: entity work.StreamPipelineBarrel
    generic map (
      ELEMENT_COUNT             => 8,
      AMOUNT_WIDTH              => 4,
      DIRECTION                 => "left",
      OPERATION                 => "rotate",
      NUM_STAGES                => NUM_PIPE_REGS
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_data                   => pipe_input(7 downto 0),
      in_amount                 => pipe_input(11 downto 8),
      out_data                  => pipe_output(7 downto 0)
    );

  uut_shift_left: entity work.StreamPipelineBarrel
    generic map (
      ELEMENT_COUNT             => 8,
      AMOUNT_WIDTH              => 4,
      DIRECTION                 => "left",
      OPERATION                 => "shift",
      NUM_STAGES                => NUM_PIPE_REGS
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_data                   => pipe_input(7 downto 0),
      in_amount                 => pipe_input(11 downto 8),
      out_data                  => pipe_output(15 downto 8)
    );

  uut_arithmetic_left: entity work.StreamPipelineBarrel
    generic map (
      ELEMENT_COUNT             => 8,
      AMOUNT_WIDTH              => 4,
      DIRECTION                 => "left",
      OPERATION                 => "arithmetic",
      NUM_STAGES                => NUM_PIPE_REGS
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_data                   => pipe_input(7 downto 0),
      in_amount                 => pipe_input(11 downto 8),
      out_data                  => pipe_output(23 downto 16)
    );

  uut_arithmetic_left_multi: entity work.StreamPipelineBarrel
    generic map (
      ELEMENT_WIDTH             => 2,
      ELEMENT_COUNT             => 4,
      AMOUNT_WIDTH              => 4,
      DIRECTION                 => "left",
      OPERATION                 => "arithmetic",
      NUM_STAGES                => NUM_PIPE_REGS
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_data                   => pipe_input(7 downto 0),
      in_amount                 => pipe_input(11 downto 8),
      out_data                  => pipe_output(31 downto 24)
    );

  uut_rotate_right: entity work.StreamPipelineBarrel
    generic map (
      ELEMENT_COUNT             => 8,
      AMOUNT_WIDTH              => 4,
      DIRECTION                 => "right",
      OPERATION                 => "rotate",
      NUM_STAGES                => NUM_PIPE_REGS
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_data                   => pipe_input(7 downto 0),
      in_amount                 => pipe_input(11 downto 8),
      out_data                  => pipe_output(39 downto 32)
    );

  uut_shift_right: entity work.StreamPipelineBarrel
    generic map (
      ELEMENT_COUNT             => 8,
      AMOUNT_WIDTH              => 4,
      DIRECTION                 => "right",
      OPERATION                 => "shift",
      NUM_STAGES                => NUM_PIPE_REGS
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_data                   => pipe_input(7 downto 0),
      in_amount                 => pipe_input(11 downto 8),
      out_data                  => pipe_output(47 downto 40)
    );

  uut_arithmetic_right: entity work.StreamPipelineBarrel
    generic map (
      ELEMENT_COUNT             => 8,
      AMOUNT_WIDTH              => 4,
      DIRECTION                 => "right",
      OPERATION                 => "arithmetic",
      NUM_STAGES                => NUM_PIPE_REGS
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_data                   => pipe_input(7 downto 0),
      in_amount                 => pipe_input(11 downto 8),
      out_data                  => pipe_output(55 downto 48)
    );

  uut_arithmetic_right_multi: entity work.StreamPipelineBarrel
    generic map (
      ELEMENT_WIDTH             => 2,
      ELEMENT_COUNT             => 4,
      AMOUNT_WIDTH              => 4,
      DIRECTION                 => "right",
      OPERATION                 => "arithmetic",
      NUM_STAGES                => NUM_PIPE_REGS
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_data                   => pipe_input(7 downto 0),
      in_amount                 => pipe_input(11 downto 8),
      out_data                  => pipe_output(63 downto 56)
    );

  b_sink: StreamSink_mdl
    generic map (
      NAME                      => "b",
      ELEMENT_WIDTH             => 64
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      valid                     => b_valid,
      ready                     => b_ready,
      data                      => b_data
    );

end TestBench;

