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
use work.StreamMonitor_pkg.all;

-- This package provides the component declaration and control functions for
-- StreamSource_mdl.

package StreamSource_pkg is

  -- Component declaration.
  component StreamSource_mdl is
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
  end component;

  -- Stream source control interface.
  type streamsource_type is protected

    -- Links this interface to a StreamSource model. This should be called
    -- before anything else.
    procedure       initialize    (nam : string := "noname");
    impure function name          return string;

    -- These procedures queue data for transmission element-wise. When there
    -- is a mismatch in element size, slv 'U'-extends, uns/str '0'-extend,
    -- and sgn/int sign-extend.
    procedure       push_slv      (dat : std_logic_vector);
    procedure       push_uns      (dat : unsigned);
    procedure       push_sgn      (dat : signed);
    procedure       push_int      (dat : integer);
    procedure       push_str      (dat : string);

    -- Sends at least one transfer, though possibly more if multiple data
    -- elements have been queued up or the range specified with set_count
    -- includes zero. If last is set, the last of these subtransfers will
    -- have the last flag in the stream asserted. Control data, elements-per-
    -- cycle, and timing information must be set prior to this call using the
    -- set_* procedures specified below if non-default behavior is desired.
    -- The default is to send data out with maximum speed and parallelism,
    -- with ctrl, x, y, and z set to 'U'.
    procedure       transmit      (last : boolean := true);

    -- These procedures set ctrl/x/y/z for the next call to transmit.
    procedure       set_ctrl      (ctrl : std_logic_vector);
    procedure       set_x         (x    : std_logic_vector);
    procedure       set_y         (y    : std_logic_vector);
    procedure       set_z         (z    : std_logic_vector);

    -- These procedures set the maximum elements-per-cycle to be transfered
    -- for a subsequent call to transmit. If low and high differ, the value
    -- is chosen with a uniform random distribution. When low and high are
    -- both less than or equal to 0, a call to transfer sends a single transfer
    -- with dvalid low without popping any data elements from the internal
    -- queue. The distribution may include negative numbers to control the
    -- probability of actually sending data; the randomized value is clamped
    -- to 0 before it is used. Initially low and high are set to COUNT_MAX.
    procedure       set_count     (val  : integer);
    procedure       set_count     (low  : integer; high : integer);

    -- These procedures set timing data for each subtransfer sent by transfer.
    -- set_ready_cyc sets the minimum cycles ready must be high during a
    -- transfer (or the distribution thereof). set_xfer_cyc similarly sets the
    -- minimum number of cycles from queueing the transfer to sending it.
    -- set_total_cyc similarly sets the minimum amount of cycles since the
    -- previous transfer or reset. If the distribution includes negative
    -- numbers, the probability for stalling essentially decreases. All ranges
    -- default to 0.
    procedure       set_ready_cyc (val : integer);
    procedure       set_ready_cyc (low : integer; high : integer);
    procedure       set_xfer_cyc  (val : integer);
    procedure       set_xfer_cyc  (low : integer; high : integer);
    procedure       set_total_cyc (val : integer);
    procedure       set_total_cyc (low : integer; high : integer);

    -- Sets the "burst length" for timing and count randomization; timing and
    -- count data is only randomized every <burst> subtransfers.
    procedure       set_burst     (val : integer);
    procedure       set_burst     (low : integer; high : integer);

    -- Sets whether the "last" flag is "greedy". By this we mean that the
    -- last transfer that actually contains data also has the "last" flag set.
    -- Contrary to AXI stream, this is not mandated by our streaming protocol;
    -- a packet can also be terminated later using a null transfer, after zero
    -- or more other null transfers. The default is to always be greedy,
    -- complying with AXI-stream. The greediness can be set as a boolean or as
    -- a probability.
    procedure       set_last_greed(greedy : boolean);
    procedure       set_last_greed(greed : real);

    ---------------------------------------------------------------------------
    -- The remaining functions map one-to-one to the underlying StreamMonitor
    ---------------------------------------------------------------------------

    -- These functions query the generics of the linked model.
    impure function g_el_width    return natural;
    impure function g_count_max   return natural;
    impure function g_count_width return natural;
    impure function g_ctrl_width  return natural;
    impure function g_x_width     return natural;
    impure function g_y_width     return natural;
    impure function g_z_width     return natural;

    -- This function queries the state of the ready signal at the most recent
    -- rising clock edge.
    impure function ready         return std_logic;

    -- These procedures operate on the packet/element queue. pq_ready returns
    -- whether a packet is ready. pq_dvalid checks whether there is at
    -- least one element remaining in the current packet. pq_get_str returns
    -- the remaining elements in the packet as characters in a string,
    -- interpreting the elements as unsigned integers and casting them to
    -- chars. The remaining pq_get functions return one element at a time,
    -- and exit with failure if no more elements are available in the packet.
    -- pq_next advances to the next packet.
    impure function pq_ready      return boolean;
    impure function pq_avail      return boolean;
    impure function pq_get_slv    return std_logic_vector;
    impure function pq_get_uns    return unsigned;
    impure function pq_get_sgn    return signed;
    impure function pq_get_int    return integer;
    impure function pq_get_nat    return natural;
    impure function pq_get_str    return string;
    procedure       pq_next       (allow_nonempty : boolean := false);

    -- These procedures operate on the control queue. cq_ready returns whether
    -- a transfer is ready. The cq_get_* functions return information from the
    -- current transfer, or exit with failure if no transfer is ready.
    -- cq_get_ecount specifically returns the number of elements valid in data,
    -- combining count and dvalid. cq_cyq_* are similar, but return timing
    -- info; cq_cyc_valid returns the number of cycles valid was high,
    -- cq_cyc_ready is the parallel for ready, and cq_cyc_total is the total
    -- number of cycles between this transfer and the previous. A reset
    -- interrupts/clears these counters. cq_x_seen returns whether an invalid
    -- handshake was detected between the current and the previous transfer.
    -- cq_unstable returns whether the valid portion of the transfer payload
    -- changed before ready acknowledged the transfer. cq_next advances to the
    -- next transfer, by default checking for the aforementioned protocol
    -- violations.
    impure function cq_ready      return boolean;
    impure function cq_get_dvalid return std_logic;
    impure function cq_get_data   return std_logic_vector;
    impure function cq_get_d_uns  return unsigned;
    impure function cq_get_d_sgn  return signed;
    impure function cq_get_d_int  return integer;
    impure function cq_get_d_nat  return natural;
    impure function cq_get_d_str  return string;
    impure function cq_get_count  return std_logic_vector;
    impure function cq_get_ecount return integer;
    impure function cq_get_last   return std_logic;
    impure function cq_get_ctrl   return std_logic_vector;
    impure function cq_get_x      return std_logic_vector;
    impure function cq_get_y      return std_logic_vector;
    impure function cq_get_z      return std_logic_vector;
    impure function cq_cyc_valid  return integer;
    impure function cq_cyc_ready  return integer;
    impure function cq_cyc_total  return integer;
    impure function cq_x_seen     return boolean;
    impure function cq_unstable   return boolean;
    procedure       cq_next       (allow_x : boolean := false; allow_unstable : boolean := false);

  end protected streamsource_type;

  -- Communication global for StreamSource instances.
  shared variable strsrc    : sc_data_type;

