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

entity SimDataComms_tc is
end SimDataComms_tc;

architecture TestCase of SimDataComms_tc is
  shared variable sc : sc_data_type;
begin

  test_basic_proc: process is
  begin
    tc_name("SimDataComms", "tests the functionality of the SimDataComms package.");
    tc_open("basic");
    ---------------------------------------------------------------------------
    tc_note("Testing basic getter/setter/delete functionality");
    ---------------------------------------------------------------------------

    -- All setters, operating on nonexisting keys.
    sc.set_str ("a.str",  "Hello");
    sc.set_slv ("a.slv",  "010101");
    sc.set_uns ("a.uns",  "101010");
    sc.set_sgn ("a.sgn",  "100110");
    sc.set_std ("a.std",  'L');
    sc.set_bool("a.bool", true);
    sc.set_int ("a.int",  42);
    sc.set_time("a.time", 123 ns);

    -- All no-default getters.
    tc_check(sc.get_str ("a.str"),   "Hello",  "get_str mismatch" );
    tc_check(sc.get_slv ("a.slv"),   "010101", "get_slv mismatch" );
    tc_check(sc.get_uns ("a.uns"),   "101010", "get_uns mismatch" );
    tc_check(sc.get_sgn ("a.sgn"),   "100110", "get_sgn mismatch" );
    tc_check(sc.get_std ("a.std"),   'L',      "get_std mismatch" );
    tc_check(sc.get_bool("a.bool"),  true,     "get_bool mismatch");
    tc_check(sc.get_int ("a.int"),   42,       "get_int mismatch" );
    tc_check(sc.get_time("a.time"),  123 ns,   "get_time mismatch");

    -- All setters, operating on existing keys.
    sc.set_str ("a.str",  "World!");
    sc.set_slv ("a.slv",  "1001");
    sc.set_uns ("a.uns",  "0110");
    sc.set_sgn ("a.sgn",  "1111");
    sc.set_std ("a.std",  'H');
    sc.set_bool("a.bool", false);
    sc.set_int ("a.int",  -33);
    sc.set_time("a.time", 345 ns);

    -- All no-default getters again, checking that the previous setters worked
    -- correctly.
    tc_check(sc.get_str ("a.str"),   "World!", "get_str mismatch" );
    tc_check(sc.get_slv ("a.slv"),   "1001",   "get_slv mismatch" );
    tc_check(sc.get_uns ("a.uns"),   "0110",   "get_uns mismatch" );
    tc_check(sc.get_sgn ("a.sgn"),   "1111",   "get_sgn mismatch" );
    tc_check(sc.get_std ("a.std"),   'H',      "get_std mismatch" );
    tc_check(sc.get_bool("a.bool"),  false,    "get_bool mismatch");
    tc_check(sc.get_int ("a.int"),   -33,      "get_int mismatch" );
    tc_check(sc.get_time("a.time"),  345 ns,   "get_time mismatch");

    -- All defaulted getters, operating on existing keys.
    tc_check(sc.get_str ("a.str",  "unknown"),   "World!",  "get_str mismatch" );
    tc_check(sc.get_slv ("a.slv",  "UUUU"),      "1001",    "get_slv mismatch" );
    tc_check(sc.get_uns ("a.uns",  "0000"),      "0110",    "get_uns mismatch" );
    tc_check(sc.get_sgn ("a.sgn",  "0000"),      "1111",    "get_sgn mismatch" );
    tc_check(sc.get_std ("a.std",  'U'),         'H',       "get_std mismatch" );
    tc_check(sc.get_bool("a.bool", true),        false,     "get_bool mismatch");
    tc_check(sc.get_int ("a.int",  0),           -33,       "get_int mismatch" );
    tc_check(sc.get_time("a.time", 20 ns),       345 ns,    "get_time mismatch");

    -- All defaulted getters, operating on non-existing keys.
    tc_check(sc.get_str ("a.str_",  "unknown"),  "unknown", "get_str mismatch" );
    tc_check(sc.get_slv ("a.slv_",  "UUUU"),     "UUUU",    "get_slv mismatch" );
    tc_check(sc.get_uns ("a.uns_",  "0000"),     "0000",    "get_uns mismatch" );
    tc_check(sc.get_sgn ("a.sgn_",  "0000"),     "0000",    "get_sgn mismatch" );
    tc_check(sc.get_std ("a.std_",  'U'),        'U',       "get_std mismatch" );
    tc_check(sc.get_bool("a.bool_", true),       true,      "get_bool mismatch");
    tc_check(sc.get_int ("a.int_",  0),          0,         "get_int mismatch" );
    tc_check(sc.get_time("a.time_", 20 ns),      20 ns,     "get_time mismatch");

    -- Defaulted getter, operating on dictionary.
    tc_check(sc.get_str ("b.str",   "unknown"),  "unknown", "get_str mismatch" );

    -- All possible cases for type getters.
    tc_check(sc.get_type("a.str")  = SCV_STR,  "get_type mismatch");
    tc_check(sc.get_type("a.slv")  = SCV_SLV,  "get_type mismatch");
    tc_check(sc.get_type("a.uns")  = SCV_SLV,  "get_type mismatch");
    tc_check(sc.get_type("a.sgn")  = SCV_SLV,  "get_type mismatch");
    tc_check(sc.get_type("a.std")  = SCV_STD,  "get_type mismatch");
    tc_check(sc.get_type("a.bool") = SCV_BOOL, "get_type mismatch");
    tc_check(sc.get_type("a.int")  = SCV_INT,  "get_type mismatch");
    tc_check(sc.get_type("a.time") = SCV_TIME, "get_type mismatch");
    tc_check(sc.get_type("a")      = SCV_DICT, "get_type mismatch");
    tc_check(sc.get_type("b")      = SCV_NULL, "get_type mismatch");

    -- Deletion of all leaf keys.
    sc.delete("a.str");
    sc.delete("a.slv");
    sc.delete("a.uns");
    sc.delete("a.sgn");
    sc.delete("a.std");
    sc.delete("a.bool");
    sc.delete("a.int");
    sc.delete("a.time");

    -- Checks that the leaves were deleted.
    tc_check(sc.get_str ("a.str",  "unknown"),   "unknown", "get_str mismatch" );
    tc_check(sc.get_slv ("a.slv",  "UUUU"),      "UUUU",    "get_slv mismatch" );
    tc_check(sc.get_uns ("a.uns",  "0000"),      "0000",    "get_uns mismatch" );
    tc_check(sc.get_sgn ("a.sgn",  "0000"),      "0000",    "get_sgn mismatch" );
    tc_check(sc.get_std ("a.std",  'U'),         'U',       "get_std mismatch" );
    tc_check(sc.get_bool("a.bool", true),        true,      "get_bool mismatch");
    tc_check(sc.get_int ("a.int",  0),           0,         "get_int mismatch" );
    tc_check(sc.get_time("a.time", 20 ns),       20 ns,     "get_time mismatch");

    -- Check that the enclosing dict was not deleted.
    tc_check(sc.get_type("a") =                  SCV_DICT,  "get_type mismatch");

    -- Re-populate the dict.
    sc.set_str ("a.str",  "World!");
    sc.set_slv ("a.slv",  "1001");
    sc.set_uns ("a.uns",  "0110");
    sc.set_sgn ("a.sgn",  "1111");
    sc.set_std ("a.std",  'H');
    sc.set_bool("a.bool", false);
    sc.set_int ("a.int",  -33);
    sc.set_time("a.time", 345 ns);

    -- Add a child dict as well.
    sc.set_str ("a.b.str", "Hi!");

    -- Ensure that it was repopulated correctly.
    tc_check(sc.get_str ("a.str",  "unknown"),   "World!",  "get_str mismatch" );
    tc_check(sc.get_slv ("a.slv",  "UUUU"),      "1001",    "get_slv mismatch" );
    tc_check(sc.get_uns ("a.uns",  "0000"),      "0110",    "get_uns mismatch" );
    tc_check(sc.get_sgn ("a.sgn",  "0000"),      "1111",    "get_sgn mismatch" );
    tc_check(sc.get_std ("a.std",  'U'),         'H',       "get_std mismatch" );
    tc_check(sc.get_bool("a.bool", true),        false,     "get_bool mismatch");
    tc_check(sc.get_int ("a.int",  0),           -33,       "get_int mismatch" );
    tc_check(sc.get_time("a.time", 20 ns),       345 ns,    "get_time mismatch");
    tc_check(sc.get_type("a") =                  SCV_DICT,  "get_type mismatch");
    tc_check(sc.get_type("a.b") =                SCV_DICT,  "get_type mismatch");
    tc_check(sc.get_str ("a.b.str", "unknown"),  "Hi!",     "get_str mismatch" );

    -- Deletion of a dict containing all key types.
    sc.delete("a");

    -- Ensure that it was deleted correctly.
    tc_check(sc.get_str ("a.str",  "unknown"),   "unknown", "get_str mismatch" );
    tc_check(sc.get_slv ("a.slv",  "UUUU"),      "UUUU",    "get_slv mismatch" );
    tc_check(sc.get_uns ("a.uns",  "0000"),      "0000",    "get_uns mismatch" );
    tc_check(sc.get_sgn ("a.sgn",  "0000"),      "0000",    "get_sgn mismatch" );
    tc_check(sc.get_std ("a.std",  'U'),         'U',       "get_std mismatch" );
    tc_check(sc.get_bool("a.bool", true),        true,      "get_bool mismatch");
    tc_check(sc.get_int ("a.int",  0),           0,         "get_int mismatch" );
    tc_check(sc.get_time("a.time", 20 ns),       20 ns,     "get_time mismatch");
    tc_check(sc.get_str ("a.b.str", "unknown"),  "unknown", "get_str mismatch" );
    tc_check(sc.get_type("a.b") =                SCV_NULL,  "get_type mismatch");
    tc_check(sc.get_type("a") =                  SCV_NULL,  "get_type mismatch");

    -- Reset the SimComms type; this checks for memory leaks and clears the
    -- contents.
    sc.reset;

    tc_pass;
  end process;

  test_dict_overwrite_proc: process is
    variable l : line;
    variable i : integer;
  begin
    tc_open("dict_overwrite");
    ---------------------------------------------------------------------------
    tc_note("Testing setter/dictionary overriding...");
    ---------------------------------------------------------------------------

    -- Initialize structure.
    sc.set_str("a.b", "test1");
    tc_check(sc.get_str("a.b",   "nope"),  "test1", "get_str mismatch");
    tc_check(sc.get_str("a.b.c", "nope"),  "nope",  "get_str mismatch");

    -- Override string leaf with dict.
    sc.set_str("a.b.c", "test2");
    tc_check(sc.get_str("a.b.c", "nope"),  "test2", "get_str mismatch");

    -- Override dict with string leaf.
    sc.set_str("a.b", "test3");
    tc_check(sc.get_str("a.b",   "nope"),  "test3", "get_str mismatch");
    tc_check(sc.get_str("a.b.c", "nope"),  "nope",  "get_str mismatch");

    -- Reset the SimComms type; this checks for memory leaks and clears the
    -- contents.
    sc.reset;

    tc_pass;
  end process;

  test_copy_proc: process is
    variable l : line;
    variable i : integer;
  begin
    tc_open("copy");
    ---------------------------------------------------------------------------
    tc_note("Testing copy...");
    ---------------------------------------------------------------------------

    -- Populate a dict with stuff.
    sc.set_str ("a.str",   "Hello");
    sc.set_str ("a.b.str", "World!");
    sc.set_slv ("a.slv",   "1001");
    sc.set_std ("a.std",   'H');
    sc.set_bool("a.bool",  false);
    sc.set_int ("a.int",   -33);
    sc.set_time("a.time",  345 ns);

    -- Make a full copy of the dict itself.
    sc.copy("a", "b");

    -- Make a leaf-based copy.
    sc.copy("a.str",   "c.str");
    sc.copy("a.b.str", "c.b.str");
    sc.copy("a.slv",   "c.slv");
    sc.copy("a.std",   "c.std");
    sc.copy("a.bool",  "c.bool");
    sc.copy("a.int",   "c.int");
    sc.copy("a.time",  "c.time");

    -- Override the original entries.
    sc.set_str ("a.str",   "nope");
    sc.set_str ("a.b.str", "nope");
    sc.set_slv ("a.slv",   "UUUU");
    sc.set_std ("a.std",   'X');
    sc.set_bool("a.bool",  true);
    sc.set_int ("a.int",   42);
    sc.set_time("a.time",  123 ns);

    -- Check that the full copy is intact.
    tc_check(sc.get_type("b") =                   SCV_DICT, "get_type mismatch");
    tc_check(sc.get_str ("b.str",   "unknown"),   "Hello",  "get_str mismatch" );
    tc_check(sc.get_type("b.b") =                 SCV_DICT, "get_type mismatch");
    tc_check(sc.get_str ("b.b.str", "unknown"),   "World!", "get_str mismatch" );
    tc_check(sc.get_slv ("b.slv",   "UUUU"),      "1001",   "get_slv mismatch" );
    tc_check(sc.get_std ("b.std",   'U'),         'H',      "get_std mismatch" );
    tc_check(sc.get_bool("b.bool",  true),        false,    "get_bool mismatch");
    tc_check(sc.get_int ("b.int",   0),           -33,      "get_int mismatch" );
    tc_check(sc.get_time("b.time",  20 ns),       345 ns,   "get_time mismatch");

    sc.delete("b");

    -- Check that the leaf copy is intact.
    tc_check(sc.get_type("c") =                   SCV_DICT, "get_type mismatch");
    tc_check(sc.get_str ("c.str",   "unknown"),   "Hello",  "get_str mismatch" );
    tc_check(sc.get_type("c.b") =                 SCV_DICT, "get_type mismatch");
    tc_check(sc.get_str ("c.b.str", "unknown"),   "World!", "get_str mismatch" );
    tc_check(sc.get_slv ("c.slv",   "UUUU"),      "1001",   "get_slv mismatch" );
    tc_check(sc.get_std ("c.std",   'U'),         'H',      "get_std mismatch" );
    tc_check(sc.get_bool("c.bool",  true),        false,    "get_bool mismatch");
    tc_check(sc.get_int ("c.int",   0),           -33,      "get_int mismatch" );
    tc_check(sc.get_time("c.time",  20 ns),       345 ns,   "get_time mismatch");

    -- Reset the SimComms type; this checks for memory leaks and clears the
    -- contents.
    sc.reset;

    tc_pass;
  end process;

  test_basic_queue_proc: process is
    variable l : line;
    variable i : integer;
  begin
    tc_open("basic_queue");
    ---------------------------------------------------------------------------
    tc_note("Testing basic queue functionality...");
    ---------------------------------------------------------------------------

    -- Populate a dict with stuff.
    sc.set_str ("a.str",   "Hello");
    sc.set_str ("a.b.str", "World!");
    sc.set_slv ("a.slv",   "1001");
    sc.set_std ("a.std",   'H');
    sc.set_bool("a.bool",  false);
    sc.set_int ("a.int",   -33);
    sc.set_time("a.time",  345 ns);

    -- Check that none of the above entries register as queues.
    tc_check(not sc.is_queue("a"),       "is_queue mismatch");
    tc_check(not sc.is_queue("a.str"),   "is_queue mismatch");
    tc_check(not sc.is_queue("a.b"),     "is_queue mismatch");
    tc_check(not sc.is_queue("a.b.str"), "is_queue mismatch");
    tc_check(not sc.is_queue("a.slv"),   "is_queue mismatch");
    tc_check(not sc.is_queue("a.std"),   "is_queue mismatch");
    tc_check(not sc.is_queue("a.bool"),  "is_queue mismatch");
    tc_check(not sc.is_queue("a.int"),   "is_queue mismatch");
    tc_check(not sc.is_queue("a.time"),  "is_queue mismatch");

    -- Push all the things.
    sc.push("a.str");
    sc.push("a.b");
    sc.push("a.slv");
    sc.push("a.std");
    sc.push("a.bool");
    sc.push("a.int");
    sc.push("a.time");

    -- Check that the appropriate entries are now queues.
    tc_check(not sc.is_queue("a"),       "is_queue mismatch");
    tc_check(    sc.is_queue("a.str"),   "is_queue mismatch");
    tc_check(    sc.is_queue("a.b"),     "is_queue mismatch");
    tc_check(not sc.is_queue("a.b.str"), "is_queue mismatch");
    tc_check(    sc.is_queue("a.slv"),   "is_queue mismatch");
    tc_check(    sc.is_queue("a.std"),   "is_queue mismatch");
    tc_check(    sc.is_queue("a.bool"),  "is_queue mismatch");
    tc_check(    sc.is_queue("a.int"),   "is_queue mismatch");
    tc_check(    sc.is_queue("a.time"),  "is_queue mismatch");

    -- Add some data to the new queue entries.
    sc.set_str ("a.str",   "World!");
    sc.set_str ("a.b.str", "Hi!");
    sc.set_slv ("a.slv",   "0110");
    sc.set_std ("a.std",   'L');
    sc.set_bool("a.bool",  true);
    sc.set_int ("a.int",   42);
    sc.set_time("a.time",  123 ns);

    -- Check that reading returns the head of the queue.
    tc_check(sc.get_type("a") =                   SCV_DICT, "get_type mismatch");
    tc_check(sc.get_str ("a.str",   "unknown"),   "Hello",  "get_str mismatch" );
    tc_check(sc.get_type("a.b") =                 SCV_DICT, "get_type mismatch");
    tc_check(sc.get_str ("a.b.str", "unknown"),   "World!", "get_str mismatch" );
    tc_check(sc.get_slv ("a.slv",   "UUUU"),      "1001",   "get_slv mismatch" );
    tc_check(sc.get_std ("a.std",   'U'),         'H',      "get_std mismatch" );
    tc_check(sc.get_bool("a.bool",  true),        false,    "get_bool mismatch");
    tc_check(sc.get_int ("a.int",   0),           -33,      "get_int mismatch" );
    tc_check(sc.get_time("a.time",  20 ns),       345 ns,   "get_time mismatch");

    -- Pop all the things.
    sc.pop("a.str");
    sc.pop("a.b");
    sc.pop("a.slv");
    sc.pop("a.std");
    sc.pop("a.bool");
    sc.pop("a.int");
    sc.pop("a.time");

    -- Check that we now see the second set of data.
    tc_check(sc.get_type("a") =                   SCV_DICT, "get_type mismatch");
    tc_check(sc.get_str ("a.str",   "unknown"),   "World!", "get_str mismatch" );
    tc_check(sc.get_type("a.b") =                 SCV_DICT, "get_type mismatch");
    tc_check(sc.get_str ("a.b.str", "unknown"),   "Hi!",    "get_str mismatch" );
    tc_check(sc.get_slv ("a.slv",   "UUUU"),      "0110",   "get_slv mismatch" );
    tc_check(sc.get_std ("a.std",   'U'),         'L',      "get_std mismatch" );
    tc_check(sc.get_bool("a.bool",  false),       true,     "get_bool mismatch");
    tc_check(sc.get_int ("a.int",   0),           42,       "get_int mismatch" );
    tc_check(sc.get_time("a.time",  20 ns),       123 ns,   "get_time mismatch");

    -- Check that none of the above entries register as queues anymore.
    tc_check(not sc.is_queue("a"),       "is_queue mismatch");
    tc_check(not sc.is_queue("a.str"),   "is_queue mismatch");
    tc_check(not sc.is_queue("a.b"),     "is_queue mismatch");
    tc_check(not sc.is_queue("a.b.str"), "is_queue mismatch");
    tc_check(not sc.is_queue("a.slv"),   "is_queue mismatch");
    tc_check(not sc.is_queue("a.std"),   "is_queue mismatch");
    tc_check(not sc.is_queue("a.bool"),  "is_queue mismatch");
    tc_check(not sc.is_queue("a.int"),   "is_queue mismatch");
    tc_check(not sc.is_queue("a.time"),  "is_queue mismatch");

    -- Reset the SimComms type; this checks for memory leaks and clears the
    -- contents.
    sc.reset;

    tc_pass;
  end process;

  test_deep_queue_proc: process is
    variable l : line;
    variable i : integer;
  begin
    tc_open("deep_queue");
    ---------------------------------------------------------------------------
    tc_note("Testing a deeper queue and queue forwarding...");
    ---------------------------------------------------------------------------

    -- Stuff some data in a queue.
    sc.set_str("a.str", "Lorem ");       sc.push("a");
    sc.set_str("a.str", "ipsum ");       sc.push("a");
    sc.set_str("a.str", "dolor ");       sc.push("a");
    sc.set_str("a.str", "sit ");         sc.push("a");
    sc.set_str("a.str", "amet, ");       sc.push("a");
    sc.set_str("a.str", "consectetur "); sc.push("a");
    sc.set_str("a.str", "adipiscing ");  sc.push("a");
    sc.set_str("a.str", "elit.");        sc.push("a");

    -- Forward the queue to another queue while reading it.
    while sc.is_queue("a") loop
      write(l, sc.get_str("a.str"));
      sc.fwd("a", "c");
    end loop;
    tc_check(l.all, "Lorem ipsum dolor sit amet, consectetur adipiscing elit.", "string mismatch: " & l.all);
    deallocate(l);

    -- Do the same using pop(s,d).
    i := 0;
    while sc.is_queue("c") loop
      write(l, sc.get_str("c.str"));
      sc.pop("c", "b");
      sc.set_int("b.int", i);
      sc.push("b");
      i := i + 1;
    end loop;
    tc_check(l.all, "Lorem ipsum dolor sit amet, consectetur adipiscing elit.", "string mismatch: " & l.all);
    deallocate(l);

    -- Copy the forwarded queue.
    sc.copy("b", "a");

    -- Read the original queue.
    i := 0;
    while sc.is_queue("b") loop
      write(l, sc.get_str("b.str"));
      tc_check(sc.get_int("b.int"), i, "int mismatch");
      sc.pop("b");
      i := i + 1;
    end loop;
    tc_check(l.all, "Lorem ipsum dolor sit amet, consectetur adipiscing elit.", "string mismatch: " & l.all);
    deallocate(l);

    -- Read the copy of the queue.
    i := 0;
    while sc.is_queue("a") loop
      write(l, sc.get_str("a.str"));
      tc_check(sc.get_int("a.int"), i, "int mismatch");
      sc.pop("a");
      i := i + 1;
    end loop;
    tc_check(l.all, "Lorem ipsum dolor sit amet, consectetur adipiscing elit.", "string mismatch: " & l.all);
    deallocate(l);

    -- Reset the SimComms type; this checks for memory leaks and clears the
    -- contents.
    sc.reset;

    tc_pass;
  end process;

end TestCase;
