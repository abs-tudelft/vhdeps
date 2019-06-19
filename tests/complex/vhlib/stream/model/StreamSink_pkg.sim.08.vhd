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

library std;
use std.textio.all;

library work;
use work.TestCase_pkg.all;
use work.SimDataComms_pkg.all;
use work.StreamMonitor_pkg.all;

-- This package provides the component declaration and control functions for
-- StreamSink_mdl.

package StreamSink_pkg is

  -- Component declaration.
  component StreamSink_mdl is
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
  end component;

  -- Stream sink control interface.
  type streamsink_type is protected

    -- Links this interface to a StreamSink model. This should be called
    -- before anything else.
    procedure       initialize    (nam : string := "noname");
    impure function name          return string;

    -- Unblocks the sink, such that it can start receiving data. The amount of
    -- data before the next block can be limited by number of transfers
    -- (num_xfer), number of elements (num_el), and/or number of last-delimited
    -- packets (num_pkt); the first limit reached will block again. Zero is
    -- used to indicate unlimited, which is the default for each. Unblock calls
    -- are queued, so subsequent calls don't override each other. The unblock
    -- queue includes the timing data set by set_*_cyc() and set_burst().
    procedure       unblock       (num_xfer : integer := 0; num_el : integer := 0; num_pkt : integer := 0);

    -- Flushes the unblock queue to immediately block the unit again.
    procedure       reblock;

    -- Returns whether the unit is currently blocked.
    impure function is_blocked    return boolean;

    -- These procedures set timing data for the ready handshake signal.
    -- set_valid_cyc sets the minimum cycles valid must be high during a
    -- transfer (or the distribution thereof). set_total_cyc similarly sets the
    -- minimum amount of cycles since the previous transfer or reset. If the
    -- distribution includes negative numbers, the probability for stalling
    -- essentially decreases. All ranges default to 0.
    procedure       set_valid_cyc (val : integer);
    procedure       set_valid_cyc (low : integer; high : integer);
    procedure       set_total_cyc (val : integer);
    procedure       set_total_cyc (low : integer; high : integer);

    -- Sets the "burst length" for timing and count randomization; timing and
    -- count data is only randomized every <burst> subtransfers.
    procedure       set_burst     (val : integer);
    procedure       set_burst     (low : integer; high : integer);

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

  end protected streamsink_type;

  -- Communication global for StreamSink instances.
  shared variable strsink    : sc_data_type;

end package StreamSink_pkg;

package body StreamSink_pkg is

  -- Access type for std_logic_vector.
  type slv_ptr is access std_logic_vector;

  -- Stream sink control interface.
  type streamsink_type is protected body

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
    variable cfg_valid_low  : integer;
    variable cfg_valid_high : integer;
    variable cfg_total_low  : integer;
    variable cfg_total_high : integer;
    variable cfg_burst_low  : integer;
    variable cfg_burst_high : integer;

    -- Sequence number for the unblock queue messages. This is used by the
    -- model to detect when the unblock queue is cleared (since a new unblock
    -- request may be queued immediately after).
    variable cur_sequence   : integer;

    --#########################################################################
    -- Links this interface to a StreamSink model. This should be called
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

      cfg_valid_low   := 0;
      cfg_valid_high  := 0;
      cfg_total_low   := 0;
      cfg_total_high  := 0;
      cfg_burst_low   := 0;
      cfg_burst_high  := 0;

      cur_sequence    := 0;
    end procedure;

    impure function name return string is
    begin
      return n.all;
    end function;


    --#########################################################################
    -- Unblocks the sink, such that it can start receiving data. The amount of
    -- data before the next block can be limited by number of transfers
    -- (num_xfer), number of elements (num_el), and/or number of last-delimited
    -- packets (num_pkt); the first limit reached will block again. Zero is
    -- used to indicate unlimited, which is the default for each. Unblock calls
    -- are queued, so subsequent calls don't override each other. The unblock
    -- queue includes the timing data set by set_*_cyc() and set_burst().
    --#########################################################################
    procedure unblock (
      num_xfer  : integer := 0;
      num_el    : integer := 0;
      num_pkt   : integer := 0
    ) is
    begin
      strsink.set_int(n.all & ".uq.sequence",       cur_sequence);
      strsink.set_int(n.all & ".uq.num_xfer",       num_xfer);
      strsink.set_int(n.all & ".uq.num_el",         num_el);
      strsink.set_int(n.all & ".uq.num_pkt",        num_pkt);
      strsink.set_int(n.all & ".uq.min_valid_low",  cfg_valid_low);
      strsink.set_int(n.all & ".uq.min_valid_high", cfg_valid_high);
      strsink.set_int(n.all & ".uq.min_total_low",  cfg_total_low);
      strsink.set_int(n.all & ".uq.min_total_high", cfg_total_high);
      strsink.set_int(n.all & ".uq.burst_low",      cfg_burst_low);
      strsink.set_int(n.all & ".uq.burst_high",     cfg_burst_high);
      strsink.push(n.all & ".uq");
      cur_sequence := cur_sequence + 1;
    end procedure;

    -- Flushes the unblock queue to immediately block the unit again.
    procedure reblock is
    begin
      strsink.delete(n.all & ".uq");
    end procedure;

    -- Returns whether the unit is currently blocked.
    impure function is_blocked return boolean is
    begin
      return not strsink.is_queue(n.all & ".uq");
    end function;


    --#########################################################################
    -- These procedures set timing data for the ready handshake signal.
    -- set_valid_cyc sets the minimum cycles valid must be high during a
    -- transfer (or the distribution thereof). set_total_cyc similarly sets the
    -- minimum amount of cycles since the previous transfer or reset. If the
    -- distribution includes negative numbers, the probability for stalling
    -- essentially decreases. All ranges default to 0.
    --#########################################################################
    procedure set_valid_cyc(val : integer) is
    begin
      set_valid_cyc(val, val);
    end procedure;

    procedure set_valid_cyc(low : integer; high : integer) is
    begin
      cfg_valid_low := low;
      cfg_valid_high := high;
    end procedure;

    procedure set_total_cyc(val : integer) is
    begin
      set_total_cyc(val, val);
    end procedure;

    procedure set_total_cyc(low : integer; high : integer) is
    begin
      cfg_total_low := low;
      cfg_total_high := high;
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
      return mon.g_ctrl_width;
    end function;

    impure function g_x_width return natural is
    begin
      return mon.g_x_width;
    end function;

    impure function g_y_width return natural is
    begin
      return mon.g_y_width;
    end function;

    impure function g_z_width return natural is
    begin
      return mon.g_z_width;
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

  end protected body streamsink_type;

end package body StreamSink_pkg;