end package StreamSource_pkg;

package body StreamSource_pkg is

  -- Access type for std_logic_vector.
  type slv_ptr is access std_logic_vector;

  -- Stream source control interface.
  type streamsource_type is protected body

    --#########################################################################
    -- Private entries.
    --#########################################################################

    -- Name of the linked model.
    variable n              : line;

    -- Link to the enclosed StreamMonitor.
    variable mon            : streammonitor_type;

    -- Copies of generics that are used a lot.
    variable ew             : natural;
    variable cm             : natural;
    variable cw             : natural;

    -- Values controlled by the setter functions.
    variable cfg_ctrl       : slv_ptr;
    variable cfg_x          : slv_ptr;
    variable cfg_y          : slv_ptr;
    variable cfg_z          : slv_ptr;
    variable cfg_count_low  : integer;
    variable cfg_count_high : integer;
    variable cfg_ready_low  : integer;
    variable cfg_ready_high : integer;
    variable cfg_xfer_low   : integer;
    variable cfg_xfer_high  : integer;
    variable cfg_total_low  : integer;
    variable cfg_total_high : integer;
    variable cfg_burst_low  : integer;
    variable cfg_burst_high : integer;
    variable cfg_greedy_last: real;

    -- Timing data for the current "burst".
    variable cur_count      : natural;
    variable cur_ready      : natural;
    variable cur_xfer       : natural;
    variable cur_total      : natural;

    -- Number of transfers remaining in the current burst. When a transfer is
    -- started while this is zero or negative, the timing configuration is
    -- randomized.
    variable burst_remain   : integer;

    -- Random seed.
    variable seed1          : positive;
    variable seed2          : positive;

    -- Temp values for transmit that need to be dynamically allocated.
    variable data           : slv_ptr;

    -- Resizes an std_logic_vector by U-extending.
    function resize_slv(i: std_logic_vector; s: natural) return std_logic_vector is
      variable res          : std_logic_vector(s-1 downto 0);
    begin
      if i'length > s then
        res := i(i'low+s-1 downto i'low);
      else
        res := (others => 'U');
        res(i'length-1 downto 0) := i;
      end if;
      return res;
    end function;

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

    --#########################################################################
    -- Links this interface to a StreamSource model. This should be called
    -- before anything else.
    --#########################################################################
    procedure initialize(nam : string := "noname") is
    begin
      tc_check_nw(strmon.exists(nam), "Could not find StreamMonitor " & nam);
      n := new string'(nam);
      mon.initialize(nam);

      ew := mon.g_el_width;
      cm := mon.g_count_max;
      cw := mon.g_count_width;

      cfg_ctrl := new std_logic_vector(mon.g_ctrl_width - 1 downto 0);
      cfg_x    := new std_logic_vector(mon.g_x_width - 1 downto 0);
      cfg_y    := new std_logic_vector(mon.g_y_width - 1 downto 0);
      cfg_z    := new std_logic_vector(mon.g_z_width - 1 downto 0);

      cfg_count_low   := mon.g_count_max;
      cfg_count_high  := mon.g_count_max;
      cfg_ready_low   := 0;
      cfg_ready_high  := 0;
      cfg_xfer_low    := 0;
      cfg_xfer_high   := 0;
      cfg_total_low   := 0;
      cfg_total_high  := 0;
      cfg_burst_low   := 0;
      cfg_burst_high  := 0;
      cfg_greedy_last := 1.0;

      cur_count := mon.g_count_max;
      cur_ready := 0;
      cur_xfer  := 0;
      cur_total := 0;

      burst_remain := 0;

      seed1 := tc_random_seed(nam);
      seed2 := 1;

      data  := new std_logic_vector(ew * cm - 1 downto 0);

    end procedure;

    impure function name return string is
    begin
      return n.all;
    end function;


    --#########################################################################
    -- These procedures queue data for transmission element-wise. When there
    -- is a mismatch in element size, slv 'U'-extends, uns/str '0'-extend,
    -- and sgn/int sign-extend.
    --#########################################################################
    procedure push_slv(dat : std_logic_vector) is
    begin
      strsrc.set_slv(n.all & ".eq", resize_slv(dat, ew));
      strsrc.push(n.all & ".eq");
    end procedure;

    procedure push_uns(dat : unsigned) is
    begin
      strsrc.set_slv(n.all & ".eq", std_logic_vector(resize(dat, ew)));
      strsrc.push(n.all & ".eq");
    end procedure;

    procedure push_sgn(dat : signed) is
    begin
      strsrc.set_slv(n.all & ".eq", std_logic_vector(resize(dat, ew)));
      strsrc.push(n.all & ".eq");
    end procedure;

    procedure push_int(dat : integer) is
    begin
      strsrc.set_slv(n.all & ".eq", std_logic_vector(to_unsigned(dat, ew)));
      strsrc.push(n.all & ".eq");
    end procedure;

    procedure push_str(dat : string) is
    begin
      for i in dat'range loop
        push_int(character'pos(dat(i)));
      end loop;
    end procedure;


    --#########################################################################
    -- Sends at least one transfer, though possibly more if multiple data
    -- elements have been queued up or the range specified with set_count
    -- includes zero. If last is set, the last of these subtransfers will
    -- have the last flag in the stream asserted. Control data, elements-per-
    -- cycle, and timing information must be set prior to this call using the
    -- set_* procedures specified below if non-default behavior is desired.
    -- The default is to send data out with maximum speed and parallelism,
    -- with ctrl, x, y, and z set to 'U'.
    --#########################################################################
    procedure transmit(last : boolean := true) is
      variable done   : boolean;
      variable send   : boolean;
      variable ecount : natural;
      variable randf  : real;
    begin
      done := false;
      while not done loop

        -- Initialize parallelization.
        data.all := (data.all'range => 'U');
        ecount := 0;

        -- Timing randomization.
        if burst_remain <= 0 then
          cur_count    := rand_nat(cfg_count_low, cfg_count_high);
          cur_ready    := rand_nat(cfg_ready_low, cfg_ready_high);
          cur_xfer     := rand_nat(cfg_xfer_low,  cfg_xfer_high);
          cur_total    := rand_nat(cfg_total_low, cfg_total_high);
          burst_remain := rand_nat(cfg_burst_low, cfg_burst_high);
          if burst_remain < 1 then
            burst_remain := 1;
          end if;
        end if;

        -- This flag indicates whether we've done all we need to do to send out
        -- the next transfer.
        send := false;
        while not send loop

          -- If we have enough elements queued up, we should send.
          if ecount >= cur_count or ecount >= cm then
            send := true;

            -- If we exit the parallelization loop here, the "last" flag is
            -- postponed to a null transfer if we have exactly the right
            -- amount of elements queued up. If we don't, the "last" flag is
            -- added greedily.
            uniform(seed1, seed2, randf);
            exit when randf > cfg_greedy_last;

          end if;

          -- If there's no more data to pull in, send the last transfer.
          if not strsrc.is_queue(n.all & ".eq") then
            send := true;
            done := true;
          end if;

          -- If we're still not ready to send, pull in more data (send being
          -- false implies elements are pending).
          if not send then
            data.all((ecount+1)*ew-1 downto ecount*ew) := resize_slv(strsrc.get_slv(n.all & ".eq"), ew);
            strsrc.pop(n.all & ".eq");
            ecount := ecount + 1;
          end if;

        end loop;

        -- If there is no chance of sending any elements, send only one
        -- transfer to prevent an infinite loop.
        if cfg_count_low <= 0 and cfg_count_high <= 0 then
          done := true;
        end if;

        -- Queue up the next transfer.
        strsrc.set_slv(n.all & ".cq.dat.data", data.all);
        if ecount = 0 then
          strsrc.set_std(n.all & ".cq.dat.dvalid", '0');
          strsrc.set_slv(n.all & ".cq.dat.count", (cw-1 downto 0 => 'U'));
        else
          strsrc.set_std(n.all & ".cq.dat.dvalid", '1');
          strsrc.set_slv(n.all & ".cq.dat.count", std_logic_vector(to_unsigned(ecount, cw)));
        end if;
        if done and last then
          strsrc.set_std(n.all & ".cq.dat.last", '1');
        else
          strsrc.set_std(n.all & ".cq.dat.last", '0');
        end if;
        strsrc.set_slv(n.all & ".cq.dat.ctrl", cfg_ctrl.all);
        strsrc.set_slv(n.all & ".cq.dat.x", cfg_x.all);
        strsrc.set_slv(n.all & ".cq.dat.y", cfg_y.all);
        strsrc.set_slv(n.all & ".cq.dat.z", cfg_z.all);
        strsrc.set_int(n.all & ".cq.cyc.min_ready", cur_ready);
        strsrc.set_int(n.all & ".cq.cyc.min_xfer", cur_xfer);
        strsrc.set_int(n.all & ".cq.cyc.min_total", cur_total);
        strsrc.push(n.all & ".cq");
        burst_remain := burst_remain - 1;

      end loop;
    end procedure;


    --#########################################################################
    -- These procedures set ctrl/x/y/z for the next call to transmit.
    --#########################################################################
    procedure set_ctrl(ctrl : std_logic_vector) is
    begin
      cfg_ctrl.all := resize_slv(ctrl, cfg_ctrl.all'length);
    end procedure;

    procedure set_x(x : std_logic_vector) is
    begin
      cfg_x.all := resize_slv(x, cfg_x.all'length);
    end procedure;

    procedure set_y(y : std_logic_vector) is
    begin
      cfg_y.all := resize_slv(y, cfg_y.all'length);
    end procedure;

    procedure set_z(z : std_logic_vector) is
    begin
      cfg_z.all := resize_slv(z, cfg_z.all'length);
    end procedure;


    --#########################################################################
    -- These procedures set the maximum elements-per-cycle to be transfered
    -- for a subsequent call to transmit. If low and high differ, the value
    -- is chosen with a uniform random distribution. When low and high are
    -- both 0, a call to transfer sends a single transfer with dvalid low
    -- without popping any data elements from the internal queue. Initially
    -- low and high are set to COUNT_MAX.
    --#########################################################################
    procedure set_count(val : integer) is
    begin
      set_count(val, val);
    end procedure;

    procedure set_count(low : integer; high : integer) is
    begin
      cfg_count_low := low;
      cfg_count_high := high;
      burst_remain := 0; -- Ensure re-randomization
    end procedure;


    --#########################################################################
    -- These procedures set timing data for each subtransfer sent by transfer.
    -- set_ready_cyc sets the minimum cycles ready must be high during a
    -- transfer (or the distribution thereof). set_xfer_cyc similarly sets the
    -- minimum number of cycles from queueing the transfer to sending it.
    -- set_total_cyc similarly sets the minimum amount of cycles since the
    -- previous transfer or reset. All ranges default to 0.
    --#########################################################################
    procedure set_ready_cyc(val : integer) is
    begin
      set_ready_cyc(val, val);
    end procedure;

    procedure set_ready_cyc(low : integer; high : integer) is
    begin
      cfg_ready_low := low;
      cfg_ready_high := high;
      burst_remain := 0; -- Ensure re-randomization
    end procedure;

    procedure set_xfer_cyc(val : integer) is
    begin
      set_xfer_cyc(val, val);
    end procedure;

    procedure set_xfer_cyc(low : integer; high : integer) is
    begin
      cfg_xfer_low := low;
      cfg_xfer_high := high;
      burst_remain := 0; -- Ensure re-randomization
    end procedure;

    procedure set_total_cyc(val : integer) is
    begin
      set_total_cyc(val, val);
    end procedure;

    procedure set_total_cyc(low : integer; high : integer) is
    begin
      cfg_total_low := low;
      cfg_total_high := high;
      burst_remain := 0; -- Ensure re-randomization
    end procedure;


    --#########################################################################
    -- Sets the "burst length" for timing and count randomization; timing and
    -- count data is only randomized every <burst> subtransfers.
    --#########################################################################
    procedure set_burst(val : integer) is
    begin
      set_burst(val, val);
    end procedure;

    procedure set_burst(low : integer; high : integer) is
    begin
      cfg_burst_low := low;
      cfg_burst_high := high;
      burst_remain := 0; -- Ensure re-randomization
    end procedure;


    --#########################################################################
    -- Sets whether the "last" flag is "greedy". By this we mean that the
    -- last transfer that actually contains data also has the "last" flag set.
    -- Contrary to AXI stream, this is not mandated by our streaming protocol;
    -- a packet can also be terminated later using a null transfer, after zero
    -- or more other null transfers. The default is to always be greedy,
    -- complying with AXI-stream. The greediness can be set as a boolean or as
    -- a probability.
    procedure set_last_greed(greedy : boolean) is
    begin
      if greedy then
        set_last_greed(1.0);
      else
        set_last_greed(0.0);
      end if;
    end procedure;

    procedure set_last_greed(greed : real) is
    begin
      cfg_greedy_last := greed;
      burst_remain := 0; -- Ensure re-randomization
    end procedure;


    --#########################################################################
    -- These functions query the generics of the linked model.
    --#########################################################################
    impure function g_el_width return natural is
    begin
      return ew;
    end function;

    impure function g_count_max return natural is
    begin
      return cm;
    end function;

    impure function g_count_width return natural is
    begin
      return cw;
    end function;

    impure function g_ctrl_width return natural is
    begin
      return cfg_ctrl.all'length;
    end function;

    impure function g_x_width return natural is
    begin
      return cfg_x.all'length;
    end function;

    impure function g_y_width return natural is
    begin
      return cfg_y.all'length;
    end function;

    impure function g_z_width return natural is
    begin
      return cfg_z.all'length;
    end function;


    --#########################################################################
    -- This function queries the state of the ready signal at the most recent
    -- rising clock edge.
    --#########################################################################
    impure function ready return std_logic is
    begin
      return mon.ready;
    end function;


    --#########################################################################
    -- These procedures operate on the packet/element queue. pq_ready returns
    -- whether a packet is ready. pq_dvalid checks whether there is at
    -- least one element remaining in the current packet. pq_get_str returns
    -- the remaining elements in the packet as characters in a string,
    -- interpreting the elements as unsigned integers and casting them to
    -- chars. The remaining pq_get functions return one element at a time,
    -- and exit with failure if no more elements are available in the packet.
    -- pq_next advances to the next packet.
    --#########################################################################
    impure function pq_ready return boolean is
    begin
      return mon.pq_ready;
    end function;

    impure function pq_avail return boolean is
    begin
      return mon.pq_avail;
    end function;

    impure function pq_get_slv return std_logic_vector is
    begin
      return mon.pq_get_slv;
    end function;

    impure function pq_get_uns return unsigned is
    begin
      return mon.pq_get_uns;
    end function;

    impure function pq_get_sgn return signed is
    begin
      return mon.pq_get_sgn;
    end function;

    impure function pq_get_int return integer is
    begin
      return mon.pq_get_int;
    end function;

    impure function pq_get_nat return natural is
    begin
      return mon.pq_get_nat;
    end function;

    impure function pq_get_str return string is
    begin
      return mon.pq_get_str;
    end function;

    procedure pq_next(allow_nonempty : boolean := false) is
    begin
      mon.pq_next(allow_nonempty);
    end procedure;


    --#########################################################################
    -- These procedures operate on the control queue. cq_ready returns whether
    -- a transfer is ready. The cq_get_* functions return information from the
    -- current transfer, or exit with failure if no transfer is ready.
    -- cq_get_ecount specifically returns the number of elements valid in data,
    -- combining count and dvalid. cq_cyq_* are similar, but return timing
    -- info; cq_cyc_valid returns the number of cycles valid was high,
    -- cq_cyc_ready is the parallel for ready, and cq_cyc_total is the total
    -- number of cycles between this transfer and the previous. A reset
    -- interrupts/clears these counters. cq_x_seen returns whether an invalid
    -- handshake was detected between the current and the previous transfer.
    -- cq_unstable returns whether the valid portion of the transfer payload
    -- changed before ready acknowledged the transfer. cq_next advances to the
    -- next transfer, by default checking for the aforementioned protocol
    -- violations.
    --#########################################################################
    impure function cq_ready return boolean is
    begin
      return mon.cq_ready;
    end function;

    impure function cq_get_dvalid return std_logic is
    begin
      return mon.cq_get_dvalid;
    end function;

    impure function cq_get_data return std_logic_vector is
    begin
      return mon.cq_get_data;
    end function;

    impure function cq_get_d_uns return unsigned is
    begin
      return mon.cq_get_d_uns;
    end function;

    impure function cq_get_d_sgn return signed is
    begin
      return mon.cq_get_d_sgn;
    end function;

    impure function cq_get_d_int return integer is
    begin
      return mon.cq_get_d_int;
    end function;

    impure function cq_get_d_nat return natural is
    begin
      return mon.cq_get_d_nat;
    end function;

    impure function cq_get_d_str return string is
    begin
      return mon.cq_get_d_str;
    end function;

    impure function cq_get_count return std_logic_vector is
    begin
      return mon.cq_get_count;
    end function;

    impure function cq_get_ecount return integer is
    begin
      return mon.cq_get_ecount;
    end function;

    impure function cq_get_last return std_logic is
    begin
      return mon.cq_get_last;
    end function;

    impure function cq_get_ctrl return std_logic_vector is
    begin
      return mon.cq_get_ctrl;
    end function;

    impure function cq_get_x return std_logic_vector is
    begin
      return mon.cq_get_x;
    end function;

    impure function cq_get_y return std_logic_vector is
    begin
      return mon.cq_get_y;
    end function;

    impure function cq_get_z return std_logic_vector is
    begin
      return mon.cq_get_z;
    end function;

    impure function cq_cyc_valid return integer is
    begin
      return mon.cq_cyc_valid;
    end function;

    impure function cq_cyc_ready return integer is
    begin
      return mon.cq_cyc_ready;
    end function;

    impure function cq_cyc_total return integer is
    begin
      return mon.cq_cyc_total;
    end function;

    impure function cq_x_seen return boolean is
    begin
      return mon.cq_x_seen;
    end function;

    impure function cq_unstable return boolean is
    begin
      return mon.cq_unstable;
    end function;

    procedure cq_next(allow_x : boolean := false; allow_unstable : boolean := false) is
    begin
      mon.cq_next(allow_x, allow_unstable);
    end procedure;

  end protected body streamsource_type;

end package body StreamSource_pkg;
