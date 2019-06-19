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
use work.StreamSink_pkg.all;
use work.StreamMonitor_pkg.all;

-- This unit models a stream sink, controlled through the procedures in
-- StreamSink_pkg.

entity StreamSink_mdl is
  generic (
    NAME                        : string := "noname";
    ELEMENT_WIDTH               : natural := 8;
    COUNT_MAX                   : natural := 1;
    COUNT_WIDTH                 : natural := 1;
    CTRL_WIDTH                  : natural := 1;
    X_WIDTH                     : natural := 1;
    Y_WIDTH                     : natural := 1;
    Z_WIDTH                     : natural := 1
  );
  port (
    clk                         : in  std_logic;
    reset                       : in  std_logic := '0';
    valid                       : in  std_logic := '1';
    ready                       : out std_logic;
    dvalid                      : in  std_logic := '1';
    data                        : in  std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0) := (others => '0');
    count                       : in  std_logic_vector(COUNT_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(COUNT_MAX, COUNT_WIDTH));
    last                        : in  std_logic := '1';
    ctrl                        : in  std_logic_vector(CTRL_WIDTH-1 downto 0) := (others => '0');
    x                           : in  std_logic_vector(X_WIDTH-1 downto 0) := (others => '0');
    y                           : in  std_logic_vector(Y_WIDTH-1 downto 0) := (others => '0');
    z                           : in  std_logic_vector(Z_WIDTH-1 downto 0) := (others => '0')
  );
end StreamSink_mdl;

