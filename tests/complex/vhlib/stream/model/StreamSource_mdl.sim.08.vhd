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
use work.SimDataComms_pkg.all;
use work.StreamSource_pkg.all;
use work.StreamMonitor_pkg.all;

-- This unit models a stream source, controlled through the procedures in
-- StreamSource_pkg.

entity StreamSource_mdl is
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
    valid                       : out std_logic;
    ready                       : in  std_logic := '1';
    dvalid                      : out std_logic;
    data                        : out std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
    count                       : out std_logic_vector(COUNT_WIDTH-1 downto 0);
    last                        : out std_logic;
    ctrl                        : out std_logic_vector(CTRL_WIDTH-1 downto 0);
    x                           : out std_logic_vector(X_WIDTH-1 downto 0);
    y                           : out std_logic_vector(Y_WIDTH-1 downto 0);
    z                           : out std_logic_vector(Z_WIDTH-1 downto 0)
  );
end StreamSource_mdl;

architecture Model of StreamSource_mdl is
begin

  -- "Register" this model in the StreamSource registry.
  register_proc: process is
  begin
    assert not strsrc.exists(NAME) report "Duplicate StreamSource with name " & NAME & "." severity failure;
    strsrc.set_bool(NAME & ".exists", true);
    tc_model_registered("StreamSource", NAME);
    wait;
  end process;

  -- This process controls the stream, but all monitoring tasks are deferred to
  -- the StreamMonitor_mdl instance.
  model_proc: process (clk) is
    variable valid_v      : std_logic := '0';
    variable ready_cycles : integer := 0;
    variable xfer_cycles  : integer := 0;
    variable total_cycles : integer := 0;

    function resize_slv(i: std_logic_vector; s: natural) return std_logic_vector is
      variable res  : std_logic_vector(s-1 downto 0);
    begin
      if i'length > s then
        res := i(i'low+s-1 downto i'low);
      else
        res := (others => 'U');
        res(i'length-1 downto 0) := i;
      end if;
      return res;
    end function;

  begin
    if rising_edge(clk) then

      -- Count cycles.
      if to_X01(ready) = '1' then
        ready_cycles := ready_cycles + 1;
      end if;
      if strsrc.is_queue(NAME & ".cq") then
        xfer_cycles := xfer_cycles + 1;
      end if;
      total_cycles := total_cycles + 1;

      -- Invalidate and reset transfer state when acknowledged.
      if valid_v = '1' and to_X01(ready) = '1' then
        valid_v := '0';
        strsrc.pop(NAME & ".cq");
        ready_cycles := 0;
        xfer_cycles  := 0;
        total_cycles := 0;
      end if;

      -- See if there is something for us to send.
      if to_X01(valid_v) = '0' and strsrc.is_queue(NAME & ".cq") then
        if ready_cycles >= strsrc.get_int(NAME & ".cq.cyc.min_ready", 1) then
          if xfer_cycles >= strsrc.get_int(NAME & ".cq.cyc.min_xfer", 1) then
            if total_cycles >= strsrc.get_int(NAME & ".cq.cyc.min_total", 1) then
              dvalid  <=            strsrc.get_std(NAME & ".cq.dat.dvalid", '1');
              data    <= resize_slv(strsrc.get_slv(NAME & ".cq.dat.data",   "U"), data'length);
              count   <= resize_slv(strsrc.get_slv(NAME & ".cq.dat.count",  "U"), count'length);
              last    <=            strsrc.get_std(NAME & ".cq.dat.last",   '1');
              ctrl    <= resize_slv(strsrc.get_slv(NAME & ".cq.dat.ctrl",   "U"), ctrl'length);
              x       <= resize_slv(strsrc.get_slv(NAME & ".cq.dat.x",      "U"), x'length);
              y       <= resize_slv(strsrc.get_slv(NAME & ".cq.dat.y",      "U"), y'length);
              z       <= resize_slv(strsrc.get_slv(NAME & ".cq.dat.z",      "U"), z'length);
              valid_v := '1';
            end if;
          end if;
        end if;
      end if;

      -- Handle X situations.
      if is_X(reset) or is_X(ready) then
        valid_v := 'X';
        dvalid  <= 'X';
        data    <= (others => 'X');
        count   <= (others => 'X');
        last    <= 'X';
        ctrl    <= (others => 'X');
        x       <= (others => 'X');
        y       <= (others => 'X');
        z       <= (others => 'X');
        if to_X01(reset) /= '1' then
          tc_warn("StreamSource " & NAME & " is propagating X", " to all outputs.");
        end if;
      end if;

      -- Handle reset.
      if to_X01(reset) = '1' then
        valid_v := '0';
        dvalid  <= 'U';
        data    <= (others => 'U');
        count   <= (others => 'U');
        last    <= 'U';
        ctrl    <= (others => 'U');
        x       <= (others => 'U');
        y       <= (others => 'U');
        z       <= (others => 'U');
      end if;

      -- Reset internal state when there is a proper reset or an X on the
      -- inputs.
      if to_X01(reset) /= '0' or is_X(ready) then
        strsrc.delete(NAME & ".cq");
      end if;

      valid <= valid_v;
    end if;
  end process;

  -- Instantiate a monitor for this stream, so the testbench can see exactly
  -- how the source model and the unit under test are interacting.
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

