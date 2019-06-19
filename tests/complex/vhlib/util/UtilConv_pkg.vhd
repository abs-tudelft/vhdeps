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
use ieee.std_logic_misc.all;

package UtilConv_pkg is

  -- Returns a as integer
  function int(a : in std_logic_vector) return integer;
  function int(a : in unsigned) return integer;
  function int(a : in signed) return integer;

  -- Returns a as std_logic_vector
  function slv(a : in integer; b : in natural) return std_logic_vector;
  function slv(a : in unsigned) return std_logic_vector;

  -- Returns the sign-extended version of a with length b
  function sext(a : in unsigned; b : in natural) return unsigned;

  -- Returns a as unsigned
  function u(a : in integer; b : in natural) return unsigned;
  function u(a : in std_logic_vector) return unsigned;
  function u(a : in std_logic) return unsigned;

  -- Returns a as std_logic
  function l(a : in boolean) return std_logic;

end UtilConv_pkg;

package body UtilConv_pkg is


  function int (a : in std_logic_vector) return integer is
  begin
    return                  to_integer(unsigned(a));
  end function int;

  function int (a : in unsigned) return integer is
  begin
    return                  to_integer(a);
  end function int;

  function int (a : in signed) return integer is
  begin
    return                  to_integer(a);
  end function int;

  function slv (a : in integer; b : in natural) return std_logic_vector is
  begin
    return                  std_logic_vector(to_unsigned(a, b));
  end function slv;

  function slv (a : in unsigned) return std_logic_vector is
  begin
    return                  std_logic_vector(a);
  end function slv;

  function sext (a : in unsigned; b : in natural) return unsigned is
    variable result : unsigned(b-1 downto 0);
  begin
    result(a'high downto 0) := a;
    result(b-1 downto a'high+1) := (others => a(a'high));
    return result;
  end function sext;

  function u (a : in integer; b : in natural) return unsigned is
  begin
    return to_unsigned(a, b);
  end function u;

  function u (a : in std_logic_vector) return unsigned is
  begin
    return                  unsigned(a);
  end function u;

  function u (a : in std_logic) return unsigned is
    variable result         : unsigned(0 downto 0);
  begin
    if a='1' then
      result                := u("1");
    else
      result                := u("0");
    end if;
    return result;
  end function u;

  function l (a: in boolean) return std_logic is
    variable result         : std_logic;
  begin
    if a then
      result                := '1';
    else
      result                := '0';
    end if;
    return                  result;
  end function l;

end UtilConv_pkg;
