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

-- This package provides a means for universal inter-process communication
-- through (global) shared variables.

package SimDataComms_pkg is

  -- Types supported by SimComms; that is, these primitive data types can be
  -- transferred, everything else must be serialized to a string.
  type variant_enum is (
    SCV_NULL, -- No data.
    SCV_SENT, -- The first entry in a dictionary list, serving as a sentinel
              -- to prevent empty dictionaries. Does not contain data.
    SCV_DICT, -- Dictionary type.
    SCV_STR,  -- Leaf node with raw string data.
    SCV_SLV,  -- Leaf node with std_logic_vector data encoded as a string.
    SCV_STD,  -- Leaf node with std_logic data encoded as a string.
    SCV_BOOL, -- Leaf node with boolean data encoded as a string.
    SCV_INT,  -- Leaf node with integer data encoded as a string.
    SCV_TIME  -- Leaf node with time data encoded as a string.
  );

  -- This object implements arbitrary communication through a shared variable.
  -- Conceptually, the contained data is encapsulated in the form of
  -- dictionaries and queues of a number of VHDL data types. Data is indexed
  -- using key strings, using . as a hierarchy separator; each entry in the
  -- key string indexes the next dictionary. 
  type sc_data_type is protected

    -- Data setters. key is a period-separated hierarchical name. If no data
    -- exists yet for the specified key, it is created. If the key maps to a
    -- queue, the data is written to the tail of the queue.
    procedure       set_str (key: string; data: string);
    procedure       set_slv (key: string; data: std_logic_vector);
    procedure       set_uns (key: string; data: unsigned);
    procedure       set_sgn (key: string; data: signed);
    procedure       set_std (key: string; data: std_logic);
    procedure       set_bool(key: string; data: boolean);
    procedure       set_int (key: string; data: integer);
    procedure       set_time(key: string; data: time);

    -- Data getters. key is a period-separated hierarchical name. If no data
    -- exists yet for the specified key or the type is wrong, simulation is
    -- halted with an error message. If the key maps to a queue, the data is
    -- read from the head of the queue.
    impure function get_str (key: string) return string;
    impure function get_slv (key: string) return std_logic_vector;
    impure function get_uns (key: string) return unsigned;
    impure function get_sgn (key: string) return signed;
    impure function get_std (key: string) return std_logic;
    impure function get_bool(key: string) return boolean;
    impure function get_int (key: string) return integer;
    impure function get_time(key: string) return time;

    -- Same as above, with one exception: If no data exists for the given key,
    -- the default is returned instead of simulation halting.
    impure function get_str (key: string; def: string)           return string;
    impure function get_slv (key: string; def: std_logic_vector) return std_logic_vector;
    impure function get_uns (key: string; def: unsigned)         return unsigned;
    impure function get_sgn (key: string; def: signed)           return signed;
    impure function get_std (key: string; def: std_logic)        return std_logic;
    impure function get_bool(key: string; def: boolean)          return boolean;
    impure function get_int (key: string; def: integer)          return integer;
    impure function get_time(key: string; def: time)             return time;

    -- Type getter. Returns the type of the given key, or SCV_NULL if it does
    -- not exist.
    impure function get_type(key: string) return variant_enum;
    impure function exists  (key: string) return boolean;

    -- Deletes a mapping. Traverses by moving to the head of queues (like
    -- getters). No-op when a key does not exist.
    procedure       delete  (key: string);

    -- Copies data from one key to another. This can essentially be used to set
    -- entire mappings at once. Destination key traversal works like setters,
    -- source key traversal works like getters.
    procedure       copy    (src: string; dest: string);

    -- Returns whether the specified key is associated with more than one data
    -- entry, making it a queue. Traverses by moving to the head of queues
    -- (like getters).
    impure function is_queue(key: string) return boolean;

    -- Pushes/pops data to/from a queue. When traversing the hierarchy, push
    -- moves to the tail of parent queues (like setters) and pop moves to the
    -- head (like getters). fwd combines a pop and a push by pushing the popped
    -- entry to a different queue instead of deallocating it. pop with a second
    -- key is like fwd, but copies the popped entry to dest without pushing
    -- (allowing data to be added to it before the push).
    procedure       push    (key: string);
    procedure       pop     (key: string);
    procedure       pop     (src: string; dest: string);
    procedure       fwd     (src: string; dest: string);

    -- Dump the contents of the simcomms object to stdout for debugging.
    procedure       dump;

    -- Frees all dynamically allocated memory, checking for memory leaks.
    procedure       reset;

  end protected sc_data_type;

end package SimDataComms_pkg;

