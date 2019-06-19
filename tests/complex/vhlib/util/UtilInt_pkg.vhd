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

package UtilInt_pkg is

  -- Array of naturals.
  type nat_array is array (natural range <>) of natural;

  -- Functions to compute the prefix sums of an array of naturals. psum returns
  -- an array of the same size as the input containing the prefix sums as they
  -- are usually defined; cumulative starts with the fixed value 0, and thus
  -- has one element extra.
  function psum(x: nat_array) return nat_array;
  function cumulative(x: nat_array) return nat_array;

  -- Returns the sum of an array of naturals.
  function sum(x: nat_array) return natural;

  -- Min/max functions.
  function imin(a: integer; b: integer) return integer;
  function imax(a: integer; b: integer) return integer;

  -- Returns ceil(log2(i)).
  function log2ceil(i: natural) return natural;

  -- Returns floor(log2(i)).
  function log2floor(i: natural) return natural;

  -- Returns (n + d - 1) / d == ceil(n / d).
  function divCeil(n: natural; d: natural) return natural;

end UtilInt_pkg;

package body UtilInt_pkg is

  function psum(x: nat_array) return nat_array is
    variable accumulator  : natural;
    variable y            : nat_array(x'range);
  begin
    accumulator := 0;
    for i in 0 to x'length-1 loop
      accumulator := accumulator + x(i);
      y(i) := accumulator;
    end loop;
    return y;
  end function;

  function cumulative(x: nat_array) return nat_array is
    variable y : nat_array(x'length downto 0);
  begin
    y(0) := 0;
    for i in 0 to x'length-1 loop
      y(i+1) := y(i) + x(i);
    end loop;
    return y;
  end cumulative;

  function sum(x: nat_array) return natural is
    variable accumulator  : natural;
  begin
    accumulator := 0;
    for i in 0 to x'length-1 loop
      accumulator := accumulator + x(i);
    end loop;
    return accumulator;
  end function;

  function imin(a: integer; b: integer) return integer is
  begin
    if a < b then
      return a;
    else
      return b;
    end if;
  end function;

  function imax(a: integer; b: integer) return integer is
  begin
    if a > b then
      return a;
    else
      return b;
    end if;
  end function;

  function log2ceil(i: natural) return natural is
    variable x, y : natural;
  begin
    x := i;
    y := 0;
    while x > 1 loop
      x := (x + 1) / 2;
      y := y + 1;
    end loop;
    return y;
  end function;

  function log2floor(i: natural) return natural is
    variable x, y : natural;
  begin
    x := i;
    y := 0;
    while x > 1 loop
      x := x / 2;
      y := y + 1;
    end loop;
    return y;
  end function;

  function divCeil(n: natural; d: natural) return natural is
  begin
    return (n + d - 1) / d;
  end function;

end UtilInt_pkg;
