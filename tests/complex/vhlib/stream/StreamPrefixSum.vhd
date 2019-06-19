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
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library work;
use work.Stream_pkg.all;

-- This unit calculates the prefix sum of an input stream of multiple elements
-- that are considered to be unsigned integers. By default, the prefix sum is
-- computed over last-delimited packets, but the sum can also be cleared at the
-- start of each transfer using in_clear. Furthermore, in_initial can be driven
-- to a nonzero value to start the prefix sum at an offset.
--
-- Symbol:   --->(Pr+)--->
--
-- Future work might consider explicitly implementing Brent-Kung, Kogge-Stone
-- or hybrid approach in case synthesis tools don't do this already.
--
entity StreamPrefixSum is
  generic (

    ---------------------------------------------------------------------------
    -- Input configuration
    ---------------------------------------------------------------------------
    -- Width of a data element, assumed to be an unsigned integer.
    ELEMENT_WIDTH               : natural;

    -- Maximum number of elements per clock in the data input stream.
    COUNT_MAX                   : natural;

    -- The number of bits in the count vectors. This must be at least
    -- ceil(log2(COUNT_MAX)) and must be at least 1. If COUNT_MAX is a power of
    -- two and this value equals log2(COUNT_MAX), a zero count implies that all
    -- entries are valid (i.e., there is an implicit '1' bit in front).
    COUNT_WIDTH                 : natural;

    -- Width of control information. This information travels with the data
    -- stream but is left untouched. Must be at least 1 to prevent null vectors.
    CTRL_WIDTH                  : natural := 1

  );
  port (

    ---------------------------------------------------------------------------
    -- Clock domains
    ---------------------------------------------------------------------------
    -- Rising-edge sensitive clock and active-high synchronous reset.
    clk                         : in  std_logic;
    reset                       : in  std_logic;

    ---------------------------------------------------------------------------
    -- Element input stream
    ---------------------------------------------------------------------------
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_dvalid                   : in  std_logic := '1';
    in_data                     : in  std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
    in_count                    : in  std_logic_vector(COUNT_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(COUNT_MAX, COUNT_WIDTH));
    in_last                     : in  std_logic := '0';
    in_ctrl                     : in  std_logic_vector(CTRL_WIDTH-1 downto 0) := (others => '0');

    -- By default, the prefix sums are delimited by in_last. Additional
    -- delimiters can be inserted using in_clear; asserting this signal resets
    -- the prefix sum just before the first entry.
    in_clear                    : in  std_logic := '0';

    -- Allows the reset value for the prefix sum to be overridden. Used during
    -- the first transfer of a packet and when in_clear is asserted.
    in_initial                  : in  std_logic_vector(ELEMENT_WIDTH-1 downto 0) := (others => '0');

    ---------------------------------------------------------------------------
    -- Prefix sums output stream
    ---------------------------------------------------------------------------
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_dvalid                  : out std_logic;
    out_data                    : out std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
    out_count                   : out std_logic_vector(COUNT_WIDTH-1 downto 0);
    out_last                    : out std_logic;
    out_ctrl                    : out std_logic_vector(CTRL_WIDTH-1 downto 0)

  );
end StreamPrefixSum;

architecture Behavioral of StreamPrefixSum is

  -- Internal copy of out_valid.
  signal out_valid_i            : std_logic;

  -- Register that stores whether the next transfer will be the first in the
  -- packet.
  signal first                  : std_logic;

  -- Accumulator register.
  signal accumulator            : unsigned(ELEMENT_WIDTH-1 downto 0);

begin

  reg_proc: process (clk) is
    variable out_valid_v        : std_logic;
    variable first_v            : std_logic;
    variable accumulator_v      : unsigned(ELEMENT_WIDTH-1 downto 0);
    variable mask               : std_logic_vector(COUNT_MAX-1 downto 0);
    variable hi, lo             : natural;
  begin
    if rising_edge(clk) then
      out_valid_v   := out_valid_i;
      first_v       := first;
      accumulator_v := accumulator;

      -- Invalidate output when handshaked.
      if out_ready = '1' then
        out_valid_v := '0';
      end if;

      -- Handle incoming requests when we can.
      if out_valid_v = '0' and in_valid = '1' then

        -- Handle accumulator reset.
        if first_v = '1' or in_clear = '1' then
          accumulator_v := unsigned(in_initial);
        end if;
        first_v := in_last;

        -- Compute prefix sums.
        mask := element_mask(in_count, in_dvalid, COUNT_MAX);
        for i in 0 to COUNT_MAX-1 loop

          -- Compute data vector indices for the current element.
          lo := i * ELEMENT_WIDTH;
          hi := lo + ELEMENT_WIDTH - 1;

          -- Only accumulate if the element is valid.
          if mask(i) = '1' then
            accumulator_v := accumulator_v + unsigned(in_data(hi downto lo));
          end if;

          -- Output the sum so far.
          out_data(hi downto lo) <= std_logic_vector(accumulator_v);

        end loop;

        -- Pass control signals through.
        out_valid_v := '1';
        out_dvalid  <= in_dvalid;
        out_count   <= in_count;
        out_last    <= in_last;
        out_ctrl    <= in_ctrl;

      end if;

      -- Handle reset.
      if reset = '1' then
        out_valid_v := '0';
        first_v     := '1';
      end if;

      out_valid_i <= out_valid_v;
      first       <= first_v;
      accumulator <= accumulator_v;
    end if;
  end process;

  in_ready <= (out_ready or not out_valid_i) and not reset;
  out_valid <= out_valid_i;

end Behavioral;
