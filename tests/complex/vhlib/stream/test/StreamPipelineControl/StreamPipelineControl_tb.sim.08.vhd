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

entity StreamPipelineControl_tb is
  generic (
    NUM_PIPE_REGS               : natural;
    MIN_CYCLES_PER_TRANSFER     : positive;
    INPUT_SLICE                 : boolean
  );
end StreamPipelineControl_tb;

architecture TestBench of StreamPipelineControl_tb is

  subtype pipe_data_type is std_logic_vector(7 downto 0);
  type pipe_data_array is array (natural range <>) of pipe_data_type;

  signal clk                    : std_logic;
  signal reset                  : std_logic;

  signal a_valid                : std_logic;
  signal a_ready                : std_logic;
  signal a_data                 : std_logic_vector(7 downto 0);

  signal b_valid                : std_logic;
  signal b_ready                : std_logic;
  signal b_data                 : std_logic_vector(7 downto 0);

  signal pipe_stall             : std_logic;
  signal pipe_insert            : std_logic := '0';
  signal pipe_delete            : std_logic;
  signal pipe_valid             : std_logic_vector(0 to NUM_PIPE_REGS);
  signal pipe_input             : pipe_data_type;
  signal pipe_regs              : pipe_data_array(1 to NUM_PIPE_REGS);

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
      data                      => a_data
    );

  uut: StreamPipelineControl
    generic map (
      IN_DATA_WIDTH             => 8,
      OUT_DATA_WIDTH            => 8,
      NUM_PIPE_REGS             => NUM_PIPE_REGS,
      MIN_CYCLES_PER_TRANSFER   => MIN_CYCLES_PER_TRANSFER,
      INPUT_SLICE               => INPUT_SLICE
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
      pipe_stall                => pipe_stall,
      pipe_insert               => pipe_insert,
      pipe_delete               => pipe_delete,
      pipe_valid                => pipe_valid,
      pipe_input                => pipe_input,
      pipe_output               => pipe_regs(NUM_PIPE_REGS)
    );

  stall_proc: process is
  begin
    pipe_stall <= '0';
    for i in 1 to 30 loop
      wait until rising_edge(clk);
    end loop;
    pipe_stall <= '1';
    for i in 1 to 10 loop
      wait until rising_edge(clk);
      if reset = '0' then
        tc_check(pipe_valid(0), '0', "stall failed");
      end if;
    end loop;
  end process;

  pipe_delete <= '1' when pipe_regs(NUM_PIPE_REGS) = "00100000" and pipe_valid(NUM_PIPE_REGS) = '1' else '0';

  pipe_reg_proc: process (clk) is
  begin
    if rising_edge(clk) then
      if pipe_valid(0) then
        if pipe_input(6 downto 5) = "10" then
          pipe_insert <= not pipe_insert;
        else
          pipe_insert <= '0';
        end if;
      end if;
      if pipe_insert = '1' then
        pipe_regs(1) <= X"21";
      else
        pipe_regs(1) <= pipe_input;
      end if;
      pipe_regs(2 to NUM_PIPE_REGS) <= pipe_regs(1 to NUM_PIPE_REGS-1);
    end if;
  end process;

  b_sink: StreamSink_mdl
    generic map (
      NAME                      => "b",
      ELEMENT_WIDTH             => 8
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      valid                     => b_valid,
      ready                     => b_ready,
      data                      => b_data
    );

end TestBench;

