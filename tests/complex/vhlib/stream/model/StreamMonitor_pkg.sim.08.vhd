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

-- This package provides the component declaration and control functions for
-- StreamMonitor_mdl.

package StreamMonitor_pkg is

  -- Component declaration.
  component StreamMonitor_mdl is
    generic (
      NAME                      : string := "noname";
      ELEMENT_WIDTH             : natural := 8;
      COUNT_MAX                 : natural := 1;
      COUNT_WIDTH               : natural := 1;
      CTRL_WIDTH                : natural := 1;
      X_WIDTH                   : natural := 1;
      Y_WIDTH                   : natural := 1;
      Z_WIDTH                   : natural := 1
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic := '0';
      valid                     : in  std_logic := '1';
      ready                     : in  std_logic := '1';
      dvalid                    : in  std_logic := '1';
      data                      : in  std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0) := (others => '0');
      count                     : in  std_logic_vector(COUNT_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(COUNT_MAX, COUNT_WIDTH));
      last                      : in  std_logic := '1';
      ctrl                      : in  std_logic_vector(CTRL_WIDTH-1 downto 0) := (others => '0');
      x                         : in  std_logic_vector(X_WIDTH-1 downto 0) := (others => '0');
      y                         : in  std_logic_vector(Y_WIDTH-1 downto 0) := (others => '0');
      z                         : in  std_logic_vector(Z_WIDTH-1 downto 0) := (others => '0')
    );
  end component;

  -- Stream monitor interface.
  type streammonitor_type is protected

    -- Links this interface to a StreamMonitor model. This should be called
    -- before anything else.
    procedure       initialize    (nam : string := "noname");
    impure function name          return string;

    -- These functions query the generics of the linked model.
    impure function g_el_width    return natural;
    impure function g_count_max   return natural;
    impure function g_count_width return natural;
    impure function g_ctrl_width  return natural;
    impure function g_x_width     return natural;
    impure function g_y_width     return natural;
    impure function g_z_width     return natural;

    -- These functions query the state of the valid and ready signals at the
    -- most recent rising clock edge.
    impure function valid         return std_logic;
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

  end protected streammonitor_type;

  -- Convenience procedure to wait for a packet to become ready, i.e. for
  -- sm.pq_ready to become true. Waits for poll*cnt at most; if this timeout
  -- expires the simulation is killed. pq_ready is polled with the interval
  -- specified by poll.
  procedure pq_wait(sm : inout streammonitor_type; poll : time; cnt : positive);

  -- Convenience procedure to wait for a transfer to become ready, i.e. for
  -- sm.cq_ready to become true. Waits for poll*cnt at most; if this timeout
  -- expires the simulation is killed. cq_ready is polled with the interval
  -- specified by poll.
  procedure cq_wait(sm : inout streammonitor_type; poll : time; cnt : positive);

  -- Communication global for StreamMonitor instances.
  shared variable strmon    : sc_data_type;

end package StreamMonitor_pkg;

