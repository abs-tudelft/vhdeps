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

package UtilMisc_pkg is

  -- Returns (s ? t : f).
  function sel(s: boolean; t: integer;          f: integer)          return integer;
  function sel(s: boolean; t: boolean;          f: boolean)          return boolean;
  function sel(s: boolean; t: std_logic_vector; f: std_logic_vector) return std_logic_vector;
  function sel(s: boolean; t: unsigned;         f: unsigned)         return unsigned;
  function sel(s: boolean; t: signed;           f: signed)           return signed;
  function sel(s: boolean; t: std_logic;        f: std_logic)        return std_logic;

  -- Returns a with its byte endianness swapped.
  function endianSwap(a : in std_logic_vector) return std_logic_vector;

  -- Returns the number of '1''s in a
  function countOnes(a : in std_logic_vector) return natural;

  -- Shifts an unsigned left if amount is positive or right if amount is
  -- negative. When shifting right, round_up selects the rounding direction.
  function shift(a: in unsigned; amount: in integer; round_up: boolean := false) return unsigned;

  -- Returns the first integer multiple of 2^b below or equal to a
  function alignDown(a : in unsigned; b : in natural) return unsigned;

  -- Returns the first integer multiple of 2^b above or equal to a
  function alignUp(a : in unsigned; b : in natural) return unsigned;

  -- Returns true if a is an integer multiple of 2^b, false otherwise
  function isAligned(a : in unsigned; b : natural) return boolean;

end UtilMisc_pkg;

package body UtilMisc_pkg is

  function sel(s: boolean; t: integer; f: integer) return integer is
  begin
    if s then
      return t;
    else
      return f;
    end if;
  end function;

  function sel(s: boolean; t: boolean; f: boolean) return boolean is
  begin
    if s then
      return t;
    else
      return f;
    end if;
  end function;

  function sel(s: boolean; t: std_logic_vector; f: std_logic_vector) return std_logic_vector is
  begin
    if s then
      return t;
    else
      return f;
    end if;
  end function;

  function sel(s: boolean; t: unsigned; f: unsigned) return unsigned is
  begin
    if s then
      return t;
    else
      return f;
    end if;
  end function;

  function sel(s: boolean; t: signed; f: signed) return signed is
  begin
    if s then
      return t;
    else
      return f;
    end if;
  end function;

  function sel(s: boolean; t: std_logic; f: std_logic) return std_logic is
  begin
    if s then
      return t;
    else
      return f;
    end if;
  end function;

  function endianSwap(a : in std_logic_vector) return std_logic_vector is
    variable result         : std_logic_vector(a'range);
    constant bytes          : natural := a'length / 8;
  begin
    for i in 0 to bytes - 1 loop
      result(8 * i + 7 downto 8 * i) := a((bytes - 1 - i) * 8 + 7 downto (bytes - 1 - i) * 8);
    end loop;
    return result;
  end function;

  function countOnes(a : in std_logic_vector) return natural is
    variable result : natural := 0;
  begin
    for i in a'range loop
      if a(i) = '1' then
        result := result + 1;
      end if;
    end loop;
    return result;
  end function;

  function shift_right_round_up(a : in unsigned; amount : in natural) return unsigned is
    variable arg_v : unsigned(a'length-1 downto 0);
    variable lsb_v : unsigned(amount-1 downto 0);
  begin
    if amount /= 0 then -- prevent null ranges on lsb_v
      arg_v := shift_right(a, amount);
      lsb_v := a(amount-1 downto 0);
      if (lsb_v /= 0) then
        arg_v := arg_v + 1;
      end if;
    else
      arg_v := a;
    end if;
    return arg_v;
  end function;

  function shift(a: in unsigned; amount: in integer; round_up: boolean := false) return unsigned is
  begin
    if amount >= 0 then
      return shift_left(a, amount);
    elsif round_up then
      return shift_right_round_up(a, -amount);
    else
      return shift_right(a, -amount);
    end if;
  end function;

  function alignDown(a : in unsigned; b : in natural) return unsigned is
    variable arg_v : unsigned(a'length-1 downto 0);
  begin
    if b /= 0 then
      arg_v := shift_right(a,b);
    else
      arg_v := a;
    end if;
    return shift_left(arg_v, b);
  end function;

  function alignUp(a : in unsigned; b : in natural) return unsigned is
    variable arg_v : unsigned(a'length-1 downto 0);
    variable lsb_v : unsigned(b-1 downto 0);
  begin
    -- Do this all over again because xsim seems to have trouble
    -- with specific functions in functions so we cant use
    -- shift_right_round_up
    if b /= 0 then -- prevent null ranges on lsb_v
      arg_v := shift_right(a, b);
      lsb_v := a(b-1 downto 0);
      if (lsb_v /= 0) then
        arg_v := arg_v + 1;
      end if;
    else
      arg_v := a;
    end if;
    return shift_left(arg_v, b);
  end function;

  function isAligned(a : in unsigned; b : natural) return boolean is
    variable lsb_v : unsigned(b-1 downto 0);
  begin
    if b > 0 then
      lsb_v := a(b-1 downto 0);
      if (lsb_v = 0) then
        return true;
      else
        return false;
      end if;
    else
      return true;
    end if;
  end function;

end UtilMisc_pkg;