package body SimDataComms_pkg is

  -- String pointer type.
  type string_ptr is access string;

  -- Variant type. Variants form the basis of the communication system. They
  -- are basically multi-dimensional linked lists; whenever additional data
  -- is needed somewhere (like a new queue entry, or a new bit of data
  -- associated with a dictionary) it is newly allocated and appended to one
  -- of the linked lists.
  type variant_type;
  type variant_ptr is access variant_type;
  type variant_type is record

    -- Link to next dictionary entry, or null if end of list.
    link    : variant_ptr;

    -- Link to previous dictionary entry, or the dictionary definition if
    -- start of list.
    rlink   : variant_ptr;

    -- Dictionary entry name.
    name    : string_ptr;

    -- Type information for this entry.
    typ     : variant_enum;

    -- Leaf data when typ is SCV_DICT.
    dict    : variant_ptr;

    -- Leaf data when typ is SCV_STR or SCV_SLV.
    str     : string_ptr;

    -- Leaf data when typ is SCV_STD, SCV_BOOL, or SCV_INT.
    int     : integer;

    -- Leaf data when typ is SCV_TIME.
    tim     : time;

    -- Next queue entry. link, rlink, and name are invalid for queue entries,
    -- only the values are used. Data setters should iterate to the end of the
    -- queue before writing; data getters should not do that. Push and pop
    -- add/remove queue entries.
    queue   : variant_ptr;

  end record;

  -- This object implements arbitrary communication through a shared variable.
  -- Conceptually, the contained data is encapsulated in the form of
  -- dictionaries and queues of a number of VHDL data types. Data is indexed
  -- using key strings, using . as a hierarchy separator; each entry in the
  -- key string indexes the next dictionary. 
  type sc_data_type is protected body

    --#########################################################################
    -- Private entries.
    --#########################################################################
    -- Root node. This always has the SCV_DICT type when initialized.
    variable root : variant_ptr := null;

    -- Allocation counters for debugging. These are incremented on allocation
    -- and decremented on deallocation to allow memory leak checks to be
    -- performed.
    variable allocs_variant : integer := 0;
    variable allocs_string  : integer := 0;

    -- Forward declaration for clearing/deallocating entries.
    procedure clear_leaf(ent: inout variant_ptr);
    procedure clear_data(ent: inout variant_ptr);
    procedure clear_entry(ent: inout variant_ptr);

    -- Traverses into the hierarchy by exactly one level, using ent as the
    -- starting point and output. ent is the dictionary definition; so
    -- ent.all.dict is the first entry (if there is one). If set is true, the
    -- key is created if it does not exist yet, and queues are traversed before
    -- entering the next dictionary. If set is false, ent will be null if the
    -- key does not exist yet.
    procedure traverse_single(keypart: string; set: boolean; ent: inout variant_ptr) is
    begin

      -- Check input.
      tc_check_nw(ent /= null, "Traversing into null variant");
      tc_check_nw(ent.all.typ = SCV_SENT, "Traversing into non-dict variant");

      -- Loop through the linkedlist representing the dictionary. We start at
      -- the sentinel entry, so the first thing we should do is move to the
      -- next entry (if there is one).
      loop
        if ent.all.link /= null then

          -- Go to the next entry.
          ent := ent.all.link;

          -- Check if this is the entry we're looking for.
          tc_check_nw(ent.all.name /= null, "Variant has null name");
          exit when ent.all.name.all = keypart;

        else

          -- We're at the end of the linkedlist, so the requested entry doesn't
          -- exist.
          if set then

            -- We're setting; create the new entry.
            ent.all.link := new variant_type'(
              link  => null,
              rlink => ent,
              name  => new string'(keypart),
              typ   => SCV_NULL,
              dict  => null,
              str   => null,
              int   => 0,
              tim   => 0 ns,
              queue => null
            );
            allocs_variant := allocs_variant + 1;
            allocs_string := allocs_string + 1;
            ent := ent.all.link;
            exit;

          else

            -- We're getting; return null.
            ent := null;
            return;

          end if;
        end if;
      end loop;

      -- Self-test: the current entry must always have the requested name.
      tc_check_nw(ent.all.name.all = keypart, "Variant has null name");

      -- ent now points to the entry we're looking for. But if we're setting,
      -- we also need to traverse into the queue to get to the tail.
      while set and ent.all.queue /= null loop
        ent := ent.all.queue;
      end loop;

    end procedure;

    -- Like traverse, but handles the full key string.
    procedure traverse(key: string; set: boolean; result: out variant_ptr) is
      variable ent    : variant_ptr;
      variable first  : natural;
      variable last   : natural;
    begin

      -- Initialize ourselves if we haven't yet.
      if root = null then
        root := new variant_type'(
          link  => null,
          rlink => null,
          name  => new string'("*"),
          typ   => SCV_DICT,
          dict  => new variant_type'(
            link  => null,
            rlink => null,
            name  => null,
            typ   => SCV_SENT,
            dict  => null,
            str   => null,
            int   => 0,
            tim   => 0 ns,
            queue => null
          ),
          str   => null,
          int   => 0,
          tim   => 0 ns,
          queue => null
        );
        allocs_variant := allocs_variant + 2;
        allocs_string := allocs_string + 1;
      end if;

      -- Start traversal at the sentinel of the root dictionary.
      ent := root.all.dict;

      first := key'low;
      last  := key'low;
      while first <= key'high loop

        -- Move the last character pointer until last+1 is a period or lies
        -- beyond the string.
        loop
          exit when last = key'high;
          exit when key(last+1) = '.';
          last := last + 1;
        end loop;

        -- key(first to last) is now the current section between periods.
        traverse_single(key(first to last), set, ent);

        -- Return immediately if ent is null; this means the key does not
        -- exist. Note that traverse_single should be creating it if set is
        -- true.
        if ent = null then
          result := null;
          return;
        end if;

        -- Move the first/last pointers beyond the period.
        first := last + 2;
        last := last + 2;

        -- If we're not done traversing, the new node should be a dictionary
        -- and we should move into it.
        if first <= key'high then

          -- If the returned entry is not a dictionary, turn it into one.
          if ent.all.typ /= SCV_DICT then
            clear_data(ent);
            ent.all.typ := SCV_DICT;
            ent.all.dict := new variant_type'(
              link  => null,
              rlink => null,
              name  => null,
              typ   => SCV_SENT,
              dict  => null,
              str   => null,
              int   => 0,
              tim   => 0 ns,
              queue => null
            );
            allocs_variant := allocs_variant + 1;
          end if;

          -- Enter the dictionary.
          ent := ent.all.dict;

        end if;

      end loop;

      -- Return the node we found.
      result := ent;

    end procedure;

    -- Deletes leaf data (dict and str) contained by the given entry and resets
    -- its type to SCV_NULL.
    procedure clear_leaf(ent: inout variant_ptr) is
      variable ent2   : variant_ptr;
    begin
      if ent = null then
        return;
      end if;

      -- Delete dict data by removing the first entry until no entries remain.
      -- Then remove the sentinel manually.
      if ent.all.dict /= null then
        while ent.all.dict.all.link /= null loop
          ent2 := ent.all.dict.all.link;
          clear_entry(ent2);
        end loop;
        deallocate(ent.all.dict);
        allocs_variant := allocs_variant - 1;
        ent.all.dict := null;
      end if;

      -- Delete string data.
      if ent.all.str /= null then
        deallocate(ent.all.str);
        allocs_string := allocs_string - 1;
        ent.all.str := null;
      end if;

      -- Clear static entries.
      ent.all.typ := SCV_NULL;
      ent.all.int := 0;
      ent.all.tim := 0 ns;

    end procedure;

    -- Deletes all data (dict, str, and queue) contained by the given entry and
    -- resets its type to SCV_NULL.
    procedure clear_data(ent: inout variant_ptr) is
      variable ent2   : variant_ptr;
    begin
      if ent = null then
        return;
      end if;

      -- Clear leaf data.
      clear_leaf(ent);

      -- Delete queue data recursively.
      if ent.all.queue /= null then
        ent2 := ent.all.queue;
        clear_entry(ent2);
        ent.all.queue := null;
      end if;

    end procedure;

    -- Deletes a variant constituting a map entry (queue entries should NOT be
    -- passed to this!).
    procedure clear_entry(ent: inout variant_ptr) is
    begin
      if ent = null then
        return;
      end if;
      clear_data(ent);
      if ent.all.rlink /= null then
        ent.all.rlink.all.link := ent.all.link;
      end if;
      if ent.all.link /= null then
        ent.all.link.all.rlink := ent.all.rlink;
      end if;
      if ent.all.name /= null then
        deallocate(ent.all.name);
        allocs_string := allocs_string - 1;
      end if;
      deallocate(ent);
      allocs_variant := allocs_variant - 1;
    end procedure;

    procedure dump_str(str: string) is
      variable ln   : std.textio.line;
    begin
      ln := new string'(str);
      writeline(std.textio.output, ln);
      if ln /= null then
        deallocate(ln);
      end if;
    end procedure;

    -- Internal dump function; dumps an entry with a specified amount of
    -- indentation.
    procedure dump_entry(ent: inout variant_ptr; indent: string) is
      variable qent : variant_ptr;
      variable ment : variant_ptr;
    begin
      if ent = null then
        dump_str(indent & "<NULL!>");
        return;
      end if;
      if ent.all.name = null then
        dump_str(indent & " - name: <NULL!>");
      else
        dump_str(indent & " - name: " & ent.all.name.all);
      end if;
      qent := ent;
      while qent /= null loop
        dump_str(indent & "   type: " & variant_enum'image(qent.all.typ));
        case qent.all.typ is
          when SCV_NULL =>
            null;
          when SCV_SENT =>
            null;
          when SCV_DICT =>
            dump_str(indent & "   val:");
            ment := qent.all.dict;
            tc_check_nw(ment /= null, "Empty dict without sentinel");
            tc_check_nw(ment.all.typ = SCV_SENT, "Nonempty dict without sentinel");
            while ment.all.link /= null loop
              if ment.all.link.all.rlink /= ment then
                dump_str(indent & "   ### RLINK INCONSISTENT ###");
              end if;
              ment := ment.all.link;
              dump_entry(ment, indent & "   ");
            end loop;
          when SCV_STR | SCV_SLV =>
            if qent.all.str = null then
              dump_str(indent & "   val: <NULL!>");
            else
              dump_str(indent & "   val: """ & qent.all.str.all & """");
            end if;
          when SCV_STD =>
            dump_str(indent & "   val: " & std_logic'image(std_logic'val(qent.all.int)));
          when SCV_BOOL =>
            dump_str(indent & "   val: " & boolean'image(boolean'val(qent.all.int)));
          when SCV_INT =>
            dump_str(indent & "   val: " & integer'image(qent.all.int));
          when SCV_TIME =>
            dump_str(indent & "   val: " & time'image(qent.all.tim));
        end case;
        qent := qent.all.queue;
        if qent /= null then
          dump_str(indent & "   ~~~~~");
        end if;
      end loop;
    end procedure;


    --#########################################################################
    -- Data setters. key is a period-separated hierarchical name. If no data
    -- exists yet for the specified key, it is created. If the key maps to a
    -- queue, the data is written to the tail of the queue.
    --#########################################################################
    procedure set_str(key: string; data: string) is
      variable ent  : variant_ptr;
    begin
      traverse(key, true, ent);
      clear_data(ent);
      ent.all.typ := SCV_STR;
      ent.all.str := new string'(data);
      allocs_string := allocs_string + 1;
    end procedure;

    procedure set_slv(key: string; data: std_logic_vector) is
      variable ent  : variant_ptr;
      variable str  : string(1 to data'length);
      variable si   : natural;
    begin
      si := 1;
      for i in data'range loop
        case data(i) is
          when 'U' => str(si) := 'U';
          when 'X' => str(si) := 'X';
          when '0' => str(si) := '0';
          when '1' => str(si) := '1';
          when 'Z' => str(si) := 'Z';
          when 'W' => str(si) := 'W';
          when 'L' => str(si) := 'L';
          when 'H' => str(si) := 'H';
          when '-' => str(si) := '-';
        end case;
        si := si + 1;
      end loop;
      traverse(key, true, ent);
      clear_data(ent);
      ent.all.typ := SCV_SLV;
      ent.all.str := new string'(str);
      allocs_string := allocs_string + 1;
    end procedure;

    procedure set_uns(key: string; data: unsigned) is
    begin
      set_slv(key, std_logic_vector(data));
    end procedure;

    procedure set_sgn(key: string; data: signed) is
    begin
      set_slv(key, std_logic_vector(data));
    end procedure;

    procedure set_std(key: string; data: std_logic) is
      variable ent  : variant_ptr;
    begin
      traverse(key, true, ent);
      clear_data(ent);
      ent.all.typ := SCV_STD;
      ent.all.int := std_logic'pos(data);
    end procedure;

    procedure set_bool(key: string; data: boolean) is
      variable ent  : variant_ptr;
    begin
      traverse(key, true, ent);
      clear_data(ent);
      ent.all.typ := SCV_BOOL;
      ent.all.int := boolean'pos(data);
    end procedure;

    procedure set_int(key: string; data: integer) is
      variable ent  : variant_ptr;
    begin
      traverse(key, true, ent);
      clear_data(ent);
      ent.all.typ := SCV_INT;
      ent.all.int := data;
    end procedure;

    procedure set_time(key: string; data: time) is
      variable ent  : variant_ptr;
    begin
      traverse(key, true, ent);
      clear_data(ent);
      ent.all.typ := SCV_TIME;
      ent.all.tim := data;
    end procedure;


    --#########################################################################
    -- Data getters. key is a period-separated hierarchical name. If no data
    -- exists yet for the specified key or the type is wrong, simulation is
    -- halted with an error message. If the key maps to a queue, the data is
    -- read from the head of the queue.
    --#########################################################################
    impure function get_str(key: string) return string is
      variable ent  : variant_ptr;
    begin
      traverse(key, false, ent);
      tc_check_nw(ent /= null, key & " is not defined");
      tc_check_nw(ent.all.typ = SCV_STR, key & " is not a string");
      return ent.all.str.all;
    end function;

    -- Private helper function for get_slv, needed to figure out vector length
    -- at function elaboration time.
    impure function get_slv_str(key: string) return string is
      variable ent  : variant_ptr;
    begin
      traverse(key, false, ent);
      tc_check_nw(ent /= null, key & " is not defined");
      tc_check_nw(ent.all.typ = SCV_SLV, key & " is not an std_logic_vector-like");
      return ent.all.str.all;
    end function;

    impure function get_slv(key: string) return std_logic_vector is
      constant str  : string := get_slv_str(key);
      variable slv  : std_logic_vector(str'length - 1 downto 0);
      variable si   : natural;
    begin
      si := 1;
      for i in slv'range loop
        case str(si) is
          when 'U' => slv(i) := 'U';
          when 'X' => slv(i) := 'X';
          when '0' => slv(i) := '0';
          when '1' => slv(i) := '1';
          when 'Z' => slv(i) := 'Z';
          when 'W' => slv(i) := 'W';
          when 'L' => slv(i) := 'L';
          when 'H' => slv(i) := 'H';
          when '-' => slv(i) := '-';
          when others => tc_fail_nw("Invalid character in std_logic_vector string");
        end case;
        si := si + 1;
      end loop;
      return slv;
    end function;

    impure function get_uns(key: string) return unsigned is
    begin
      return unsigned(get_slv(key));
    end function;

    impure function get_sgn(key: string) return signed is
    begin
      return signed(get_slv(key));
    end function;

    impure function get_std(key: string) return std_logic is
      variable ent  : variant_ptr;
    begin
      traverse(key, false, ent);
      tc_check_nw(ent /= null, key & " is not defined");
      tc_check_nw(ent.all.typ = SCV_STD, key & " is not an std_logic");
      return std_logic'val(ent.all.int);
    end function;

    impure function get_bool(key: string) return boolean is
      variable ent  : variant_ptr;
    begin
      traverse(key, false, ent);
      tc_check_nw(ent /= null, key & " is not defined");
      tc_check_nw(ent.all.typ = SCV_BOOL, key & " is not a boolean");
      return boolean'val(ent.all.int);
    end function;

    impure function get_int(key: string) return integer is
      variable ent  : variant_ptr;
    begin
      traverse(key, false, ent);
      tc_check_nw(ent /= null, key & " is not defined");
      tc_check_nw(ent.all.typ = SCV_INT, key & " is not an integer");
      return ent.all.int;
    end function;

    impure function get_time(key: string) return time is
      variable ent  : variant_ptr;
    begin
      traverse(key, false, ent);
      tc_check_nw(ent /= null, key & " is not defined");
      tc_check_nw(ent.all.typ = SCV_TIME, key & " is not a time");
      return ent.all.tim;
    end function;


    --#########################################################################
    -- Same as above, with one exception: If no data exists for the given key,
    -- the default is returned instead of simulation halting.
    --#########################################################################
    impure function get_str(key: string; def: string) return string is
      variable ent  : variant_ptr;
    begin
      traverse(key, false, ent);
      if ent = null then
        return def;
      end if;
      tc_check_nw(ent.all.typ = SCV_STR, key & " is not a string");
      return ent.all.str.all;
    end function;

    -- Private helper function for get_slv, needed to figure out vector length
    -- at function elaboration time.
    impure function get_slv_str(key: string; def: string) return string is
      variable ent  : variant_ptr;
    begin
      traverse(key, false, ent);
      if ent = null then
        return def;
      end if;
      tc_check_nw(ent.all.typ = SCV_SLV, key & " is not an std_logic_vector-like");
      return ent.all.str.all;
    end function;

    impure function get_slv(key: string; def: std_logic_vector) return std_logic_vector is
      constant str  : string := get_slv_str(key, "null");
      variable slv  : std_logic_vector(str'length - 1 downto 0);
      variable si   : natural;
    begin
      if str = "null" then
        return def;
      end if;
      si := 1;
      for i in slv'range loop
        case str(si) is
          when 'U' => slv(i) := 'U';
          when 'X' => slv(i) := 'X';
          when '0' => slv(i) := '0';
          when '1' => slv(i) := '1';
          when 'Z' => slv(i) := 'Z';
          when 'W' => slv(i) := 'W';
          when 'L' => slv(i) := 'L';
          when 'H' => slv(i) := 'H';
          when '-' => slv(i) := '-';
          when others => tc_fail_nw("Invalid character in std_logic_vector string");
        end case;
        si := si + 1;
      end loop;
      return slv;
    end function;

    impure function get_uns(key: string; def: unsigned) return unsigned is
    begin
      return unsigned(get_slv(key, std_logic_vector(def)));
    end function;

    impure function get_sgn(key: string; def: signed) return signed is
    begin
      return signed(get_slv(key, std_logic_vector(def)));
    end function;

    impure function get_std(key: string; def: std_logic) return std_logic is
      variable ent  : variant_ptr;
    begin
      traverse(key, false, ent);
      if ent = null then
        return def;
      end if;
      tc_check_nw(ent.all.typ = SCV_STD, key & " is not an std_logic");
      return std_logic'val(ent.all.int);
    end function;

    impure function get_bool(key: string; def: boolean) return boolean is
      variable ent  : variant_ptr;
    begin
      traverse(key, false, ent);
      if ent = null then
        return def;
      end if;
      tc_check_nw(ent.all.typ = SCV_BOOL, key & " is not a boolean");
      return boolean'val(ent.all.int);
    end function;

    impure function get_int(key: string; def: integer) return integer is
      variable ent  : variant_ptr;
    begin
      traverse(key, false, ent);
      if ent = null then
        return def;
      end if;
      tc_check_nw(ent.all.typ = SCV_INT, key & " is not an integer");
      return ent.all.int;
    end function;

    impure function get_time(key: string; def: time) return time is
      variable ent  : variant_ptr;
    begin
      traverse(key, false, ent);
      if ent = null then
        return def;
      end if;
      tc_check_nw(ent.all.typ = SCV_TIME, key & " is not a time");
      return ent.all.tim;
    end function;


    --#########################################################################
    -- Type getter. Returns the type of the given key, or SCV_NULL if it does
    -- not exist.
    --#########################################################################
    impure function get_type(key: string) return variant_enum is
      variable ent  : variant_ptr;
    begin
      traverse(key, false, ent);
      if ent = null then
        return SCV_NULL;
      end if;
      return ent.all.typ;
    end function;

    impure function exists(key: string) return boolean is
    begin
      return get_type(key) /= SCV_NULL;
    end function;


    --#########################################################################
    -- Deletes a mapping. Traverses by moving to the head of queues (like
    -- getters). No-op when a key does not exist.
    --#########################################################################
    procedure delete(key: string) is
      variable ent  : variant_ptr;
    begin
      traverse(key, false, ent);
      clear_entry(ent);
    end procedure;


    --#########################################################################
    -- Copies data from one key to another. This can essentially be used to set
    -- entire mappings at once. Destination key traversal works like setters,
    -- source key traversal works like getters.
    --#########################################################################

    -- Internal function used by copy. Deep-copies the contents of sent (source
    -- entry) to dent (destination entry), leaving map entry metadata (link,
    -- rlink, and name intact).
    procedure copy_entry(sent: inout variant_ptr; dent: inout variant_ptr) is
      variable sqent  : variant_ptr;
      variable dqent  : variant_ptr;
      variable sment  : variant_ptr;
      variable dment  : variant_ptr;
    begin

      -- Iterate over queue entries, including the current one.
      sqent := sent;
      dqent := dent;
      while sqent /= null loop

        -- Copy static information.
        dqent.all.typ := sqent.all.typ;
        dqent.all.int := sqent.all.int;
        dqent.all.tim := sqent.all.tim;

        -- Make a copy of the string data if it exists.
        if sqent.all.str /= null then
          dqent.all.str := new string'(sqent.all.str.all);
          allocs_string := allocs_string + 1;
        else
          dqent.all.str := null;
        end if;

        -- Make a copy of the map data if it exists.
        if sqent.all.dict /= null then
          dqent.all.dict := new variant_type'(
            link  => null,
            rlink => null,
            name  => null,
            typ   => SCV_SENT,
            dict  => null,
            str   => null,
            int   => 0,
            tim   => 0 ns,
            queue => null
          );
          allocs_variant := allocs_variant + 1;
          sment := sqent.all.dict;
          dment := dqent.all.dict;
          while sment.all.link /= null loop
            dment.all.link := new variant_type'(
              link  => null,
              rlink => dment,
              name  => null,
              typ   => SCV_NULL,
              dict  => null,
              str   => null,
              int   => 0,
              tim   => 0 ns,
              queue => null
            );
            allocs_variant := allocs_variant + 1;
            dment := dment.all.link;
            sment := sment.all.link;
            if sment.all.name /= null then
              dment.all.name := new string'(sment.all.name.all);
              allocs_string := allocs_string + 1;
            else
              dment.all.name := null;
            end if;
            copy_entry(sment, dment);
          end loop;
        else
          dqent.all.dict := null;
        end if;

        -- Make a copy of the next queue entry if it exists.
        if sqent.all.queue /= null then
          dqent.all.queue := new variant_type'(
            link  => null,
            rlink => null,
            name  => null,
            typ   => SCV_NULL,
            dict  => null,
            str   => null,
            int   => 0,
            tim   => 0 ns,
            queue => null
          );
          allocs_variant := allocs_variant + 1;
        else
          dqent.all.queue := null;
        end if;

        -- Move to the next queue entry.
        sqent := sqent.all.queue;
        dqent := dqent.all.queue;

      end loop;

    end procedure;

    procedure copy(src: string; dest: string) is
      variable sent : variant_ptr;
      variable dent : variant_ptr;
    begin
      traverse(src, false, sent);
      tc_check_nw(sent /= null, src & " is not defined");
      traverse(dest, true, dent);
      clear_data(dent);
      copy_entry(sent, dent);
    end procedure;


    --#########################################################################
    -- Returns whether the specified key is associated with more than one data
    -- entry, making it a queue. Traverses by moving to the head of queues
    -- (like getters).
    --#########################################################################
    impure function is_queue(key: string) return boolean is
      variable ent  : variant_ptr;
    begin
      traverse(key, false, ent);
      if ent = null then
        return false;
      end if;
      return ent.all.queue /= null;
    end function;


    --#########################################################################
    -- Pushes/pops data to/from a queue. When traversing the hierarchy, push
    -- moves to the tail of parent queues(like setters) and pop moves to the
    -- head(like getters).
    --#########################################################################

    -- Private procedure that performs the bulk of the pop operation. ent must
    -- be the head of a non-empty queue. It is detached from the queue, but not
    -- deallocated.
    procedure detach(ent : inout variant_ptr) is
    begin

      --                        name
      --                         ^
      --                         |
      -- .-----------.  link  .-----.  link  ............
      -- | ent.rlink |------->| ent |------->: ent.link :
      -- |           |<-------|     |<-------: (null?)  :
      -- '-----------' rlink  '-----' rlink  ''''''''''''
      --                         |
      --                         | queue
      --                         |    name
      --                         v    .---0
      --                   .-----------.
      --                   | ent.queue |--0
      --                0--|           |
      --                   '-----------'
      --                         |
      --                         | queue
      --                         v
      --                       null?

      ent.all.rlink.all.link := ent.all.queue;
      if ent.all.link /= null then
        ent.all.link.all.rlink := ent.all.queue;
      end if;

      --                        name
      --                         ^
      --                         |
      -- .-----------.        .-----.  link  ............
      -- | ent.rlink |        | ent |------->: ent.link :
      -- |           |<-------|     |        : (null?)  :
      -- '-----------' rlink  '-----'        ''''''''''''
      --        |                |                 |
      --        |                | queue           |
      --        |                |    name         |
      --        |                v    .---0        |
      --        |   link   .-----------.           |
      --        '--------->| ent.queue |--0        |
      --                0--|           |<----------'
      --                   '-----------'   rlink
      --                         |
      --                         | queue
      --                         v
      --                       null?

      ent.all.queue.all.link := ent.all.link;
      ent.all.queue.all.rlink := ent.all.rlink;

      --                        name
      --                         ^
      --                         |
      -- .-----------.        .-----.  link  ............
      -- | ent.rlink |        | ent |------->: ent.link :
      -- |           |<-------|     |        : (null?)  :
      -- '-----------' rlink  '-----'        ''''''''''''
      --      ^ |                |               ^ |
      --      | |                | queue         | |
      --      | |                |    name       | |
      --      | |                v    .---0      | |
      --      | |   link   .-----------.   link  | |
      --      | '--------->| ent.queue |---------' |
      --      '------------|           |<----------'
      --           rlink   '-----------'   rlink
      --                         |
      --                         | queue
      --                         v
      --                       null?

      ent.all.queue.all.name := ent.all.name;
      ent.all.name := null;

      --                         0
      --                         ^
      --                    name |
      -- .-----------.        .-----.  link  ............
      -- | ent.rlink |        | ent |------->: ent.link :
      -- |           |<-------|     |        : (null?)  :
      -- '-----------' rlink  '-----'        ''''''''''''
      --      ^ |                |               ^ |
      --      | |                | queue         | |
      --      | |                |               | |
      --      | |                v    .-->name   | |
      --      | |   link   .-----------.   link  | |
      --      | '--------->| ent.queue |---------' |
      --      '------------|           |<----------'
      --           rlink   '-----------'   rlink
      --                         |
      --                         | queue
      --                         v
      --                       null?

      ent.all.rlink := null;
      ent.all.link := null;
      ent.all.queue := null;
      ent.all.name := null;

      --                         0
      --                         ^
      --                         |
      -- .-----------.        .-----.        ............
      -- | ent.rlink |        | ent |--0     : ent.link :
      -- |           |     0--|     |        : (null?)  :
      -- '-----------'        '-----'        ''''''''''''
      --      ^ |                |               ^ |
      --      | |                0               | |
      --      | |                     name       | |
      --      | |                     .-->name   | |
      --      | |   link   .-----------.   link  | |
      --      | '--------->| ent.queue |---------' |
      --      '------------|           |<----------'
      --           rlink   '-----------'   rlink
      --                         |
      --                         | queue
      --                         v
      --                       null?

    end procedure;

    procedure push(key: string) is
      variable ent  : variant_ptr;
    begin
      traverse(key, true, ent);
      assert ent.all.queue = null
        report "Setter traversal resulted in entry with non-null queue"
        severity failure;
      ent.all.queue := new variant_type'(
        link  => null, -- unused
        rlink => null, -- unused
        name  => null, -- unused
        typ   => SCV_NULL,
        dict  => null,
        str   => null,
        int   => 0,
        tim   => 0 ns,
        queue => null
      );
      allocs_variant := allocs_variant + 1;
    end procedure;

    procedure pop(key: string) is
      variable ent  : variant_ptr;
    begin
      traverse(key, false, ent);
      tc_check_nw(ent /= null, key & " is not defined");
      tc_check_nw(ent.all.rlink /= null, key & " rlink is missing");
      tc_check_nw(ent.all.queue /= null, "pop from empty queue " & key);
      detach(ent);
      clear_entry(ent);
    end procedure;

    -- Private procedure implementing the common part of pop(s,d) and fwd.
    procedure fwd_int(src: string; dest: string; sent: inout variant_ptr; dent: inout variant_ptr) is
    begin

      -- Prepare source.
      traverse(src, false, sent);
      tc_check_nw(sent /= null, src & " is not defined");
      tc_check_nw(sent.all.rlink /= null, src & " rlink is missing");
      tc_check_nw(sent.all.queue /= null, "pop from empty queue " & src);

      -- Prepare destination.
      traverse(dest, true, dent);
      assert dent.all.queue = null
        report "Setter traversal resulted in entry with non-null queue"
        severity failure;

      -- Detach the head of the source queue.
      detach(sent);

      -- Write source to dest.
      clear_data(dent);
      dent.all.typ  := sent.all.typ;
      dent.all.dict := sent.all.dict;
      dent.all.str  := sent.all.str;
      dent.all.int  := sent.all.int;
      dent.all.tim  := sent.all.tim;

    end procedure;

    procedure pop(src: string; dest: string) is
      variable sent : variant_ptr;
      variable dent : variant_ptr;
    begin
      fwd_int(src, dest, sent, dent);

      -- We don't need the source entry anymore, so deallocate it.
      deallocate(sent);
      allocs_variant := allocs_variant - 1;

    end procedure;

    procedure fwd(src: string; dest: string) is
      variable sent : variant_ptr;
      variable dent : variant_ptr;
    begin
      fwd_int(src, dest, sent, dent);

      -- Now we need to push dent and deallocate sent. Kill two birds with one
      -- stone by reusing sent instead of deallocating it and then allocating a
      -- new variant for dent. link, rlink, name, and queue should already be
      -- null after detach().
      dent.all.queue := sent;
      sent.all.typ  := SCV_NULL;
      sent.all.dict := null;
      sent.all.str  := null;
      sent.all.int  := 0;
      sent.all.tim  := 0 ns;

    end procedure;


    --#########################################################################
    -- Dump the contents of the simcomms object to stdout for debugging.
    --#########################################################################
    procedure dump is
    begin
      dump_entry(root, "");
    end procedure;

    --#########################################################################
    -- Frees all dynamically allocated memory, checking for memory leaks.
    --#########################################################################
    procedure reset is
    begin
      if root /= null then
        clear_entry(root);
        root := null;
        assert allocs_string = 0 and allocs_variant = 0
          report "SimComms object leaked " & integer'image(allocs_string) &
          " string(s) and " & integer'image(allocs_variant) & " variant(s)!"
          severity failure;
      end if;
    end procedure;

  end protected body sc_data_type;

end package body SimDataComms_pkg;
