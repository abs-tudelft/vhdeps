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

-- This package forms the basis for all automated testing within vhlib.

-- A test suite for some component consists of one or more test cases (toplevel
-- simulation entities), which in turn can run one or more "subtests". Each
-- subtest lives in its own process, starting with a tc_open call and ending
-- with tc_pass or some kind of failure. Subtests are named, and execute in
-- alphabetical order if used correctly.

package TestCase_pkg is

  signal test : std_logic := '1';

  -----------------------------------------------------------------------------
  -- Test case functions
  -----------------------------------------------------------------------------
  -- Sets the name for the test case. This is just printed in the header and
  -- footer of the test case runner if specified, it is not used elsewhere.
  -- If used, it should be called before (one of the) tc_open calls.
  procedure tc_name(name : string; desc : string := "");

  -- Opens a subtest. If a subtest is already open, this function delays until
  -- it passes or fails. As long as all subtests are started in the first
  -- simulation cycle, they are executed in alphabetical order. tc_open waits
  -- until all models that specify an initialization time have completed using
  -- the specified time resolution.
  procedure tc_open(name : string := "main"; desc : string := ""; timeout : time := 0 ns);

  -- Marks the current subtest as passed. If this is the last subtest, the
  -- entire test case is completed (with either failure or success depending
  -- on whether the other subtests passed).
  procedure tc_pass;

  -----------------------------------------------------------------------------
  -- Common functions
  -----------------------------------------------------------------------------
  -- Fails the current subtest unconditionally.
  procedure tc_fail(                                                         msg : string := "Check failed");

  -- Check whether the given condition is true, failing the subtest if not.
  procedure tc_check(cnd : boolean;                                          msg : string := "Check failed");

  -- Check for equality between an expected and actual value, failing the
  -- subtest if not.
  procedure tc_check(act : string;           exp : string;                   msg : string := "Check failed");
  procedure tc_check(act : boolean;          exp : boolean;                  msg : string := "Check failed");
  procedure tc_check(act : std_logic;        exp : std_logic;                msg : string := "Check failed");
  procedure tc_check(act : std_logic_vector; exp : std_logic_vector;         msg : string := "Check failed");
  procedure tc_check(act : unsigned;         exp : std_logic_vector;         msg : string := "Check failed");
  procedure tc_check(act : signed;           exp : std_logic_vector;         msg : string := "Check failed");
  procedure tc_check(act : std_logic_vector; exp : integer;                  msg : string := "Check failed");
  procedure tc_check(act : unsigned;         exp : integer;                  msg : string := "Check failed");
  procedure tc_check(act : signed;           exp : integer;                  msg : string := "Check failed");
  procedure tc_check(act : integer;          exp : integer;                  msg : string := "Check failed");
  procedure tc_check(act : real;             exp : real;                     msg : string := "Check failed");
  procedure tc_check(act : time;             exp : time;                     msg : string := "Check failed");

  -- Check for equality between an expected and actual value with a nonzero
  -- +/- tolerance, failing the subtest if not.
  procedure tc_check(act : std_logic_vector; exp : integer;  tol : integer;  msg : string := "Check failed");
  procedure tc_check(act : unsigned;         exp : integer;  tol : integer;  msg : string := "Check failed");
  procedure tc_check(act : signed;           exp : integer;  tol : integer;  msg : string := "Check failed");
  procedure tc_check(act : integer;          exp : integer;  tol : integer;  msg : string := "Check failed");
  procedure tc_check(act : real;             exp : real;     tol : real;     msg : string := "Check failed");
  procedure tc_check(act : time;             exp : time;     tol : time;     msg : string := "Check failed");

  -- These procedures can be used to print warning messages. They are
  -- suppressed when no test case is running, and are also automatically
  -- suppressed when there are more than 10 warnings with the exact same
  -- name (per test case). name and msg are printed concatenated to each
  -- other, but only name is used for the duplicate check.
  procedure tc_warn(name : string; msg : string := "");
  procedure tc_warn(cond : boolean; name : string; msg : string := "");

  -- These procedures can be used to print notes. They are suppressed when
  -- no test case is running, but are not automatically supressed when they
  -- occur too often.
  procedure tc_note(msg : string);

  -- Waits for the specified amount of time if it is within the bounds of what
  -- the subtest is limited to, or fails the subtest (unless pass is called
  -- from another process first) and waits forever.
  procedure tc_wait_for(del : time);

  -- Waits for a signal event. If the subtest deadline is reached first, the
  -- test fails and this waits forever.
  procedure tc_wait_on(signal s : in std_logic);
  procedure tc_wait_on(signal s : in std_logic_vector);
  procedure tc_wait_on(signal s : in signed);
  procedure tc_wait_on(signal s : in unsigned);

  -- Same as above, but with a timeout. Returns when either the signal changes
  -- or the time expires, fails the subtest and waits forever if the subtest
  -- timeout expires.
  procedure tc_wait_on(signal s : in std_logic;        timeout : time);
  procedure tc_wait_on(signal s : in std_logic_vector; timeout : time);
  procedure tc_wait_on(signal s : in signed;           timeout : time);
  procedure tc_wait_on(signal s : in unsigned;         timeout : time);

  -- Same as above, also returns whether the timeout exired (exp = true) or
  -- the signal changed (exp = false).
  procedure tc_wait_on(signal s : in std_logic;        timeout : time; expired : out boolean);
  procedure tc_wait_on(signal s : in std_logic_vector; timeout : time; expired : out boolean);
  procedure tc_wait_on(signal s : in signed;           timeout : time; expired : out boolean);
  procedure tc_wait_on(signal s : in unsigned;         timeout : time; expired : out boolean);

  -----------------------------------------------------------------------------
  -- Model functions
  -----------------------------------------------------------------------------
  -- Models that generate simulation events on their own (e.g. clock
  -- generators) should check tc_resetting at least this often, preferably
  -- synchronized to the start of the simulation.
  constant TC_SYNC_PERIOD : time := 1 us;

  -- Call before registering a model with SimComms for eye candy.
  procedure tc_model_registered(typ : string; name : string);

  -- The test case runner waits with passing control to the test case until all
  -- models report that they have initialized. A model can report that it is
  -- busy initializing by assigning '1' to tc_model_init. When it completes, it
  -- should assign 'Z'.
  signal tc_model_init : std_logic := 'Z';

  -- Returns whether models such as clock generators should be resetting
  -- right now. They need to check this function at least every TC_SYNC_PERIOD.
  impure function tc_resetting return boolean;

  -- Returns whether models such as clock generators should stop generating
  -- events.
  impure function tc_complete return boolean;

  -- Waits forever if the test case is complete.
  procedure tc_yield;

  -- String hash function to generate a random seed from a model name.
  function tc_random_seed(name : string) return positive;

  -- The following procedures are copies of the above that terminate with a
  -- failure immediately instead of waiting indefinitely. They are to be used
  -- within protected bodies or functions, which are not allowed to call wait.
  procedure tc_fail_nw(                                                         msg : string := "Check failed");
  procedure tc_check_nw(cnd : boolean;                                          msg : string := "Check failed");
  procedure tc_check_nw(act : string;           exp : string;                   msg : string := "Check failed");
  procedure tc_check_nw(act : boolean;          exp : boolean;                  msg : string := "Check failed");
  procedure tc_check_nw(act : std_logic;        exp : std_logic;                msg : string := "Check failed");
  procedure tc_check_nw(act : std_logic_vector; exp : std_logic_vector;         msg : string := "Check failed");
  procedure tc_check_nw(act : unsigned;         exp : std_logic_vector;         msg : string := "Check failed");
  procedure tc_check_nw(act : signed;           exp : std_logic_vector;         msg : string := "Check failed");
  procedure tc_check_nw(act : std_logic_vector; exp : integer;                  msg : string := "Check failed");
  procedure tc_check_nw(act : unsigned;         exp : integer;                  msg : string := "Check failed");
  procedure tc_check_nw(act : signed;           exp : integer;                  msg : string := "Check failed");
  procedure tc_check_nw(act : integer;          exp : integer;                  msg : string := "Check failed");
  procedure tc_check_nw(act : real;             exp : real;                     msg : string := "Check failed");
  procedure tc_check_nw(act : time;             exp : time;                     msg : string := "Check failed");
  procedure tc_check_nw(act : std_logic_vector; exp : integer;  tol : integer;  msg : string := "Check failed");
  procedure tc_check_nw(act : unsigned;         exp : integer;  tol : integer;  msg : string := "Check failed");
  procedure tc_check_nw(act : signed;           exp : integer;  tol : integer;  msg : string := "Check failed");
  procedure tc_check_nw(act : integer;          exp : integer;  tol : integer;  msg : string := "Check failed");
  procedure tc_check_nw(act : real;             exp : real;     tol : real;     msg : string := "Check failed");
  procedure tc_check_nw(act : time;             exp : time;     tol : time;     msg : string := "Check failed");

  -- Returns whether the current subtest has a deadline.
  impure function tc_has_deadline return boolean;

  -- Returns the maximum delay that we are allowed to wait for before the
  -- subtest deadline expires. Used for "wait until" statements without time
  -- limit.
  impure function tc_max_delay return time;

  -- Clamps the given delay to the maximum delay that this subtest is still
  -- allowed to run for. After delaying by this long, call tc_check_timeout.
  impure function tc_clamp_delay(del : time) return time;

  -- Checks whether the subtest timeout has passed. If it has, waits forever.
  procedure tc_check_timeout;