package body StreamMonitor_pkg is

  type streammonitor_type is protected body

    --#########################################################################
    -- Private entries.
    --#########################################################################

    -- Name of the linked model.
    variable n  : line;


    --#########################################################################
    -- Links this interface to a StreamMonitor model. This should be called
    -- before anything else.
    --#########################################################################
    procedure initialize(nam : string := "noname") is
    begin
      tc_check_nw(strmon.exists(nam), "Could not find StreamMonitor " & nam);
      n := new string'(nam);
    end procedure;

    impure function name return string is
    begin
      return n.all;
    end function;

    --#########################################################################
    -- These functions query the generics of the linked model.
    --#########################################################################
    impure function g_el_width return natural is
    begin
      return strmon.get_int(n.all & ".g.el_width");
    end function;

    impure function g_count_max return natural is
    begin
      return strmon.get_int(n.all & ".g.count_max");
    end function;

    impure function g_count_width return natural is
    begin
      return strmon.get_int(n.all & ".g.count_width");
    end function;

    impure function g_ctrl_width return natural is
    begin
      return strmon.get_int(n.all & ".g.ctrl_width");
    end function;

    impure function g_x_width return natural is
    begin
      return strmon.get_int(n.all & ".g.x_width");
    end function;

    impure function g_y_width return natural is
    begin
      return strmon.get_int(n.all & ".g.y_width");
    end function;

    impure function g_z_width return natural is
    begin
      return strmon.get_int(n.all & ".g.z_width");
    end function;


    --#########################################################################
    -- These functions query the state of the valid and ready signals at the
    -- most recent rising clock edge.
    --#########################################################################
    impure function valid return std_logic is
    begin
      return strmon.get_std(n.all & ".valid");
    end function;

    impure function ready return std_logic is
    begin
      return strmon.get_std(n.all & ".ready");
    end function;


    --#########################################################################
    -- These procedures operate on the packet/element queue. pq_ready returns
    -- whether a packet is ready right now, pq_wait waits for at most poll*cnt
    -- until this is the case (checking with intervall poll, exiting with
    -- failure if a timeout occurs). pq_dvalid checks whether there is at
    -- least one element remaining in the current packet. pq_get_str returns
    -- the remaining elements in the packet as characters in a string,
    -- interpreting the elements as unsigned integers and casting them to
    -- chars. The remaining pq_get functions return one element at a time,
    -- and exit with failure if no more elements are available in the packet.
    -- pq_next advances to the next packet.
    --#########################################################################
    impure function pq_ready return boolean is
    begin
      return strmon.is_queue(n.all & ".pq");
    end function;

    impure function pq_avail return boolean is
    begin
      return strmon.is_queue(n.all & ".pq.dq");
    end function;

    impure function pq_get_slv_int return std_logic_vector is
    begin
      tc_check_nw(pq_avail, "StreamMonitor " & n.all & ": no data available.");
      return strmon.get_slv(n.all & ".pq.dq");
    end function;

    impure function pq_get_slv return std_logic_vector is
      constant slv : std_logic_vector := pq_get_slv_int;
    begin
      strmon.pop(n.all & ".pq.dq");
      return slv;
    end function;

    impure function pq_get_uns return unsigned is
    begin
      return unsigned(pq_get_slv);
    end function;

    impure function pq_get_sgn return signed is
    begin
      return signed(pq_get_slv);
    end function;

    impure function pq_get_int return integer is
    begin
      return to_integer(pq_get_sgn);
    end function;

    impure function pq_get_nat return natural is
    begin
      return to_integer(pq_get_uns);
    end function;

    impure function pq_get_str return string is
      variable s  : string(1 to 1) := "?";
    begin
      tc_check_nw(pq_ready, "StreamMonitor " & n.all & ": no packet available.");
      if pq_avail then
        s(s'low) := character'val(pq_get_nat mod 256);
        -- This check is not necessary, but avoids concatenating null strings
        -- (null vector implementations are sketchy among tool vendors).
        if pq_avail then
          return s & pq_get_str;
        else
          pq_next;
          return s;
        end if;
      else
        pq_next;
        return "";
      end if;
    end function;

    procedure pq_next(allow_nonempty : boolean := false) is
    begin
      if not allow_nonempty then
        tc_check_nw(not pq_avail, "StreamMonitor " & n.all & ": packet was longer than expected.");
      end if;
      strmon.pop(n.all & ".pq");
    end procedure;


    --#########################################################################
    -- These procedures operate on the control queue. cq_ready returns whether
    -- a transfer is ready right now, cq_wait waits for at most poll*cnt until
    -- this is the case (checking with intervall poll, exiting with failure if
    -- a timeout occurs). The cq_get_* functions return information from the
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
      return strmon.is_queue(n.all & ".cq");
    end function;

    impure function cq_get_dvalid return std_logic is
    begin
      tc_check_nw(cq_ready, "StreamMonitor " & n.all & ": no data available.");
      return strmon.get_std(n.all & ".cq.dat.dvalid");
    end function;

    impure function cq_get_data return std_logic_vector is
    begin
      tc_check_nw(cq_ready, "StreamMonitor " & n.all & ": no data available.");
      return strmon.get_slv(n.all & ".cq.dat.data");
    end function;

    impure function cq_get_d_uns return unsigned is
    begin
      return unsigned(cq_get_data);
    end function;

    impure function cq_get_d_sgn return signed is
    begin
      return signed(cq_get_data);
    end function;

    impure function cq_get_d_int return integer is
    begin
      return to_integer(cq_get_d_sgn);
    end function;

    impure function cq_get_d_nat return natural is
    begin
      return to_integer(cq_get_d_uns);
    end function;

    impure function cq_get_d_str return string is
      variable s  : string(1 to 1) := "?";
    begin
      if cq_ready then
        s(s'low) := character'val(cq_get_d_nat mod 256);
        cq_next;
        -- This check is not necessary, but avoids concatenating null strings
        -- (null vector implementations are sketchy among tool vendors).
        if cq_ready then
          return s & cq_get_d_str;
        else
          return s;
        end if;
      else
        return "";
      end if;
    end function;

    impure function cq_get_count return std_logic_vector is
    begin
      tc_check_nw(cq_ready, "StreamMonitor " & n.all & ": no data available.");
      return strmon.get_slv(n.all & ".cq.dat.count");
    end function;

    impure function cq_get_ecount return integer is
      variable ecount : natural;
    begin
      tc_check_nw(not is_X(cq_get_dvalid), "StreamMonitor " & n.all & ": undefined dvalid.");
      if to_X01(cq_get_dvalid) = '0' then
        return 0;
      end if;
      tc_check_nw(not is_X(cq_get_count), "StreamMonitor " & n.all & ": undefined count.");
      ecount := to_integer(unsigned(cq_get_count));
      if ecount = 0 and (g_count_max = 2**g_count_width) then
        ecount := g_count_max;
      end if;
      if ecount < 1 or ecount > g_count_max then
        tc_check_nw(not is_X(cq_get_count), "StreamMonitor " & n.all & ": count out of range.");
      end if;
      return ecount;
    end function;

    impure function cq_get_last return std_logic is
    begin
      tc_check_nw(cq_ready, "StreamMonitor " & n.all & ": no data available.");
      return strmon.get_std(n.all & ".cq.dat.last");
    end function;

    impure function cq_get_ctrl return std_logic_vector is
    begin
      tc_check_nw(cq_ready, "StreamMonitor " & n.all & ": no data available.");
      return strmon.get_slv(n.all & ".cq.dat.ctrl");
    end function;

    impure function cq_get_x return std_logic_vector is
    begin
      tc_check_nw(cq_ready, "StreamMonitor " & n.all & ": no data available.");
      return strmon.get_slv(n.all & ".cq.dat.x");
    end function;

    impure function cq_get_y return std_logic_vector is
    begin
      tc_check_nw(cq_ready, "StreamMonitor " & n.all & ": no data available.");
      return strmon.get_slv(n.all & ".cq.dat.y");
    end function;

    impure function cq_get_z return std_logic_vector is
    begin
      tc_check_nw(cq_ready, "StreamMonitor " & n.all & ": no data available.");
      return strmon.get_slv(n.all & ".cq.dat.z");
    end function;

    impure function cq_cyc_valid return integer is
    begin
      tc_check_nw(cq_ready, "StreamMonitor " & n.all & ": no data available.");
      return strmon.get_int(n.all & ".cq.cyc.valid");
    end function;

    impure function cq_cyc_ready return integer is
    begin
      tc_check_nw(cq_ready, "StreamMonitor " & n.all & ": no data available.");
      return strmon.get_int(n.all & ".cq.cyc.ready");
    end function;

    impure function cq_cyc_total return integer is
    begin
      tc_check_nw(cq_ready, "StreamMonitor " & n.all & ": no data available.");
      return strmon.get_int(n.all & ".cq.cyc.total");
    end function;

    impure function cq_x_seen return boolean is
    begin
      tc_check_nw(cq_ready, "StreamMonitor " & n.all & ": no data available.");
      return strmon.get_bool(n.all & ".cq.x_seen");
    end function;

    impure function cq_unstable return boolean is
    begin
      return strmon.get_bool(n.all & ".cq.unstable");
    end function;

    procedure cq_next(allow_x : boolean := false; allow_unstable : boolean := false) is
    begin
      tc_check_nw(cq_ready, "StreamMonitor " & n.all & ": no data available.");
      if not allow_x then
        tc_check_nw(not cq_x_seen, "StreamMonitor " & n.all & ": undefined handshakes were encountered.");
      end if;
      if not allow_unstable then
        tc_check_nw(not cq_unstable, "StreamMonitor " & n.all & ": unstable data was encountered.");
      end if;
      strmon.pop(n.all & ".cq");
    end procedure;

  end protected body streammonitor_type;

  -- Convenience procedure to wait for a packet to become ready, i.e. for
  -- sm.pq_ready to become true. Waits for poll*cnt at most; if this timeout
  -- expires the simulation is killed. pq_ready is polled with the interval
  -- specified by poll.
  procedure pq_wait(sm : inout streammonitor_type; poll : time; cnt : positive) is
  begin
    for i in 0 to cnt loop
      if sm.pq_ready then
        return;
      end if;
      wait for poll;
    end loop;
    if not sm.pq_ready then
      tc_fail("StreamMonitor " & sm.name & ": timeout waiting for next packet.");
    end if;
  end procedure;

  -- Convenience procedure to wait for a transfer to become ready, i.e. for
  -- sm.cq_ready to become true. Waits for poll*cnt at most; if this timeout
  -- expires the simulation is killed. cq_ready is polled with the interval
  -- specified by poll.
  procedure cq_wait(sm : inout streammonitor_type; poll : time; cnt : positive) is
  begin
    for i in 0 to cnt loop
      if sm.cq_ready then
        return;
      end if;
      wait for poll;
    end loop;
    if not sm.cq_ready then
      tc_fail("StreamMonitor " & sm.name & ": timeout waiting for next transfer.");
    end if;
  end procedure;

end package body StreamMonitor_pkg;
