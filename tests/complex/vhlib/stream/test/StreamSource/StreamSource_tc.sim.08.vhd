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
use work.TestCase_pkg.all;
use work.StreamSource_pkg.all;
use work.ClockGen_pkg.all;

entity StreamSource_tc is
end StreamSource_tc;

architecture TestCase of StreamSource_tc is

  constant NAME           : string := "test";
  constant ELEMENT_WIDTH  : natural := 7;
  constant COUNT_MAX      : natural := 4;
  constant COUNT_WIDTH    : natural := 3;
  constant CTRL_WIDTH     : natural := 2;
  constant X_WIDTH        : natural := 3;
  constant Y_WIDTH        : natural := 4;
  constant Z_WIDTH        : natural := 5;

  signal clk              : std_logic := '0';
  signal reset            : std_logic := '1';
  signal valid            : std_logic;
  signal ready            : std_logic;
  signal dvalid           : std_logic;
  signal data             : std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
  signal count            : std_logic_vector(COUNT_WIDTH-1 downto 0);
  signal last             : std_logic;
  signal ctrl             : std_logic_vector(CTRL_WIDTH-1 downto 0);
  signal x                : std_logic_vector(X_WIDTH-1 downto 0);
  signal y                : std_logic_vector(Y_WIDTH-1 downto 0);
  signal z                : std_logic_vector(Z_WIDTH-1 downto 0);

begin

  uut : StreamSource_mdl
    generic map (
      NAME            => NAME,
      ELEMENT_WIDTH   => ELEMENT_WIDTH,
      COUNT_MAX       => COUNT_MAX,
      COUNT_WIDTH     => COUNT_WIDTH,
      CTRL_WIDTH      => CTRL_WIDTH,
      X_WIDTH         => X_WIDTH,
      Y_WIDTH         => Y_WIDTH,
      Z_WIDTH         => Z_WIDTH
    )
    port map (
      clk             => clk,
      reset           => reset,
      valid           => valid,
      ready           => ready,
      dvalid          => dvalid,
      data            => data,
      count           => count,
      last            => last,
      ctrl            => ctrl,
      x               => x,
      y               => y,
      z               => z
    );

  clk_inst: ClockGen_mdl port map (clk => clk, reset => reset);

  ready <= '1';

  test_proc: process is
    variable s  : streamsource_type;
  begin
    tc_name("StreamSource", "tests the functionality of the StreamSource model.");
    tc_open;
    s.initialize(NAME);
    s.push_str("The quick brown fox jumped over the lazy dog.");
    s.set_ctrl("01");
    s.transmit(last => true);
    --pq_wait(s, 10 ns, 1000);
    wait for 1 us;
    tc_check(s.pq_get_str, "The quick brown fox jumped over the lazy dog.");
    tc_pass;
    wait;
  end process;

end TestCase;