end package TestCase_pkg;

package body TestCase_pkg is

  -- Prints a line of text to stdout.
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

  -- Padds a string with the second string if the second is longer.
  function strpad(s : string; pad : string) return string is
    variable ret  : string(pad'range);
  begin
    if s'length > pad'length then
      return s;
    end if;
    ret := pad;
    ret(s'low to s'low + s'length - 1) := s;
    return ret;
  end function;

  -- Returns the current timestamp.
  procedure printlnt(s: string) is
  begin
    println(strpad(time'image(now), "               |") & " " & s);
  end procedure;

  -- Converts a std_logic_vector to a string.
  function slv2str(slv : std_logic_vector) return string is
    variable ret  : string(1 to slv'length + 2);
    variable si   : positive := 2;
  begin
    for i in slv'range loop
      case slv(i) is
        when 'U' => ret(si) := 'U';
        when 'X' => ret(si) := 'X';
        when '0' => ret(si) := '0';
        when '1' => ret(si) := '1';
        when 'Z' => ret(si) := 'Z';
        when 'W' => ret(si) := 'W';
        when 'L' => ret(si) := 'L';
        when 'H' => ret(si) := 'H';
        when '-' => ret(si) := '-';
      end case;
      si := si + 1;
    end loop;
    ret(1) := '"';
    ret(slv'length + 2) := '"';
    return ret;
  end function;

  type str_ptr is access string;

  type subtest_state_type is (ST_PENDING, ST_RUNNING, ST_PASSED, ST_FAILED);

  type subtest_type;
  type subtest_ptr is access subtest_type;
  type subtest_type is record
    nxt   : subtest_ptr;
    sname : str_ptr;
    sdesc : str_ptr;
    state : subtest_state_type;
    msg   : str_ptr;
    tout  : time;
  end record;

  type warning_type;
  type warning_ptr is access warning_type;
  type warning_type is record
    nxt   : warning_ptr;
    name  : str_ptr;
    count : natural;
  end record;

  constant WARN_THRES : natural := 10;

  -- Subtest registry.
  type subtests_type is protected

    -- Sets the name of the test case.
    procedure set_name(name : string; descr : string := "");

    -- Registers a subtest.
    procedure add(stname : string; descr : string; timeout : time);

    -- Asks whether the subtest with the given name can start. If this returns
    -- false, the subtest process should stall for exactly 1 us and then retry.
    -- If true, the subtest should start.
    impure function start(name : string) return boolean;

    -- Releases the reset signal.
    procedure release_reset;

    -- Returns whether the current subtest has a deadline.
    impure function has_deadline return boolean;

    -- Returns the maximum delay that we are allowed to wait for before the
    -- subtest deadline expires. Used for "wait until" statements without time
    -- limit.
    impure function max_delay return time;

    -- Clamps the given delay to the maximum delay that this subtest is still
    -- allowed to run for. After delaying by this long, call check_timeout.
    impure function clamp_delay(del : time) return time;

    -- Checks whether the subtest timeout has passed. Returns true if it has,
    -- in which case the subtest has already been failed and the caller
    -- should just wait forever.
    impure function check_timeout return boolean;

    -- Marks the currently running subtest as passed and allows other subtests
    -- to start.
    procedure pass;

    -- Marks the currently running subtest as failed and allows other subtests
    -- to start.
    procedure fail(msg : string);

    -- Records an unrecoverable error and terminate the simulation immediately.
    procedure die(msg : string);

    -- Returns whether models such as clock generators should be resetting
    -- right now. They need to check this function at least every microsecond.
    impure function resetting return boolean;

    -- Returns whether models such as clock generators should stop generating
    -- events.
    impure function complete return boolean;

    -- This procedure can be used to print warning messages. They are
    -- suppressed when no test case is running, and are also automatically
    -- suppressed when there are more than 10 warnings with the exact same
    -- name (per test case). name and msg are printed concatenated to each
    -- other, but only name is used for the duplicate check.
    procedure warn(name : string; msg : string);

    -- This procedure can be used to print notes. They are suppressed when
    -- no test case is running.
    procedure no_te(msg : string);

  end protected subtests_type;

  type subtests_type is protected body

    -- Test storage. The first entry in the list is an unused sentinal.
    variable st   : subtest_ptr;

    -- Warning storage. The first entry in the list is an unused sentinal.
    variable wrn  : warning_ptr;

    -- Whether there was an external failure (fail outside subtest).
    variable ef   : boolean;

    -- Whether anything is currently running.
    variable ar   : boolean;

    -- Whether we're currently resetting.
    variable rstn : boolean;

    -- Whether all tests are done.
    variable don  : boolean;

    -- Deadline for the current subtest. Use the tc_wait_for call to honor this
    -- in all test-case based code; it will fail the subtest if the specified
    -- wait time is too long.
    variable dead : time;

    -- Start time for the current subtest.
    variable sts  : time;

    -- Name and description for the test case.
    variable nam  : str_ptr;
    variable desc : str_ptr;

    -- Your usual strcmp function.
    function strcmp(left : string; right : string) return integer is
      variable minlen  : natural;
    begin
      minlen := left'length;
      if right'length < minlen then
        minlen := right'length;
      end if;
      for i in 1 to minlen loop
        if character'pos(left(i)) < character'pos(right(i)) then
          return -1;
        elsif character'pos(left(i)) > character'pos(right(i)) then
          return 1;
        end if;
      end loop;
      if left'length < right'length then
        return -1;
      elsif left'length > right'length then
        return 1;
      else
        return 0;
      end if;
    end function;

    -- Sets the name of the test case.
    procedure set_name(name : string; descr : string := "") is
    begin
      if nam /= null then
        deallocate(nam);
      end if;
      nam := new string'(name);
      if descr /= "" then
        if desc /= null then
          deallocate(desc);
        end if;
        desc := new string'(descr);
      end if;
    end procedure;

    -- Prints the header.
    procedure print_header is
    begin
      println("================================================================================");
      println(" VHLIB TEST CASE FRAMEWORK");
      println("================================================================================");
      if nam /= null then
        println("Test case: " & nam.all);
      end if;
      if desc /= null then
        println("Description: " & desc.all);
      end if;
    end procedure;

    -- Registers a subtest.
    procedure add(stname : string; descr : string; timeout : time) is
      variable it : subtest_ptr;
    begin
      if st = null then
        if ef then
          die("Initialization failed!");
        end if;
        print_header;
        rstn := false;
        don := false;
        st := new subtest_type'(
          nxt   => null,
          sname => null,
          sdesc => null,
          state => ST_PENDING,
          msg   => null,
          tout  => 0 ns
        );
      end if;
      it := st;
      loop
        exit when it.all.nxt = null;
        exit when strcmp(stname, it.all.nxt.all.sname.all) < 0;
        it := it.all.nxt;
      end loop;
      it.all.nxt := new subtest_type'(
        nxt   => it.all.nxt,
        sname => new string'(stname),
        sdesc => null,
        state => ST_PENDING,
        msg   => null,
        tout  => timeout
      );
      if descr /= "" then
        it.all.nxt.all.sdesc := new string'(descr);
      end if;
      println("Found subtest " & stname);
    end procedure;

    -- Asks whether the subtest with the given name can start. If this returns
    -- false, the subtest process should stall for exactly 1 us and then retry.
    -- If true, the subtest should start.
    impure function start(name : string) return boolean is
      variable it   : subtest_ptr;
    begin
      if ar then
        return false;
      end if;
      it := st.all.nxt;
      loop
        if it = null then
          report "Unexpected call to start for subtest " & name severity failure;
          return false;
        end if;
        if name = it.all.sname.all then
          if it.all.state = ST_PENDING then
            it.all.state := ST_RUNNING;
            ar := true;
            println("---------------+----------------------------------------------------------------");
            if it.all.sdesc /= null then
              printlnt("Starting test " & name & ": " & it.sdesc.all);
            else
              printlnt("Starting test " & name);
            end if;
            if it.all.tout = 0 ns then
              dead := 0 ns;
            else
              dead := now + it.all.tout;
              printlnt("Setting deadline to now + " & time'image(it.all.tout) & " = " & time'image(dead));
            end if;
            sts := now;
            return true;
          end if;
        end if;
        if it.all.state = ST_PENDING then
          return false;
        end if;
        it := it.all.nxt;
      end loop;
    end function;

    -- Releases the reset signal.
    procedure release_reset is
    begin
      rstn := true;
    end procedure;

    -- Prints simulation summary and exits.
    procedure end_simulation is
      variable it     : subtest_ptr;
      variable failed : boolean;
    begin
      don := true;
      rstn := false;
      println("---------------+----------------------------------------------------------------");
      if nam /= null then
        println(nam.all & " took " & time'image(now) & ". Summary:");
      else
        println("The test took " & time'image(now) & ". Summary:");
      end if;
      if st /= null then
        it := st.all.nxt;
        failed := false;
        while it /= null loop
          case it.all.state is
            when ST_PASSED => println(" * PASSED " & it.all.sname.all);
            when ST_FAILED | ST_RUNNING => println(" * FAILED " & it.all.sname.all & ": " & it.all.msg.all); failed := true;
            when ST_PENDING => println(" * SKIP   " & it.all.sname.all & ": " & it.all.msg.all); failed := true;
          end case;
          it := it.all.nxt;
        end loop;
      end if;
      if ef then
        println(" * One or more failures were reported outside of a test case.");
        failed := true;
      end if;
      println("================================================================================");
      if failed then
        if nam /= null then
          println(" TEST COMPLETE: result for " & nam.all & " is ***FAILURE***");
        else
          println(" TEST COMPLETE: result is ***FAILURE***");
        end if;
        println("================================================================================");
        report "Test case failed" severity failure;
      else
        if nam /= null then
          println(" TEST COMPLETE: result for " & nam.all & " is ***SUCCESS***");
        else
          println(" TEST COMPLETE: result is ***SUCCESS***");
        end if;
        println("================================================================================");
      end if;
    end procedure;

    -- Checks whether all tests are done. If so, prints a summary; otherwise
    -- do nothing.
    procedure check_done is
      variable it   : subtest_ptr;
    begin
      if ar then
        return;
      end if;
      it := st.all.nxt;
      while it /= null loop
        if (it.all.state = ST_PENDING) or (it.all.state = ST_RUNNING) then
          return;
        end if;
        it := it.all.nxt;
      end loop;
      end_simulation;
    end procedure;

    -- Resets warning message information.
    procedure reset_warnings is
      variable it   : warning_ptr;
      variable tmp  : warning_ptr;
    begin
      if wrn = null then
        return;
      end if;
      it := wrn.all.nxt;
      wrn.all.nxt := null;
      while it /= null loop
        if it.all.count > WARN_THRES then
          printlnt("Suppressed warning " & integer'image(it.all.count - WARN_THRES) & "x: " & it.all.name.all);
        end if;
        tmp := it.all.nxt;
        deallocate(it.all.name);
        deallocate(it);
        it := tmp;
      end loop;
    end procedure;

    -- Marks the currently running subtest as passed or failed and allows other
    -- subtests to start.
    impure function stop(result : subtest_state_type; msg : string) return boolean is
      variable it   : subtest_ptr;
    begin
      if not ar then
        return false;
      end if;
      it := st.all.nxt;
      loop
        if it = null then
          return false;
        end if;
        if it.all.state = ST_RUNNING then
          if result = ST_FAILED then
            printlnt("Test " & it.all.sname.all & " failed: " & msg);
          else
            printlnt("Test " & it.all.sname.all & " passed!");
          end if;
          if dead = 0 ns then
            printlnt("Took " & time'image(now - sts));
          elsif now < dead then
            printlnt("Took " & time'image(now - sts) & " (" & integer'image(((now - sts) * 100) / it.all.tout) & "% of deadline)");
          end if;
          it.all.state := result;
          it.all.msg := new string'(msg);
          rstn := false;
          ar := false;
          reset_warnings;
          check_done;
          return true;
        end if;
        it := it.all.nxt;
      end loop;
      report "Sorry, what?" severity failure;
      return false;
    end function;

    -- Returns whether the current subtest has a deadline.
    impure function has_deadline return boolean is
    begin
      return dead /= 0 ns;
    end function;

    -- Returns the maximum delay that we are allowed to wait for before the
    -- subtest deadline expires. Used for "wait until" statements without time
    -- limit.
    impure function max_delay return time is
    begin
      if dead = 0 ns then
        report "tc_max_delay called during test without deadline. Check with tc_has_deadline first!" severity failure;
        return -1 ns;
      else
        return dead - now;
      end if;
    end function;

    -- Clamps the given delay to the maximum delay that this subtest is still
    -- allowed to run for. After delaying by this long, call check_timeout.
    impure function clamp_delay(del : time) return time is
    begin
      if dead = 0 ns then
        return del;
      elsif now > dead then
        tc_warn("tc_clamp_delay called after timeout has already expired. Missing tc_check_timeout?");
        return 1 ns;
      elsif now + del > dead then
        return dead - now;
      else
        return del;
      end if;
    end function;

    -- Checks whether the subtest timeout has passed. Returns true if it has,
    -- in which case the subtest has already been failed and the caller
    -- should just wait forever.
    impure function check_timeout return boolean is
      variable dum  : boolean;
    begin
      if dead = 0 ns then
        return false;
      elsif now >= dead then
        dum := stop(ST_FAILED, "Subtest timed out");
        return true;
      else
        return false;
      end if;
    end function;

    -- Marks the currently running subtest as passed and allows other subtests
    -- to start.
    procedure pass is
    begin
      if not stop(ST_PASSED, "") then
        report "Unexpected call to stop" severity failure;
      end if;
    end procedure;

    -- Marks the currently running subtest as failed and allows other subtests
    -- to start.
    procedure fail(msg : string) is
    begin
      if st = null and ef = false then
        print_header;
      end if;
      if not stop(ST_FAILED, msg) then
        println("Recording failure outside subtest: " & msg);
        ef := true;
      end if;
    end procedure;

    -- Records an unrecoverable error and terminate the simulation immediately.
    procedure die(msg : string) is
    begin
      if st = null and ef = false then
        print_header;
      end if;
      if not stop(ST_FAILED, msg) then
        println("Recording failure outside test case: " & msg);
        ef := true;
      end if;
      println("This failure is fatal. Simulation cannot continue.");
      end_simulation;
    end procedure;

    -- Returns whether models such as clock generators should be resetting
    -- right now. They need to check this function at least every microsecond.
    impure function resetting return boolean is
    begin
      return not rstn;
    end function;

    -- Returns whether models such as clock generators should stop generating
    -- events.
    impure function complete return boolean is
    begin
      return don;
    end function;

    -- Prints a warning message unless the warning is suppressed. Warnings are
    -- suppressed when no test case is running, and are also automatically
    -- suppressed when there are more than 10 warnings with the exact same
    -- message (per test case).
    procedure warn(name : string; msg : string) is
      variable it   : warning_ptr;
    begin
      if not ar then
        return;
      end if;
      if wrn = null then
        wrn := new warning_type'(nxt => null, name => null, count => 0);
      end if;
      it := wrn;
      while it.all.nxt /= null loop
        exit when it.all.nxt.all.name.all = name;
        it := it.all.nxt;
      end loop;
      if it.all.nxt = null then
        it.all.nxt := new warning_type'(nxt => null, name => new string'(name), count => 0);
      end if;
      it := it.all.nxt;
      it.all.count := it.all.count + 1;
      if it.all.count < WARN_THRES then
        printlnt("Warning: " & name & msg);
      elsif it.all.count = WARN_THRES then
        printlnt("Warning (suppressing): " & name & msg);
      end if;
    end procedure;

    -- This procedure can be used to print notes. They are suppressed when
    -- no test case is running.
    procedure no_te(msg : string) is
    begin
      if not ar then
        return;
      end if;
      printlnt(msg);
    end procedure;

  end protected body subtests_type;

  shared variable tc_reg : subtests_type;

  -- Sets the name for the test case. This is just printed in the header and
  -- footer of the test case runner if specified, it is not used elsewhere.
  -- If used, it should be called before (one of the) tc_open calls.
  procedure tc_name(name : string; desc : string := "") is
  begin
    tc_reg.set_name(name, desc);
  end procedure;

  -- Opens a subtest. If a subtest is already open, this function delays until
  -- it passes or fails. As long as all subtests are started in the first
  -- simulation cycle, they are executed in alphabetical order. tc_open waits
  -- until all models that specify an initialization time have completed using
  -- the specified time resolution.
  procedure tc_open(name : string := "main"; desc : string := ""; timeout : time := 0 ns) is
  begin
    wait for TC_SYNC_PERIOD / 2;
    tc_reg.add(name, desc, timeout);
    wait for TC_SYNC_PERIOD / 2;
    while not tc_reg.start(name) loop
      wait for TC_SYNC_PERIOD;
    end loop;
    wait for TC_SYNC_PERIOD;
    tc_reg.release_reset;
    if tc_model_init /= 'Z' then
      wait until tc_model_init = 'Z';
      tc_note("Model initialization complete");
    end if;
  end tc_open;

  -- Marks the current subtest as passed. If this is the last subtest, the
  -- entire test case is completed (with either failure or success depending
  -- on whether the other subtests passed).
  procedure tc_pass is
  begin
    tc_reg.pass;
    wait;
  end procedure;

  -- Fails the current subtest unconditionally.
  procedure tc_fail(msg : string := "Check failed") is
  begin
    tc_reg.fail(msg);
    wait;
  end procedure;

  -- Check whether the given condition is true, failing the subtest if not.
  procedure tc_check(cnd : boolean; msg : string := "Check failed") is
  begin
    if not cnd then
      tc_fail(msg);
    end if;
  end procedure;

  -- std_logic match function that handles don't cares but is still strict
  -- about the other enum entries because damnit VHDL, that is what you want.
  function stl_match(a : std_logic; b : std_logic) return boolean is
  begin
    if a = '-' then
      return true;
    elsif b = '-' then
      return true;
    else
      return a = b;
    end if;
  end function;

  function stl_match(a : std_logic_vector; b : std_logic_vector) return boolean is
    constant aa : std_logic_vector(a'length - 1 downto 0) := a;
    constant ab : std_logic_vector(b'length - 1 downto 0) := b;
  begin
    if a'length /= b'length then
      return false;
    end if;
    for i in aa'range loop
      if not stl_match(aa(i), ab(i)) then
        return false;
      end if;
    end loop;
    return true;
  end function;

  -- Check for equality between an expected and actual value, failing the
  -- subtest if not.
  procedure tc_check(act : string; exp : string; msg : string := "Check failed") is
  begin
    if act /= exp then
      tc_fail(msg & ": """ & act & """ /= """ & exp & """");
    end if;
  end procedure;

  procedure tc_check(act : boolean; exp : boolean; msg : string := "Check failed") is
  begin
    if act /= exp then
      tc_fail(msg & ": " & boolean'image(act) & " /= " & boolean'image(exp));
    end if;
  end procedure;

  procedure tc_check(act : std_logic; exp : std_logic; msg : string := "Check failed") is
  begin
    if not stl_match(act, exp) then
      tc_fail(msg & ": " & std_logic'image(act) & " /= " & std_logic'image(exp));
    end if;
  end procedure;

  procedure tc_check(act : std_logic_vector; exp : std_logic_vector; msg : string := "Check failed") is
  begin
    if not stl_match(act, exp) then
      tc_fail(msg & ": " & slv2str(act) & " /= " & slv2str(exp));
    end if;
  end procedure;

  procedure tc_check(act : unsigned; exp : std_logic_vector; msg : string := "Check failed") is
  begin
    if not stl_match(std_logic_vector(act), exp) then
      tc_fail(msg & ": " & slv2str(std_logic_vector(act)) & " /= " & slv2str(exp));
    end if;
  end procedure;

  procedure tc_check(act : signed; exp : std_logic_vector; msg : string := "Check failed") is
  begin
    if not stl_match(std_logic_vector(act), exp) then
      tc_fail(msg & ": " & slv2str(std_logic_vector(act)) & " /= " & slv2str(exp));
    end if;
  end procedure;

  procedure tc_check(act : std_logic_vector; exp : integer; msg : string := "Check failed") is
  begin
    if to_integer(unsigned(act)) /= exp then
      tc_fail(msg & ": " & integer'image(to_integer(unsigned(act))) & " /= " & integer'image(exp));
    end if;
  end procedure;

  procedure tc_check(act : unsigned; exp : integer; msg : string := "Check failed") is
  begin
    if to_integer(act) /= exp then
      tc_fail(msg & ": " & integer'image(to_integer(act)) & " /= " & integer'image(exp));
    end if;
  end procedure;

  procedure tc_check(act : signed; exp : integer; msg : string := "Check failed") is
  begin
    if to_integer(act) /= exp then
      tc_fail(msg & ": " & integer'image(to_integer(act)) & " /= " & integer'image(exp));
    end if;
  end procedure;

  procedure tc_check(act : integer; exp : integer; msg : string := "Check failed") is
  begin
    if act /= exp then
      tc_fail(msg & ": " & integer'image(act) & " /= " & integer'image(exp));
    end if;
  end procedure;

  procedure tc_check(act : real; exp : real; msg : string := "Check failed") is
  begin
    if act /= exp then
      tc_fail(msg & ": " & real'image(act) & " /= " & real'image(exp));
    end if;
  end procedure;

  procedure tc_check(act : time; exp : time; msg : string := "Check failed") is
  begin
    if act /= exp then
      tc_fail(msg & ": " & time'image(act) & " /= " & time'image(exp));
    end if;
  end procedure;

  -- Check for equality between an expected and actual value with a nonzero
  -- +/- tolerance, failing the subtest if not.
  procedure tc_check(act : std_logic_vector; exp : integer; tol : integer; msg : string := "Check failed") is
  begin
    tc_check(to_integer(unsigned(act)), exp, tol, msg);
  end procedure;

  procedure tc_check(act : unsigned; exp : integer; tol : integer; msg : string := "Check failed") is
  begin
    tc_check(to_integer(act), exp, tol, msg);
  end procedure;

  procedure tc_check(act : signed; exp : integer; tol : integer; msg : string := "Check failed") is
  begin
    tc_check(to_integer(act), exp, tol, msg);
  end procedure;

  procedure tc_check(act : integer; exp : integer; tol : integer; msg : string := "Check failed") is
    variable err  : integer;
  begin
    err := act - exp;
    if err < 0 then
      err := -err;
    end if;
    if err > tol then
      tc_fail(msg & ": " & integer'image(act) & " /= " & integer'image(exp) & " +/- " & integer'image(tol));
    end if;
  end procedure;

  procedure tc_check(act : real; exp : real; tol : real; msg : string := "Check failed") is
    variable err  : real;
  begin
    err := act - exp;
    if err < 0.0 then
      err := -err;
    end if;
    if err > tol then
      tc_fail(msg & ": " & real'image(act) & " /= " & real'image(exp) & " +/- " & real'image(tol));
    end if;
  end procedure;

  procedure tc_check(act : time; exp : time; tol : time; msg : string := "Check failed") is
    variable err  : time;
  begin
    err := act - exp;
    if err < 0 ns then
      err := -err;
    end if;
    if err > tol then
      tc_fail(msg & ": " & time'image(act) & " /= " & time'image(exp) & " +/- " & time'image(tol));
    end if;
  end procedure;

  -- The following procedures are copies of the above that terminate with a
  -- failure immediately instead of waiting indefinitely. They are to be used
  -- within protected bodies or functions, which are not allowed to call wait.
  -- Thanks VHDL.
  procedure tc_fail_nw(msg : string := "Check failed") is
  begin
    tc_reg.die(msg);
  end procedure;

  procedure tc_check_nw(cnd : boolean; msg : string := "Check failed") is
  begin
    if not cnd then
      tc_fail_nw(msg);
    end if;
  end procedure;

  procedure tc_check_nw(act : string; exp : string; msg : string := "Check failed") is
  begin
    if act /= exp then
      tc_fail_nw(msg & ": """ & act & """ /= """ & exp & """");
    end if;
  end procedure;

  procedure tc_check_nw(act : boolean; exp : boolean; msg : string := "Check failed") is
  begin
    if act /= exp then
      tc_fail_nw(msg & ": " & boolean'image(act) & " /= " & boolean'image(exp));
    end if;
  end procedure;

  procedure tc_check_nw(act : std_logic; exp : std_logic; msg : string := "Check failed") is
  begin
    if not stl_match(act, exp) then
      tc_fail_nw(msg & ": " & std_logic'image(act) & " /= " & std_logic'image(exp));
    end if;
  end procedure;

  procedure tc_check_nw(act : std_logic_vector; exp : std_logic_vector; msg : string := "Check failed") is
  begin
    if not stl_match(act, exp) then
      tc_fail_nw(msg & ": " & slv2str(act) & " /= " & slv2str(exp));
    end if;
  end procedure;

  procedure tc_check_nw(act : unsigned; exp : std_logic_vector; msg : string := "Check failed") is
  begin
    if not stl_match(std_logic_vector(act), exp) then
      tc_fail_nw(msg & ": " & slv2str(std_logic_vector(act)) & " /= " & slv2str(exp));
    end if;
  end procedure;

  procedure tc_check_nw(act : signed; exp : std_logic_vector; msg : string := "Check failed") is
  begin
    if not stl_match(std_logic_vector(act), exp) then
      tc_fail_nw(msg & ": " & slv2str(std_logic_vector(act)) & " /= " & slv2str(exp));
    end if;
  end procedure;

  procedure tc_check_nw(act : std_logic_vector; exp : integer; msg : string := "Check failed") is
  begin
    if to_integer(unsigned(act)) /= exp then
      tc_fail_nw(msg & ": " & integer'image(to_integer(unsigned(act))) & " /= " & integer'image(exp));
    end if;
  end procedure;

  procedure tc_check_nw(act : unsigned; exp : integer; msg : string := "Check failed") is
  begin
    if to_integer(act) /= exp then
      tc_fail_nw(msg & ": " & integer'image(to_integer(act)) & " /= " & integer'image(exp));
    end if;
  end procedure;

  procedure tc_check_nw(act : signed; exp : integer; msg : string := "Check failed") is
  begin
    if to_integer(act) /= exp then
      tc_fail_nw(msg & ": " & integer'image(to_integer(act)) & " /= " & integer'image(exp));
    end if;
  end procedure;

  procedure tc_check_nw(act : integer; exp : integer; msg : string := "Check failed") is
  begin
    if act /= exp then
      tc_fail_nw(msg & ": " & integer'image(act) & " /= " & integer'image(exp));
    end if;
  end procedure;

  procedure tc_check_nw(act : real; exp : real; msg : string := "Check failed") is
  begin
    if act /= exp then
      tc_fail_nw(msg & ": " & real'image(act) & " /= " & real'image(exp));
    end if;
  end procedure;

  procedure tc_check_nw(act : time; exp : time; msg : string := "Check failed") is
  begin
    if act /= exp then
      tc_fail_nw(msg & ": " & time'image(act) & " /= " & time'image(exp));
    end if;
  end procedure;

  procedure tc_check_nw(act : std_logic_vector; exp : integer; tol : integer; msg : string := "Check failed") is
  begin
    tc_check_nw(to_integer(unsigned(act)), exp, tol, msg);
  end procedure;

  procedure tc_check_nw(act : unsigned; exp : integer; tol : integer; msg : string := "Check failed") is
  begin
    tc_check_nw(to_integer(act), exp, tol, msg);
  end procedure;

  procedure tc_check_nw(act : signed; exp : integer; tol : integer; msg : string := "Check failed") is
  begin
    tc_check_nw(to_integer(act), exp, tol, msg);
  end procedure;

  procedure tc_check_nw(act : integer; exp : integer; tol : integer; msg : string := "Check failed") is
    variable err  : integer;
  begin
    err := act - exp;
    if err < 0 then
      err := -err;
    end if;
    if err > tol then
      tc_fail_nw(msg & ": " & integer'image(act) & " /= " & integer'image(exp) & " +/- " & integer'image(tol));
    end if;
  end procedure;

  procedure tc_check_nw(act : real; exp : real; tol : real; msg : string := "Check failed") is
    variable err  : real;
  begin
    err := act - exp;
    if err < 0.0 then
      err := -err;
    end if;
    if err > tol then
      tc_fail_nw(msg & ": " & real'image(act) & " /= " & real'image(exp) & " +/- " & real'image(tol));
    end if;
  end procedure;

  procedure tc_check_nw(act : time; exp : time; tol : time; msg : string := "Check failed") is
    variable err  : time;
  begin
    err := act - exp;
    if err < 0 ns then
      err := -err;
    end if;
    if err > tol then
      tc_fail_nw(msg & ": " & time'image(act) & " /= " & time'image(exp) & " +/- " & time'image(tol));
    end if;
  end procedure;

  -- These procedures can be used to print warning messages. They are
  -- suppressed when no test case is running, and are also automatically
  -- suppressed when there are more than 10 warnings with the exact same
  -- name (per test case). name and msg are printed concatenated to each
  -- other, but only name is used for the duplicate check.
  procedure tc_warn(name : string; msg : string := "") is
  begin
    tc_reg.warn(name, msg);
  end procedure;

  procedure tc_warn(cond : boolean; name : string; msg : string := "") is
  begin
    if not cond then
      tc_reg.warn(name, msg);
    end if;
  end procedure;

  -- These procedures can be used to print notes. . They are suppressed when
  -- no test case is running, but are not automatically supressed when they
  -- occur too often.
  procedure tc_note(msg : string) is
  begin
    tc_reg.no_te(msg);
  end procedure;

  -- Waits for the specified amount of time if it is within the bounds of what
  -- the subtest is limited to, or fails the subtest (unless pass is called
  -- from another process first) and waits forever.
  procedure tc_wait_for(del : time) is
  begin
    wait for tc_clamp_delay(del);
    tc_check_timeout;
  end procedure;

  -- Waits for a signal event. If the subtest deadline is reached first, the
  -- test fails and this waits forever.
  procedure tc_wait_on(signal s : in std_logic) is
  begin
    if tc_has_deadline then
      wait until s'event for tc_max_delay;
      tc_check_timeout;
    else
      wait until s'event;
    end if;
  end procedure;

  procedure tc_wait_on(signal s : in std_logic_vector) is
  begin
    if tc_has_deadline then
      wait until s'event for tc_max_delay;
      tc_check_timeout;
    else
      wait until s'event;
    end if;
  end procedure;

  procedure tc_wait_on(signal s : in signed) is
  begin
    if tc_has_deadline then
      wait until s'event for tc_max_delay;
      tc_check_timeout;
    else
      wait until s'event;
    end if;
  end procedure;

  procedure tc_wait_on(signal s : in unsigned) is
  begin
    if tc_has_deadline then
      wait until s'event for tc_max_delay;
      tc_check_timeout;
    else
      wait until s'event;
    end if;
  end procedure;

  -- Same as above, but with a timeout. Returns when either the signal changes
  -- or the time expires, fails the subtest and waits forever if the subtest
  -- timeout expires.
  procedure tc_wait_on(signal s : in std_logic; timeout : time) is
    variable exp : boolean;
  begin
    tc_wait_on(s, timeout, exp);
  end procedure;

  procedure tc_wait_on(signal s : in std_logic_vector; timeout : time) is
    variable exp : boolean;
  begin
    tc_wait_on(s, timeout, exp);
  end procedure;

  procedure tc_wait_on(signal s : in signed; timeout : time) is
    variable exp : boolean;
  begin
    tc_wait_on(s, timeout, exp);
  end procedure;

  procedure tc_wait_on(signal s : in unsigned; timeout : time) is
    variable exp : boolean;
  begin
    tc_wait_on(s, timeout, exp);
  end procedure;

  -- Same as above, also returns whether the timeout exired (exp = true) or
  -- the signal changed (exp = false).
  procedure tc_wait_on(signal s : in std_logic; timeout : time; expired : out boolean) is
    variable start : time;
  begin
    start := now;
    wait until s'event for tc_clamp_delay(timeout);
    tc_check_timeout;
    if start + timeout > now then
      expired := false;
    else
      expired := true;
    end if;
  end procedure;

  procedure tc_wait_on(signal s : in std_logic_vector; timeout : time; expired : out boolean) is
    variable start : time;
  begin
    start := now;
    wait until s'event for tc_clamp_delay(timeout);
    tc_check_timeout;
    if start + timeout > now then
      expired := false;
    else
      expired := true;
    end if;
  end procedure;

  procedure tc_wait_on(signal s : in signed; timeout : time; expired : out boolean) is
    variable start : time;
  begin
    start := now;
    wait until s'event for tc_clamp_delay(timeout);
    tc_check_timeout;
    if start + timeout > now then
      expired := false;
    else
      expired := true;
    end if;
  end procedure;

  procedure tc_wait_on(signal s : in unsigned; timeout : time; expired : out boolean) is
    variable start : time;
  begin
    start := now;
    wait until s'event for tc_clamp_delay(timeout);
    tc_check_timeout;
    if start + timeout > now then
      expired := false;
    else
      expired := true;
    end if;
  end procedure;

  -- Returns whether the current subtest has a deadline.
  impure function tc_has_deadline return boolean is
  begin
    return tc_reg.has_deadline;
  end function;

  -- Returns the maximum delay that we are allowed to wait for before the
  -- subtest deadline expires. Used for "wait until" statements without time
  -- limit.
  impure function tc_max_delay return time is
  begin
    return tc_reg.max_delay;
  end function;

  -- Clamps the given delay to the maximum delay that this subtest is still
  -- allowed to run for. After delaying by this long, call check_timeout.
  impure function tc_clamp_delay(del : time) return time is
  begin
    return tc_reg.clamp_delay(del);
  end function;

  -- Checks whether the subtest timeout has passed. If it has, waits forever.
  procedure tc_check_timeout is
  begin
    if tc_reg.check_timeout then
      wait;
    end if;
  end procedure;

  -- Returns whether models such as clock generators should be resetting
  -- right now. They need to check this function at least every microsecond.
  impure function tc_resetting return boolean is
  begin
    return tc_reg.resetting;
  end function;

  -- Returns whether models such as clock generators should stop generating
  -- events.
  impure function tc_complete return boolean is
  begin
    return tc_reg.complete;
  end function;

  -- Waits forever if the test case is complete.
  procedure tc_yield is
  begin
    if tc_reg.complete then
      wait;
    end if;
  end procedure;

  -- Call before registering a model with SimComms for eye candy.
  procedure tc_model_registered(typ : string; name : string) is
  begin
    wait for 600 ns;
    println("Found " & typ & " " & name);
  end procedure;

  -- String hash function to generate a random seed from a model name.
  function tc_random_seed(name : string) return positive is
    variable seed : positive;
  begin
    seed := 5381;
    for i in name'range loop
      seed := ((seed * 33) mod 65535) + 1 + character'pos(name(i));
    end loop;
    return seed;
  end function;

end package body TestCase_pkg;
