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

library std;
use std.textio.all;

library work;
use work.TestCase_pkg.all;
use work.SimDataComms_pkg.all;

-- This package provides the component declaration and control functions for
-- ClockGen_mdl.

package ClockGen_pkg is

  -- Component declaration.
  component ClockGen_mdl is
    generic (
      NAME                      : string := "clock";
      AUTOSTART                 : boolean := true;
      INIT_PERIOD               : time := 10 ns;
      INIT_DUTY                 : time := 0 ns;
      INIT_JITTER_RES           : time := 1 ns;
      INIT_JITTER_MAX           : natural := 0;
      INIT_RESET_CYC            : natural := 10;
      PHASE                     : time := 0 ns
    );
    port (
      clk                       : out std_logic := '0';
      clk_n                     : out std_logic := '1';
      reset                     : out std_logic := '1';
      reset_n                   : out std_logic := '0'
    );
  end component;

  -- Stream source control interface.
  type clockgen_type is protected

    -- Links this interface to a ClockGen model. This should be called
    -- before anything else.
    procedure       initialize    (nam : string := "clock");
    impure function name          return string;

  end protected clockgen_type;

  -- Communication global for ClockGen instances.
  shared variable clkgen    : sc_data_type;

end package ClockGen_pkg;

package body ClockGen_pkg is

  -- Stream source control interface.
  type clockgen_type is protected body

    --#########################################################################
    -- Private entries.
    --#########################################################################

    -- Name of the linked model.
    variable n              : line;


    --#########################################################################
    -- Links this interface to a ClockGen model. This should be called
    -- before anything else.
    --#########################################################################
    procedure initialize(nam : string := "clock") is
    begin
      tc_check_nw(clkgen.exists(nam), "Could not find ClockGen " & nam);
      n := new string'(nam);
    end procedure;

    impure function name return string is
    begin
      return n.all;
    end function;

  end protected body clockgen_type;

end package body ClockGen_pkg;
