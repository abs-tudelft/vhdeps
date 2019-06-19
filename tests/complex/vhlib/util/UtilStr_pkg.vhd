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

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

library std;
use std.textio.all;

--=============================================================================
-- This package contains basic simulation/elaboration-only utilities, primarily
-- focussed on string manipulation.
-------------------------------------------------------------------------------
package UtilStr_pkg is
--=============================================================================

  -- pragma translate_off

  -----------------------------------------------------------------------------
  -- Basic string manipulation
  -----------------------------------------------------------------------------
  -- Returns true if given character is alphabetical.
  function isAlphaChar(c: character) return boolean;

  -- Returns true if given character is numeric.
  function isNumericChar(c: character) return boolean;

  -- Returns true if given character is alphanumerical.
  function isAlphaNumericChar(c: character) return boolean;

  -- Returns true if given character is whitespace.
  function isWhitespaceChar(c: character) return boolean;

  -- Returns true if given character is a special character (not alphanumerical
  -- and not whitespace).
  function isSpecialChar(c: character) return boolean;

  -- Converts a character to lower- or uppercase.
  function lowerChar(c: character) return character;
  function upperChar(c: character) return character;

  -- Converts a character to its numeric value, supporting all hexadecimal
  -- digits. Returns -1 when the character is not hexadecimal.
  function charToDigitVal(c: character) return integer;

  -- Converts a hex character to an std_logic_vector of length 4. U, X, L, H,
  -- and Z are supported in addition to hex characters.
  function charToSlv(c: character) return std_logic_vector;

  -- Tests whether two characters match, ignoring case.
  function charsEqualI(a: character; b: character) return boolean;

  -- Case-insensitive string matching.
  function matchStrI(
    s1    : in string;
    s2    : in string
  ) return boolean;

  -- Tests whether line contains match at position pos (case insensitive).
  function matchAtI(
    line  : in string;   -- String to match in.
    pos   : in positive; -- Position in line where matching should start.
    match : in string    -- The string to match.
  ) return boolean;

  -- Tests whether line contains match at position pos (case insensitive).
  function matchAt(
    line  : in string;   -- String to match in.
    pos   : in positive; -- Position in line where matching should start.
    match : in string    -- The string to match.
  ) return boolean;

  -- Converts stuff to a string, representing it in unsigned decimal notation.
  function slvToUDec(value: std_logic_vector) return string;
  function unsToUDec(value: unsigned) return string;
  function intToUDec(value: integer) return string;

  -- Converts stuff to a string, representing it in signed decimal notation.
  function slvToDec(value: std_logic_vector) return string;
  function sgnToDec(value: signed) return string;
  function intToDec(value: integer) return string;

  -- Converts stuff to a string in hexadecimal notation,
  -- prefixing 0x.
  function slvToHex(value: std_logic_vector) return string;
  function slvToHex(value: std_logic_vector; digits: natural) return string;
  function unsToHex(value: unsigned) return string;
  function unsToHex(value: unsigned; digits: natural) return string;
  function sgnToHex(value: signed) return string;
  function sgnToHex(value: signed; digits: natural) return string;
  function intToHex(value: integer) return string;
  function intToHex(value: integer; digits: natural) return string;

  -- Converts stuff to a string in hexadecimal notation,
  -- WITHOUT prefixing 0x.
  function slvToHexNo0x(value: std_logic_vector) return string;
  function slvToHexNo0x(value: std_logic_vector; digits: natural) return string;
  function unsToHexNo0x(value: unsigned) return string;
  function unsToHexNo0x(value: unsigned; digits: natural) return string;
  function sgnToHexNo0x(value: signed) return string;
  function sgnToHexNo0x(value: signed; digits: natural) return string;
  function intToHexNo0x(value: integer) return string;
  function intToHexNo0x(value: integer; digits: natural) return string;

  -- Converts stuff to a string in binary notation,
  -- prefixing 0b.
  function slvToBin(value: std_logic_vector) return string;
  function slvToBin(value: std_logic_vector; digits: natural) return string;
  function unsToBin(value: unsigned) return string;
  function unsToBin(value: unsigned; digits: natural) return string;
  function sgnToBin(value: signed) return string;
  function sgnToBin(value: signed; digits: natural) return string;
  function intToBin(value: integer) return string;
  function intToBin(value: integer; digits: natural) return string;

  -- Converts an std_logic_vector to a string in binary notation,
  -- WITHOUT prefixing 0b.
  function slvToBinNo0x(value: std_logic_vector) return string;
  function slvToBinNo0x(value: std_logic_vector; digits: natural) return string;
  function unsToBinNo0x(value: unsigned) return string;
  function unsToBinNo0x(value: unsigned; digits: natural) return string;
  function sgnToBinNo0x(value: signed) return string;
  function sgnToBinNo0x(value: signed; digits: natural) return string;
  function intToBinNo0x(value: integer) return string;
  function intToBinNo0x(value: integer; digits: natural) return string;

  -- Dumps the given string to stdout. Works like a report statement, but
  -- doesn't have all the simulator fluff around it.
  procedure println(s: string);

  -- pragma translate_on

