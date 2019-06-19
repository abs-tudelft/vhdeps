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
use ieee.math_real.all;

library work;
use work.TestCase_pkg.all;
use work.SimDataComms_pkg.all;
use work.ClockGen_pkg.all;

-- This unit generates a clock and an associated synchronous reset.

entity ClockGen_mdl is
  generic (
    NAME                        : string := "clock";

    -- When set, this clock starts automatically (without test case
    -- configuration).
    AUTOSTART                   : boolean := true;

    -- Initial clock period.
    INIT_PERIOD                 : time := 10 ns;

    -- Initial high time.
    INIT_DUTY                   : time := 0 ns;

    -- Jitter configuration. The edges deviate from perfect by +/- max*res,
    -- with steps of res.
    INIT_JITTER_RES             : time := 1 ns;
    INIT_JITTER_MAX             : natural := 0;

    -- Number of cycles to assert reset at the start of each test case.
    INIT_RESET_CYC              : natural := 10;

    -- Delay before the clock process is started.
    PHASE                       : time := 0 ns

  );
  port (
    clk                         : out std_logic := '0';
    clk_n                       : out std_logic := '1';
    reset                       : out std_logic := '1';
    reset_n                     : out std_logic := '0'
  );
end ClockGen_mdl;

architecture Model of ClockGen_mdl is

  signal sync   : std_logic := '0';
  signal clk_i  : std_logic := '0';

begin

  sync_proc: process is
  begin
    wait for TC_SYNC_PERIOD;
    sync <= not sync;
    tc_yield;
  end process;

  clk_proc: process is
    variable jitter     : integer := 0;
    variable seed1      : positive := 5381;
    variable seed2      : positive := 1;

    procedure jittered_delay(nom : time) is
      variable res      : time;
      variable rand     : real;
      variable new_jit  : integer;
      variable delta_jit: integer;
      variable delta_tim: time;
    begin
      res := clkgen.get_time(NAME & ".jitter_res");
      uniform(seed1, seed2, rand);
      new_jit := integer(round((rand * 2.0 - 1.0) * real(clkgen.get_int(NAME & ".jitter_max"))));
      delta_jit := new_jit - jitter;
      delta_tim := nom + res * delta_jit;
      while delta_tim <= 0 ns loop
        new_jit := new_jit + 1;
        delta_tim := delta_tim + res;
      end loop;
      wait for delta_tim;
      jitter := new_jit;
      tc_yield;
    end procedure;

    variable high_time  : time;
    variable low_time   : time;
  begin
    tc_check(not clkgen.exists(NAME), "Duplicate ClockGen with name " & NAME & ".");
    clkgen.set_bool(NAME & ".exists", true);
    if AUTOSTART then
      tc_model_init <= '1';
    else
      tc_model_init <= 'Z';
    end if;
    tc_model_registered("ClockGen", NAME);
    seed1 := tc_random_seed(NAME);
    tc: loop
      clkgen.set_bool(NAME & ".run",            AUTOSTART);
      clkgen.set_bool(NAME & ".initial_reset",  AUTOSTART);
      clkgen.set_time(NAME & ".period",         INIT_PERIOD);
      clkgen.set_time(NAME & ".duty",           INIT_DUTY);
      clkgen.set_time(NAME & ".jitter_res",     INIT_JITTER_RES);
      clkgen.set_int (NAME & ".jitter_max",     INIT_JITTER_MAX);
      clkgen.set_int (NAME & ".reset",          INIT_RESET_CYC);
      if AUTOSTART then
        tc_model_init <= '1';
      else
        tc_model_init <= 'Z';
      end if;
      tc_model_init <= '1';
      wait until sync'event;
      next tc when tc_resetting;
      if PHASE > 0 ns then
        wait for PHASE;
      end if;
      cyc: loop
        high_time := clkgen.get_time(NAME & ".duty");
        if high_time = 0 ns then
          high_time := clkgen.get_time(NAME & ".period");
          low_time := high_time / 2;
          high_time := high_time - low_time;
        else
          low_time := clkgen.get_time(NAME & ".period");
          low_time := low_time - high_time;
        end if;
        if clkgen.get_bool(NAME & ".run") then
          clk <= '1';
          clk_i <= '1';
          clk_n <= '0';
        else
          clk <= '0';
          clk_i <= '0';
          clk_n <= '1';
        end if;
        jittered_delay(high_time);
        if clkgen.get_bool(NAME & ".initial_reset") then
          tc_model_init <= '1';
        else
          tc_model_init <= 'Z';
        end if;
        clk <= '0';
        clk_i <= '0';
        clk_n <= '1';
        jittered_delay(low_time);
        next tc when tc_resetting;
      end loop;
    end loop;
  end process;

  reset_proc: process (clk_i) is
    variable remain : natural;
  begin
    if rising_edge(clk_i) then
      remain := clkgen.get_int(NAME & ".reset");
      if remain > 0 then
        reset <= '1';
        reset_n <= '0';
        clkgen.set_int(NAME & ".reset", remain - 1);
      else
        reset <= '0';
        reset_n <= '1';
        if clkgen.get_bool(NAME & ".initial_reset") then
          clkgen.set_bool(NAME & ".initial_reset", false);
        end if;
      end if;
    end if;
  end process;

end Model;