architecture Model of StreamSink_mdl is
begin

  -- "Register" this model in the StreamSink registry.
  register_proc: process is
  begin
    assert not strsink.exists(NAME) report "Duplicate StreamSink with name " & NAME & "." severity failure;
    strsink.set_bool(NAME & ".exists", true);
    tc_model_registered("StreamSink", NAME);
    wait;
  end process;

  -- This process controls the stream, but all monitoring tasks are deferred to
  -- the StreamMonitor_mdl instance.
  model_proc: process (clk) is
    variable ready_v          : std_logic := '0';

    -- Pending transfer information. When pending is set and the *_cycles
    -- counters have all reached min_*_cycles, ready is asserted. pending is
    -- cleared when the transfer is acknowledged.
    variable pending          : boolean := false;
    variable min_valid_cycles : integer := 0;
    variable min_total_cycles : integer := 0;

    -- Cycle counters used to determine when to assert ready.
    variable valid_cycles     : integer := 0;
    variable total_cycles     : integer := 0;

    -- Sequence number of the current unblock request or -1 if no request is
    -- currently available, and the number of data associated with it (so we
    -- don't have to query it every cycle).
    variable cur_sequence     : integer := -1;
    variable num_xfer         : integer := 0;
    variable num_el           : integer := 0;
    variable num_pkt          : integer := 0;
    variable min_valid_low    : integer := 0;
    variable min_valid_high   : integer := 0;
    variable min_total_low    : integer := 0;
    variable min_total_high   : integer := 0;
    variable burst_low        : integer := 0;
    variable burst_high       : integer := 0;

    -- Transfer counters used to determine when to advance to the next unblock
    -- request.
    variable xfer_count       : integer := 0;
    variable el_count         : integer := 0;
    variable pkt_count        : integer := 0;

    -- Burst counter used to determine when to re-randomize the min_*_cycles
    -- values.
    variable burst_remain     : integer := 0;

    -- Temporary variables.
    variable i                : integer := 0;

    -- Random seed.
    variable seed1            : positive := tc_random_seed(NAME);
    variable seed2            : positive := 1;

    -- Gets a random natural number from the given low/high values.
    impure function rand_nat(lo: integer; hi: integer) return natural is
      variable randf  : real;
      variable randi  : integer;
    begin
      uniform(seed1, seed2, randf);
      randf := randf * real(hi - lo + 1);
      randi := integer(floor(randf)) + lo;
      if randi > 0 then
        return randi;
      end if;
      return 0;
    end function;

  begin
    if rising_edge(clk) then

      -- Count cycles.
      if to_X01(valid) = '1' then
        valid_cycles := valid_cycles + 1;
      end if;
      total_cycles := total_cycles + 1;

      -- Release handshake and deactivate ourselves after every transfer.
      if ready_v = '1' and to_X01(valid) = '1' then
        ready_v := '0';
        pending := false;

        -- Update the transfer counters.
        xfer_count := xfer_count + 1;
        if to_X01(dvalid) = '1' then
          i := 0;
          if COUNT_WIDTH >= 1 then
            i := to_integer(unsigned(count));
          end if;
          if i = 0 then
            i := 2**COUNT_WIDTH;
          end if;
          el_count := el_count + i;
        end if;
        if to_X01(last) = '1' then
          pkt_count := pkt_count + 1;
        end if;

        -- Update the burst counter.
        burst_remain := burst_remain - 1;

        -- See if we've completed the current command.
        if (
          (num_xfer > 0 and xfer_count >= num_xfer) or
          (num_el   > 0 and el_count   >= num_el) or
          (num_pkt  > 0 and pkt_count  >= num_pkt)
        ) then
          if strsink.is_queue(NAME & ".uq") then
            if strsink.get_int(NAME & ".uq.sequence") = cur_sequence then
              strsink.pop(NAME & ".uq");
            end if;
          end if;
          cur_sequence := -1;
        end if;

      end if;

      -- If we're handling a command right now, make sure that it hasn't been
      -- removed through reblock.
      if cur_sequence /= -1 then
        if not strsink.is_queue(NAME & ".uq") then
          cur_sequence := -1;
          pending := false;
        elsif strsink.get_int(NAME & ".uq.sequence") /= cur_sequence then
          cur_sequence := -1;
          pending := false;
        end if;
      end if;

      -- If we're not handling a command right now (implies not pending), see
      -- if a new one is waiting.
      if cur_sequence = -1 then
        assert not pending;
        if strsink.is_queue(NAME & ".uq") then
          cur_sequence    := strsink.get_int(NAME & ".uq.sequence");
          num_xfer        := strsink.get_int(NAME & ".uq.num_xfer");
          num_el          := strsink.get_int(NAME & ".uq.num_el");
          num_pkt         := strsink.get_int(NAME & ".uq.num_pkt");
          min_valid_low   := strsink.get_int(NAME & ".uq.min_valid_low");
          min_valid_high  := strsink.get_int(NAME & ".uq.min_valid_high");
          min_total_low   := strsink.get_int(NAME & ".uq.min_total_low");
          min_total_high  := strsink.get_int(NAME & ".uq.min_total_high");
          burst_low       := strsink.get_int(NAME & ".uq.burst_low");
          burst_high      := strsink.get_int(NAME & ".uq.burst_high");
          burst_remain    := 0;
          xfer_count      := 0;
          el_count        := 0;
          pkt_count       := 0;
        end if;
      end if;

      -- If we're handling a command but nothing is pending right now, we need
      -- to pend the next transfer.
      if cur_sequence /= -1 and not pending then

        -- Randomize the timing configuration when our burst runs out or we
        -- just started a new command.
        if burst_remain <= 0 then
          burst_remain      := rand_nat(burst_low,      burst_high);
          min_valid_cycles  := rand_nat(min_valid_low,  min_valid_high);
          min_total_cycles  := rand_nat(min_total_low,  min_total_high);
        end if;

        -- Set the pending flag to start the next transfer.
        pending       := true;
        valid_cycles  := 0;
        total_cycles  := 0;

      end if;

      -- If a transfer is pending and the cycle counters fulfill the
      -- requirements, assert ready.
      if pending then
        if valid_cycles >= min_valid_cycles then
          if total_cycles >= min_total_cycles then
            ready_v := '1';
          end if;
        end if;
      end if;

      -- Handle X situations.
      if is_X(reset) or is_X(ready) then
        ready_v := 'X';
        if to_X01(reset) /= '1' then
          tc_warn("StreamSink " & NAME & " is propagating X", " to handshake output.");
        end if;
      end if;

      -- Handle reset.
      if to_X01(reset) = '1' then
        ready_v := '0';
      end if;

      -- Reset internal state when there is a proper reset or an X on the
      -- inputs.
      if to_X01(reset) /= '0' or is_X(ready) then
        strsink.delete(NAME & ".uq");
        pending := false;
      end if;

      ready <= ready_v;
    end if;
  end process;

  -- Instantiate a monitor for this stream, so the testbench can see exactly
  -- how the sink model and the unit under test are interacting.
  monitor: StreamMonitor_mdl
    generic map (
      NAME                      => NAME,
      ELEMENT_WIDTH             => ELEMENT_WIDTH,
      COUNT_MAX                 => COUNT_MAX,
      COUNT_WIDTH               => COUNT_WIDTH,
      CTRL_WIDTH                => CTRL_WIDTH,
      X_WIDTH                   => X_WIDTH,
      Y_WIDTH                   => Y_WIDTH,
      Z_WIDTH                   => Z_WIDTH
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      valid                     => valid,
      ready                     => ready,
      dvalid                    => dvalid,
      data                      => data,
      count                     => count,
      last                      => last,
      ctrl                      => ctrl,
      x                         => x,
      y                         => y,
      z                         => z
    );

end Model;