end UtilStr_pkg;

--=============================================================================
package body UtilStr_pkg is
--=============================================================================

  -- pragma translate_off

  function isAlphaChar(c: character) return boolean is
    variable result: boolean;
  begin
    case c is
      when 'a' => result := true; when 'A' => result := true;
      when 'b' => result := true; when 'B' => result := true;
      when 'c' => result := true; when 'C' => result := true;
      when 'd' => result := true; when 'D' => result := true;
      when 'e' => result := true; when 'E' => result := true;
      when 'f' => result := true; when 'F' => result := true;
      when 'g' => result := true; when 'G' => result := true;
      when 'h' => result := true; when 'H' => result := true;
      when 'i' => result := true; when 'I' => result := true;
      when 'j' => result := true; when 'J' => result := true;
      when 'k' => result := true; when 'K' => result := true;
      when 'l' => result := true; when 'L' => result := true;
      when 'm' => result := true; when 'M' => result := true;
      when 'n' => result := true; when 'N' => result := true;
      when 'o' => result := true; when 'O' => result := true;
      when 'p' => result := true; when 'P' => result := true;
      when 'q' => result := true; when 'Q' => result := true;
      when 'r' => result := true; when 'R' => result := true;
      when 's' => result := true; when 'S' => result := true;
      when 't' => result := true; when 'T' => result := true;
      when 'u' => result := true; when 'U' => result := true;
      when 'v' => result := true; when 'V' => result := true;
      when 'w' => result := true; when 'W' => result := true;
      when 'x' => result := true; when 'X' => result := true;
      when 'y' => result := true; when 'Y' => result := true;
      when 'z' => result := true; when 'Z' => result := true;
      when others => result := false;
    end case;
    return result;
  end function;

  function isNumericChar(c: character) return boolean is
    variable result: boolean;
  begin
    case c is
      when '0' => result := true; when '1' => result := true;
      when '2' => result := true; when '3' => result := true;
      when '4' => result := true; when '5' => result := true;
      when '6' => result := true; when '7' => result := true;
      when '8' => result := true; when '9' => result := true;
      when others => result := false;
    end case;
    return result;
  end function;

  function isAlphaNumericChar(c: character) return boolean is
  begin
    return isAlphaChar(c) or isNumericChar(c);
  end function;

  function isWhitespaceChar(c: character) return boolean is
    variable result: boolean;
  begin
    case c is
      when ' ' => result := true;
      when HT => result := true;
      when LF => result := true;
      when CR => result := true;
      when others => result := false;
    end case;
    return result;
  end function;

  function isSpecialChar(c: character) return boolean is
  begin
    return not isAlphaNumericChar(c) and not isWhitespaceChar(c);
  end function;

  function lowerChar(
    c: character
  ) return character is
    variable result: character;
  begin
    case c is
      when 'A' => result := 'a';
      when 'B' => result := 'b';
      when 'C' => result := 'c';
      when 'D' => result := 'd';
      when 'E' => result := 'e';
      when 'F' => result := 'f';
      when 'G' => result := 'g';
      when 'H' => result := 'h';
      when 'I' => result := 'i';
      when 'J' => result := 'j';
      when 'K' => result := 'k';
      when 'L' => result := 'l';
      when 'M' => result := 'm';
      when 'N' => result := 'n';
      when 'O' => result := 'o';
      when 'P' => result := 'p';
      when 'Q' => result := 'q';
      when 'R' => result := 'r';
      when 'S' => result := 's';
      when 'T' => result := 't';
      when 'U' => result := 'u';
      when 'V' => result := 'v';
      when 'W' => result := 'w';
      when 'X' => result := 'x';
      when 'Y' => result := 'y';
      when 'Z' => result := 'z';
      when others => result := c;
    end case;
    return result;
  end function;

  function upperChar(
    c: character
  ) return character is
    variable result: character;
  begin
    case c is
      when 'a' => result := 'A';
      when 'b' => result := 'B';
      when 'c' => result := 'C';
      when 'd' => result := 'D';
      when 'e' => result := 'E';
      when 'f' => result := 'F';
      when 'g' => result := 'G';
      when 'h' => result := 'H';
      when 'i' => result := 'I';
      when 'j' => result := 'J';
      when 'k' => result := 'K';
      when 'l' => result := 'L';
      when 'm' => result := 'M';
      when 'n' => result := 'N';
      when 'o' => result := 'O';
      when 'p' => result := 'P';
      when 'q' => result := 'Q';
      when 'r' => result := 'R';
      when 's' => result := 'S';
      when 't' => result := 'T';
      when 'u' => result := 'U';
      when 'v' => result := 'V';
      when 'w' => result := 'W';
      when 'x' => result := 'X';
      when 'y' => result := 'Y';
      when 'z' => result := 'Z';
      when others => result := c;
    end case;
    return result;
  end function;

  function charToDigitVal(
    c: character
  ) return integer is
    variable result: integer;
  begin
    case c is
      when '0' => result := 0;
      when '1' => result := 1;
      when '2' => result := 2;
      when '3' => result := 3;
      when '4' => result := 4;
      when '5' => result := 5;
      when '6' => result := 6;
      when '7' => result := 7;
      when '8' => result := 8;
      when '9' => result := 9;
      when 'a' => result := 10;
      when 'b' => result := 11;
      when 'c' => result := 12;
      when 'd' => result := 13;
      when 'e' => result := 14;
      when 'f' => result := 15;
      when 'A' => result := 10;
      when 'B' => result := 11;
      when 'C' => result := 12;
      when 'D' => result := 13;
      when 'E' => result := 14;
      when 'F' => result := 15;
      when others => result := -1;
    end case;
    return result;
  end function;

  function charToSlv(c: character) return std_logic_vector is
    variable intVal : integer;
  begin
    intVal := charToDigitVal(c);
    if intVal > -1 then
      return std_logic_vector(to_unsigned(intVal, 4));
    end if;
    case c is
      when 'L' => return "LLLL";
      when 'H' => return "HHHH";
      when 'U' => return "UUUU";
      when 'Z' => return "ZZZZ";
      when '-' => return "----";
      when others => return "XXXX";
    end case;
  end function;

  function charsEqualI(
    a: character;
    b: character
  ) return boolean is
  begin
    return upperChar(a) = upperChar(b);
  end function;

  function matchStrI(
    s1    : in string;
    s2    : in string
  ) return boolean is
  begin
    if s1'length /= s2'length then
      return false;
    end if;
    for i in s1'range loop
      if not charsEqualI(s1(i), s2(i+s2'low-s1'low)) then
        return false;
      end if;
    end loop;
    return true;
  end function;

  function matchAtI(
    line  : in string;
    pos   : in positive;
    match : in string
  ) return boolean is
    variable posInt: positive;
  begin
    posInt := pos;
    for matchPos in match'range loop
      if posInt > line'length then
        return false;
      end if;
      if not charsEqualI(match(matchPos), line(posInt)) then
        return false;
      end if;
      posInt := posInt + 1;
    end loop;
    return true;
  end function;

  function matchAt(
    line  : in string;
    pos   : in positive;
    match : in string
  ) return boolean is
    variable posInt: positive;
  begin
    posInt := pos;
    for matchPos in match'range loop
      if posInt > line'length then
        return false;
      end if;
      if match(matchPos) /= line(posInt) then
        return false;
      end if;
      posInt := posInt + 1;
    end loop;
    return true;
  end function;

  function slvToUDec(value: std_logic_vector) return string is
    variable temp : unsigned(value'length-1 downto 0);
    variable digit : integer;
    constant STR_LEN : natural := (value'length / 3) + 1;
    variable s : string(1 to STR_LEN);
    variable index : natural;
  begin
    temp := unsigned(value);
    if temp = 0 then
      return "0";
    end if;
    index := STR_LEN;
    while temp > 0 loop
      digit := to_integer(temp mod 10);
      temp := temp / 10;
      case digit is
        when 0 => s(index) := '0';
        when 1 => s(index) := '1';
        when 2 => s(index) := '2';
        when 3 => s(index) := '3';
        when 4 => s(index) := '4';
        when 5 => s(index) := '5';
        when 6 => s(index) := '6';
        when 7 => s(index) := '7';
        when 8 => s(index) := '8';
        when 9 => s(index) := '9';
        when others => s(index) := '?';
      end case;
      index := index - 1;
    end loop;
    return s(index+1 to STR_LEN);
  end function;

  function unsToUDec(value: unsigned) return string is
  begin
    return slvToUDec(std_logic_vector(value));
  end function;

  function intToUDec(value: integer) return string is
  begin
    return integer'image(value);
  end function;

  function slvToDec(value: std_logic_vector) return string is
    variable temp : signed(value'length-1 downto 0);
  begin
    temp := signed(value);
    if temp = 0 then
      return "0";
    elsif temp > 0 then
      return slvToUDec(std_logic_vector(temp));
    else
      return "-" & slvToUDec(std_logic_vector(0-temp));
    end if;
  end function;

  function sgnToDec(value: signed) return string is
  begin
    return slvToDec(std_logic_vector(value));
  end function;

  function intToDec(value: integer) return string is
  begin
    return integer'image(value);
  end function;

  function slvToHex(value: std_logic_vector) return string is
  begin
    return "0x" & slvToHexNo0x(value);
  end function;

  function slvToHex(value: std_logic_vector; digits: natural) return string is
  begin
    return "0x" & slvToHexNo0x(value, digits);
  end function;

  function unsToHex(value: unsigned) return string is
  begin
    return "0x" & unsToHexNo0x(value);
  end function;

  function unsToHex(value: unsigned; digits: natural) return string is
  begin
    return "0x" & unsToHexNo0x(value, digits);
  end function;

  function sgnToHex(value: signed) return string is
  begin
    return "0x" & sgnToHexNo0x(value);
  end function;

  function sgnToHex(value: signed; digits: natural) return string is
  begin
    return "0x" & sgnToHexNo0x(value, digits);
  end function;

  function intToHex(value: integer) return string is
  begin
    return "0x" & intToHexNo0x(value);
  end function;

  function intToHex(value: integer; digits: natural) return string is
  begin
    return "0x" & intToHexNo0x(value, digits);
  end function;

  function slvToHexNo0x(value: std_logic_vector) return string is
  begin
    return slvToHexNo0x(value, (value'length-1) / 4 + 1);
  end slvToHexNo0x;

  function extractStdLogicVectRange(
    slv     : std_logic_vector;
    low     : natural;
    len     : natural;
    def     : std_logic
  ) return std_logic_vector is
    variable ret  : std_logic_vector(len-1 downto 0) := (others => def);
  begin
    for i in 0 to len-1 loop
      if i + low >= slv'low and i + low <= slv'high then
        ret(i) := slv(i + low);
      end if;
    end loop;
    return ret;
  end function;

  function slvToHexNo0x(value: std_logic_vector; digits: natural) return string is
    variable normalized : std_logic_vector(value'length-1 downto 0);
    variable s : string(1 to digits);
    variable temp : std_logic_vector(3 downto 0);
  begin
    normalized := value;
    for i in 0 to digits-1 loop
      temp := to_X01Z(extractStdLogicVectRange(normalized, i*4, 4, '0'));
      case temp is
        when "0000" => s(digits-i) := '0';
        when "0001" => s(digits-i) := '1';
        when "0010" => s(digits-i) := '2';
        when "0011" => s(digits-i) := '3';
        when "0100" => s(digits-i) := '4';
        when "0101" => s(digits-i) := '5';
        when "0110" => s(digits-i) := '6';
        when "0111" => s(digits-i) := '7';
        when "1000" => s(digits-i) := '8';
        when "1001" => s(digits-i) := '9';
        when "1010" => s(digits-i) := 'A';
        when "1011" => s(digits-i) := 'B';
        when "1100" => s(digits-i) := 'C';
        when "1101" => s(digits-i) := 'D';
        when "1110" => s(digits-i) := 'E';
        when "1111" => s(digits-i) := 'F';
        when others =>
          temp := extractStdLogicVectRange(normalized, i*4, 4, '0');
          case temp is
            when "XXXX" => s(digits-i) := 'X';
            when "UUUU" => s(digits-i) := 'U';
            when "LLLL" => s(digits-i) := 'L';
            when "HHHH" => s(digits-i) := 'H';
            when "ZZZZ" => s(digits-i) := 'Z';
            when "----" => s(digits-i) := '-';
            when others => s(digits-i) := '?';
          end case;
      end case;
    end loop;
    return s;
  end slvToHexNo0x;

  function unsToHexNo0x(value: unsigned) return string is
  begin
    return slvToHexNo0x(std_logic_vector(value));
  end function;

  function unsToHexNo0x(value: unsigned; digits: natural) return string is
  begin
    return slvToHexNo0x(std_logic_vector(value), digits);
  end function;

  function sgnToHexNo0x(value: signed) return string is
  begin
    return slvToHexNo0x(std_logic_vector(value));
  end function;

  function sgnToHexNo0x(value: signed; digits: natural) return string is
  begin
    return slvToHexNo0x(std_logic_vector(value), digits);
  end function;

  function intToHexNo0x(value: integer) return string is
  begin
    return intToHexNo0x(value, 8);
  end function;

  function intToHexNo0x(value: integer; digits: natural) return string is
  begin
    return slvToHexNo0x(std_logic_vector(to_unsigned(value, digits*4)), digits);
  end function;

  function slvToBin(value: std_logic_vector) return string is
  begin
    return "0b" & slvToBinNo0x(value);
  end function;

  function slvToBin(value: std_logic_vector; digits: natural) return string is
  begin
    return "0b" & slvToBinNo0x(value, digits);
  end function;

  function unsToBin(value: unsigned) return string is
  begin
    return "0b" & unsToBinNo0x(value);
  end function;

  function unsToBin(value: unsigned; digits: natural) return string is
  begin
    return "0b" & unsToBinNo0x(value, digits);
  end function;

  function sgnToBin(value: signed) return string is
  begin
    return "0b" & sgnToBinNo0x(value);
  end function;

  function sgnToBin(value: signed; digits: natural) return string is
  begin
    return "0b" & sgnToBinNo0x(value, digits);
  end function;

  function intToBin(value: integer) return string is
  begin
    return "0b" & intToBinNo0x(value);
  end function;

  function intToBin(value: integer; digits: natural) return string is
  begin
    return "0b" & intToBinNo0x(value, digits);
  end function;

  function slvToBinNo0x(value: std_logic_vector) return string is
  begin
    return slvToBinNo0x(value, value'length);
  end function;

  function slvToBinNo0x(value: std_logic_vector; digits: natural) return string is
    variable normalized : std_logic_vector(value'length-1 downto 0);
    variable s : string(1 to digits);
    variable temp : std_logic_vector(0 downto 0);
  begin
    normalized := value;
    for i in 0 to digits-1 loop
      temp := extractStdLogicVectRange(normalized, i, 1, '0');
      case temp is
        when "0" => s(digits-i) := '0';
        when "1" => s(digits-i) := '1';
        when "X" => s(digits-i) := 'X';
        when "U" => s(digits-i) := 'U';
        when "L" => s(digits-i) := 'L';
        when "H" => s(digits-i) := 'H';
        when "Z" => s(digits-i) := 'Z';
        when "-" => s(digits-i) := '-';
        when others => s(digits-i) := '?';
      end case;
    end loop;
    return s;
  end function;

  function unsToBinNo0x(value: unsigned) return string is
  begin
    return slvToBinNo0x(std_logic_vector(value));
  end function;

  function unsToBinNo0x(value: unsigned; digits: natural) return string is
  begin
    return slvToBinNo0x(std_logic_vector(value), digits);
  end function;

  function sgnToBinNo0x(value: signed) return string is
  begin
    return slvToBinNo0x(std_logic_vector(value));
  end function;

  function sgnToBinNo0x(value: signed; digits: natural) return string is
  begin
    return slvToBinNo0x(std_logic_vector(value), digits);
  end function;

  function intToBinNo0x(value: integer) return string is
  begin
    return intToBinNo0x(value, 32);
  end function;

  function intToBinNo0x(value: integer; digits: natural) return string is
  begin
    return slvToBinNo0x(std_logic_vector(to_unsigned(value, digits)), digits);
  end function;

  procedure println(s: string) is
    variable ln : std.textio.line;
  begin
    ln := new string(1 to s'length);
    ln.all := s;
    writeline(std.textio.output, ln);
    if ln /= null then
      deallocate(ln);
    end if;
  end procedure;

  -- pragma translate_on

end UtilStr_pkg;
