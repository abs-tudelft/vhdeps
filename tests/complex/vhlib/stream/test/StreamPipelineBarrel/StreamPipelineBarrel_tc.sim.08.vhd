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
use work.StreamSink_pkg.all;

entity StreamPipelineBarrel_tc is
end StreamPipelineBarrel_tc;

architecture TestCase of StreamPipelineBarrel_tc is
begin

  main_tc: process is
    variable a : streamsource_type;
    variable b : streamsink_type;

    procedure check(
      rol_val : std_logic_vector(7 downto 0);
      sll_val : std_logic_vector(7 downto 0);
      sla_val : std_logic_vector(7 downto 0);
      slx_val : std_logic_vector(7 downto 0);
      ror_val : std_logic_vector(7 downto 0);
      srl_val : std_logic_vector(7 downto 0);
      sra_val : std_logic_vector(7 downto 0);
      srx_val : std_logic_vector(7 downto 0)
    ) is
      variable val : std_logic_vector(63 downto 0);
    begin
      val := b.cq_get_data;
      tc_check(val( 7 downto  0), rol_val, "rol");
      tc_check(val(15 downto  8), sll_val, "sll");
      tc_check(val(23 downto 16), sla_val, "sla");
      tc_check(val(31 downto 24), slx_val, "slx");
      tc_check(val(39 downto 32), ror_val, "ror");
      tc_check(val(47 downto 40), srl_val, "srl");
      tc_check(val(55 downto 48), sra_val, "sra");
      tc_check(val(63 downto 56), srx_val, "srx");
      b.cq_next;
    end procedure;
  begin
    tc_open("StreamPipelineBarrel", "tests StreamPipelineBarrel.");
    a.initialize("a");
    b.initialize("b");

    a.push_slv("0000" & "01010011");
    a.push_slv("0001" & "01010011");
    a.push_slv("0010" & "01010011");
    a.push_slv("0011" & "01010011");
    a.push_slv("0100" & "01010011");
    a.push_slv("0110" & "01010011");
    a.push_slv("1000" & "01010011");

    a.push_slv("0000" & "11001010");
    a.push_slv("0001" & "11001010");
    a.push_slv("0010" & "11001010");
    a.push_slv("0011" & "11001010");
    a.push_slv("0100" & "11001010");
    a.push_slv("0110" & "11001010");
    a.push_slv("1000" & "11001010");
    a.transmit;

    b.unblock;

    tc_wait_for(1 us);

    --       rol         sll         sla        sla*2        ror         srl         sra        sra*2
    check("01010011", "01010011", "01010011", "01010011", "01010011", "01010011", "01010011", "01010011"); -- 0
    check("10100110", "10100110", "10100110", "01001100", "10101001", "00101001", "00101001", "00010100"); -- 1
    check("01001101", "01001100", "01001100", "00110000", "11010100", "00010100", "00010100", "00000101"); -- 2
    check("10011010", "10011000", "10011000", "11000000", "01101010", "00001010", "00001010", "00000001"); -- 3
    check("00110101", "00110000", "00110000", "00000000", "00110101", "00000101", "00000101", "00000000"); -- 4
    check("11010100", "11000000", "11000000", "00000000", "01001101", "00000001", "00000001", "00000000"); -- 6
    check("01010011", "00000000", "00000000", "00000000", "01010011", "00000000", "00000000", "00000000"); -- 8

    --       rol         sll         sla        sla*2        ror         srl         sra        sra*2
    check("11001010", "11001010", "11001010", "11001010", "11001010", "11001010", "11001010", "11001010"); -- 0
    check("10010101", "10010100", "10010100", "00101000", "01100101", "01100101", "11100101", "11110010"); -- 1
    check("00101011", "00101000", "00101000", "10100000", "10110010", "00110010", "11110010", "11111100"); -- 2
    check("01010110", "01010000", "01010000", "10000000", "01011001", "00011001", "11111001", "11111111"); -- 3
    check("10101100", "10100000", "10100000", "00000000", "10101100", "00001100", "11111100", "11111111"); -- 4
    check("10110010", "10000000", "10000000", "00000000", "00101011", "00000011", "11111111", "11111111"); -- 6
    check("11001010", "00000000", "00000000", "00000000", "11001010", "00000000", "11111111", "11111111"); -- 8

    tc_pass;
    wait;
  end process;

  uut: entity work.StreamPipelineBarrel_tb;

end TestCase;

