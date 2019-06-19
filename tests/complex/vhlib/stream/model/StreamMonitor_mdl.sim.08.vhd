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
use work.StreamMonitor_pkg.all;

-- This unit monitors a stream, in such a way that transfers can be monitored
-- through the procedures in StreamMonitor_pkg.

entity StreamMonitor_mdl is
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
    ready                       : in  std_logic := '1';
    dvalid                      : in  std_logic := '1';
    data                        : in  std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0) := (others => '0');
    count                       : in  std_logic_vector(COUNT_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(COUNT_MAX, COUNT_WIDTH));
    last                        : in  std_logic := '1';
    ctrl                        : in  std_logic_vector(CTRL_WIDTH-1 downto 0) := (others => '0');
    x                           : in  std_logic_vector(X_WIDTH-1 downto 0) := (others => '0');
    y                           : in  std_logic_vector(Y_WIDTH-1 downto 0) := (others => '0');
    z                           : in  std_logic_vector(Z_WIDTH-1 downto 0) := (others => '0')
  );
end StreamMonitor_mdl;

architecture Model of StreamMonitor_mdl is
begin

  -- "Register" this model in the StreamMonitor registry by populating the
  -- generics.
  register_proc: process is
  begin
    assert not strmon.exists(NAME) report "Duplicate StreamMonitor with name " & NAME & "." severity failure;
    strmon.set_int(NAME & ".g.el_width",      ELEMENT_WIDTH);
    strmon.set_int(NAME & ".g.count_max",     COUNT_MAX);
    strmon.set_int(NAME & ".g.count_width",   COUNT_WIDTH);
    strmon.set_int(NAME & ".g.ctrl_width",    CTRL_WIDTH);
    strmon.set_int(NAME & ".g.x_width",       X_WIDTH);
    strmon.set_int(NAME & ".g.y_width",       Y_WIDTH);
    strmon.set_int(NAME & ".g.z_width",       Z_WIDTH);
    tc_model_registered("StreamMonitor", NAME);
    wait;
  end process;

  -- This process controls the stream, but all monitoring tasks are deferred to
  -- the StreamMonitor_mdl instance.
  model_proc: process (clk) is
    variable x_seen       : boolean := false;
    variable unstable     : boolean := false;
    variable saved_valid  : boolean := false;
    variable saved_dvalid : std_logic;
    variable saved_data   : std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
    variable saved_count  : std_logic_vector(COUNT_WIDTH-1 downto 0);
    variable saved_last   : std_logic;
    variable saved_ctrl   : std_logic_vector(CTRL_WIDTH-1 downto 0);
    variable saved_x      : std_logic_vector(X_WIDTH-1 downto 0);
    variable saved_y      : std_logic_vector(Y_WIDTH-1 downto 0);
    variable saved_z      : std_logic_vector(Z_WIDTH-1 downto 0);
    variable valid_cycles : integer := 0;
    variable ready_cycles : integer := 0;
    variable total_cycles : integer := 0;
    variable count_v      : natural;
  begin
    if rising_edge(clk) then

      -- Save the state of the handshake signals so they can be monitored from
      -- the testbench directly.
      strmon.set_std(NAME & ".valid", valid);
      strmon.set_std(NAME & ".ready", ready);

      -- Count cycles.
      if valid = '1' then
        valid_cycles := valid_cycles + 1;
      end if;
      if ready = '1' then
        ready_cycles := ready_cycles + 1;
      end if;
      total_cycles := total_cycles + 1;

      -- Assert that validated data does not change and that count is within
      -- the supported range.
      if to_X01(valid) then
        if saved_valid then
          if saved_dvalid /= dvalid then
            tc_warn("StreamMonitor " & NAME & " unstable", " dvalid.");
            unstable := true;
          end if;
          if to_X01(dvalid) /= '0' then
            if saved_count /= count then
              tc_warn("StreamMonitor " & NAME & " unstable", " count.");
              unstable := true;
            end if;
            if not is_X(count) then
              count_v := to_integer(unsigned(count));
              if count_v = 0 and (COUNT_MAX = 2**COUNT_WIDTH) then
                count_v := COUNT_MAX;
              end if;
              if count_v < 1 or count_v > COUNT_MAX then
                tc_warn("StreamMonitor " & NAME & " count is out of range.");
                count_v := 0;
              end if;
              if count_v > 0 then
                if saved_data(count_v * ELEMENT_WIDTH - 1 downto 0) /= data(count_v * ELEMENT_WIDTH - 1 downto 0) then
                  tc_warn("StreamMonitor " & NAME & " unstable", " data.");
                  unstable := true;
                end if;
              end if;
            end if;
          end if;
          if saved_last /= last then
            tc_warn("StreamMonitor " & NAME & " unstable", " last.");
            unstable := true;
          end if;
          if saved_ctrl /= ctrl then
            tc_warn("StreamMonitor " & NAME & " unstable", " ctrl.");
            unstable := true;
          end if;
          if saved_x /= x then
            tc_warn("StreamMonitor " & NAME & " unstable", " x.");
            unstable := true;
          end if;
          if saved_y /= y then
            tc_warn("StreamMonitor " & NAME & " unstable", " y.");
            unstable := true;
          end if;
          if saved_z /= z then
            tc_warn("StreamMonitor " & NAME & " unstable", " z.");
            unstable := true;
          end if;
        end if;
        saved_dvalid := dvalid;
        saved_data   := data;
        saved_count  := count;
        saved_last   := last;
        saved_ctrl   := ctrl;
        saved_x      := x;
        saved_y      := y;
        saved_z      := z;
      end if;

      -- Invalidate and reset transfer state when acknowledged.
      if to_X01(valid) = '1' and to_X01(ready) = '1' then

        -- Push all the transfer data we have into the control queue.
        strmon.set_std (NAME & ".cq.dat.dvalid", dvalid);
        strmon.set_slv (NAME & ".cq.dat.data",   data);
        strmon.set_slv (NAME & ".cq.dat.count",  count);
        strmon.set_std (NAME & ".cq.dat.last",   last);
        strmon.set_slv (NAME & ".cq.dat.ctrl",   ctrl);
        strmon.set_slv (NAME & ".cq.dat.x",      x);
        strmon.set_slv (NAME & ".cq.dat.y",      y);
        strmon.set_slv (NAME & ".cq.dat.z",      z);
        strmon.set_int (NAME & ".cq.cyc.valid",  valid_cycles);
        strmon.set_int (NAME & ".cq.cyc.ready",  ready_cycles);
        strmon.set_int (NAME & ".cq.cyc.total",  total_cycles);
        strmon.set_bool(NAME & ".cq.x_seen",     x_seen);
        strmon.set_bool(NAME & ".cq.unstable",   unstable);
        strmon.push(NAME & ".cq");

        -- Also make a packet queue available. A packet consists itself of a
        -- queue of elements.
        if to_X01(dvalid) = '1' and not is_X(count) then
          count_v := to_integer(unsigned(count));
          if count_v = 0 and (COUNT_MAX = 2**COUNT_WIDTH) then
            count_v := COUNT_MAX;
          end if;
          if count_v < 1 or count_v > COUNT_MAX then
            count_v := 0;
          end if;
          for i in 0 to count_v - 1 loop
            strmon.set_slv(NAME & ".pq.dq", data((i+1)*ELEMENT_WIDTH-1 downto i*ELEMENT_WIDTH));
            strmon.push(NAME & ".pq.dq");
          end loop;
        end if;
        if to_X01(last) = '1' then
          strmon.push(NAME & ".pq");
        end if;

        -- Reset transfer state.
        x_seen := false;
        valid_cycles := 0;
        ready_cycles := 0;
        total_cycles := 0;
        saved_valid := false;
        unstable := false;

      end if;

      -- Handle X situations.
      if is_X(reset) or is_X(valid) or (to_X01(valid) = '1' and is_X(ready)) then
        x_seen := true;
        if to_X01(reset) = '0' then
          tc_warn("StreamMonitor " & NAME & " observed an undefined handshake.");
        end if;
      end if;

      -- Handle reset.
      if to_X01(reset) = '1' then
        strmon.delete(NAME & ".pq");
        strmon.delete(NAME & ".cq");
        x_seen := false;
        valid_cycles := 0;
        ready_cycles := 0;
        total_cycles := 0;
        unstable := false;
      end if;

    end if;
  end process;

end Model;

