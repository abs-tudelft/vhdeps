# Copyright 2018 Delft University of Technology
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import re
import os
import sys
import functools
import fnmatch

class StyleError(Exception):
    pass

class ResolutionError(Exception):
    pass

@functools.total_ordering
class VhdFile(object):
    """Represents a VHDL file."""

    ENTITY_DEF    = re.compile(r'entity\s+([a-zA-Z][a-zA-Z0-9_]*)\s+is')
    ENTITY_USE    = re.compile(r':\s*entity\s+(([a-zA-Z][a-zA-Z0-9_]*)\.)?([a-zA-Z][a-zA-Z0-9_]*)\s*[(\sport)|(\sgeneric)|;]')
    COMPONENT_DEF = re.compile(r'component\s+([a-zA-Z][a-zA-Z0-9_]*)\s+is')
    COMPONENT_USE = re.compile(r':\s*([a-zA-Z][a-zA-Z0-9_]*)\s*((\sport)|(\sgeneric))')
    PACKAGE_DEF   = re.compile(r'package\s+([a-zA-Z][a-zA-Z0-9_]*)\s+is')
    PACKAGE_USE   = re.compile(r'use\s+([a-zA-Z][a-zA-Z0-9_]*)\.([a-zA-Z][a-zA-Z0-9_]*)')
    TIMEOUT       = re.compile(r'\-\-\s*pragma\s+simulation\s+timeout\s+([0-9]+(?:\.[0-9]*)?\s+[pnum]?s)')

    def __init__(self, fname, lib='work', version=93, strict=False, allow_bb=False):
        """Creates a representation of the definitions and uses of a VHDL file
        for dependency resolution. `fname` should be the path to the VHDL file.
        `lib` can be used to specify a nonstandard VHDL library for the file.
        `version` specifies the VHDL version as a 2- or 4-digit year. `strict`
        can be set to True to enforce certain style rules when parsing.
        `allow_bb` can be set to allow components defined in this file to
        remain black boxes, useful for vendor libraries containing macros and
        primitives."""

        # Make sure the filename is canonical, so the hash and equality
        # functions work as intended.
        fname = os.path.realpath(fname)

        # Initialize and save parameters.
        super().__init__()
        self.fname    = fname
        self.lib      = lib
        self.version  = version
        self.strict   = strict
        self.allow_bb = allow_bb

        # Read and "parse" the file. "Parsing" is limited to stripping comments
        # and pattern matching to keep things simple.
        with open(fname, 'r') as f:
            contents = f.read().lower()
        sim_timeout = [match.group(1) for match in self.TIMEOUT.finditer(contents)]
        contents = ' '.join((line.split('--')[0] for line in contents.split('\n')))
        self.entity_defs = {match.group(1) for match in self.ENTITY_DEF.finditer(contents)}
        self.entity_uses = {(match.group(2), match.group(3)) for match in self.ENTITY_USE.finditer(contents)}
        self.component_defs = {match.group(1) for match in self.COMPONENT_DEF.finditer(contents)}
        self.component_uses = {match.group(1) for match in self.COMPONENT_USE.finditer(contents)}
        self.package_defs = {match.group(1) for match in self.PACKAGE_DEF.finditer(contents)}
        self.package_uses = {(match.group(1), match.group(2)) for match in self.PACKAGE_USE.finditer(contents)}

        # If this file contains a single entity or package, record its name.
        if len(self.entity_defs) + len(self.package_defs) != 1:
            self.unit = None
        elif self.entity_defs:
            self.unit = next(iter(self.entity_defs))
        else:
            self.unit = next(iter(self.package_defs))
        self.is_pkg = bool(self.package_defs)

        # Record "simulation timeout" pragma. This should be specified in test
        # cases to indicate the expected runtime.
        if sim_timeout:
            self.sim_timeout = sim_timeout[0]
        else:
            self.sim_timeout = None

        # Enforce style rules if strict checking is enabled.
        if strict:
            if self.unit is None:
                raise StyleError('%s contains multiple or zero design units' % self.fname)
            if self.is_pkg and not self.unit.endswith('_pkg'):
                raise StyleError('%s contains package without _pkg prefix' % self.fname)
            if os.path.basename(self.fname).lower().split('.')[0] != self.unit.lower():
                raise StyleError('Filename does not match design unit for %s' % self.fname)

    def resolve(self, vhd_list):
        """Using the complete list of VHDL files (which may or may not include
        self), determine this VHDL file's dependencies. The dependencies are
        recorded in `self.before` (files that must be compiled before this
        file) and `self.anywhere` (files that can be compiled at any time, i.e.
        entities that are only used through component declarations). Missing
        dependencies throw a ResolutionError."""
        self.before = set()
        self.anywhere = set()

        # Record which files to look in for component declarations.
        component_decl_vhds = [self]

        # Resolve used packages.
        for lib, pkg in self.package_uses:
            if lib in ['ieee', 'std']:
                continue
            if not lib or lib == 'work':
                lib = self.lib
            for vhd in vhd_list:
                if vhd.lib == lib and pkg in vhd.package_defs:
                    self.before.add(vhd)
                    component_decl_vhds.append(vhd)
                    break
            else:
                raise ResolutionError(
                    'Could not find package %s.%s used in %s (%s)' %
                    (lib, pkg, self.fname, self.lib))

        # Resolve entity instantiations.
        for lib, ent in self.entity_uses:
            if not lib or lib == 'work':
                lib = self.lib
            for vhd in vhd_list:
                if vhd.lib == lib and ent in vhd.entity_defs:
                    self.before.add(vhd)
                    break
            else:
                raise ResolutionError(
                    'Could not find entity %s.%s used in %s (%s)' %
                    (lib, ent, self.fname, self.lib))

        # Resolve component instantiations. We ensure that the component is
        # declared and the entity is defined.
        for comp in self.component_uses:

            # Look for component declaration.
            for vhd in component_decl_vhds:
                if comp in vhd.component_defs:
                    lib = vhd.lib
                    allow_bb = vhd.allow_bb
                    break
            else:
                raise ResolutionError(
                    'Could not find component declaration for %s used in %s (%s) within %s' %
                    (comp, self.fname, self.lib, ', '.join(map(str, component_decl_vhds))))

            # Look for the accompanying entity.
            for vhd in vhd_list:
                if vhd.lib == lib and comp in vhd.entity_defs:
                    self.anywhere.add(vhd)
                    break
            else:
                if not allow_bb:
                    raise ResolutionError(
                        'Black box: could not find entity for component %s from library %s used in %s (%s)' %
                        (comp, lib, self.fname, self.lib))

    def get_timeout(self):
        """Returns the value of the simulation timeout pragma for test cases.
        This reports a warning to stderr and returns '1 ms' if it isn't
        specified."""
        if self.sim_timeout is None:
            print('Warning: no simulation timeout specified for %s.%s, defaulting to 1 ms.' %
                  (self.lib, self.unit), file=sys.stderr)
            print('Specify using "--pragma simulation timeout <VHDL timespec>"', file=sys.stderr)
            self.sim_timeout = '1 ms'
        return self.sim_timeout

    # Allow VhdFile objects to be used within sets and as dictionary keys.
    def __hash__(self):
        return hash(self.fname)

    def __eq__(self, other):
        try:
            return self.fname == other.fname
        except TypeError:
            return False

    def __lt__(self, other):
        try:
            return self.fname < other.fname
        except TypeError:
            return False

    # Debugging stuff.
    def dump(self):
        print('%s (%s):' % (self.fname, self.lib))
        print(' - define:')
        for ent in self.entity_defs:
            print('    * entity %s' % ent)
        for pkg in self.package_defs:
            print('    * package %s' % pkg)
        for comp in self.component_defs:
            print('    * component %s' % comp)
        print()

    def __str__(self):
        return os.path.basename(self.fname)

    __repr__ = __str__


class VhdList(object):
    """Represents a list of all VHDL files available for compilation."""

    def __init__(self, simulation=False, max_version=2008):
        """Constructs a VHDL file list. `simulation` specifies whether we're
        compiling for simulation or synthesis. `version` specifies the maximum
        supported VHDL version of the target."""
        super().__init__()
        self.simulation = simulation
        self.max_version = max_version
        self.files = set()

    def add_dir(self, dirname, recursive=True, **kwargs):
        """Adds a directory to the VHDL file list. `dirname` specifies the root
        directory, `recursive` specifies whether we should recurse into
        subdirectories. `add_file` is called for all `*.vhd` and `*.vhdl` files
        encountered using the specified keyword arguments."""
        for f in os.listdir(dirname):
            fname = os.path.join(dirname, f)
            if os.path.isdir(fname):
                if recursive:
                    self.add_dir(fname, recursive, **kwargs)
            elif f.lower().endswith('.vhd') or f.lower().endswith('.vhdl'):
                self.add_file(fname, **kwargs)

    def add_file(self, fname, lib='work', version=93, strict=False, **kwargs):
        """Adds a file to the VHDL file list. `fname` specifies the file, `lib`
        optionally specifies the library it should be compiled into,
        `version` specifies the file version if `strict` is not set,
        `strict` specifies whether style rules should be enforced (including
        specification of the VHDL version in the filename). Additional keyword
        arguments are passed to the VhdFile constructor. Returns the loaded
        VHDL file or False if the file was rejected due to version limit or
        synthesis/simulation exclusion."""
        if not strict:

            # Load the VHDL file without style checking.
            vhd = VhdFile(fname, lib, version, strict=False, **kwargs)

        else:

            # Determine how and whether to load this VHDL file based on the
            # "modifiers" in the file extension. First parse all the modifiers
            # into a list.
            mods = os.path.basename(fname).split('.')[1:-1]

            # Look for the mandatory VHDL version modifier, defined to be the
            # last modifier in the modifier list that can be parsed as a
            # decimal integer.
            version = None
            for mod in mods:
                try:
                    version = int(mod)
                except ValueError:
                    pass
            if version is None:
                raise StyleError('%s is missing version modifier' % fname)
            if version < 70:
                version += 2000
            elif version < 100:
                version += 1900

            # If the file version exceeds the maximum supported version for
            # the target, ignore it.
            if version > self.max_version:
                return False

            # Check for the simulation/synthesis inclusion modifiers. One or
            # both should always be specified. If only one is specified and
            # we're doing the opposite operation, reject the file.
            if 'i' not in mods and 'y' not in mods:
                raise StyleError('%s is missing simulation/synthesis modifier(s)' % fname)
            if ('i' if self.simulation else 'y') not in mods:
                return False

            # Load the VHDL file with strict style checking.
            vhd = VhdFile(fname, lib, version, strict=True, **kwargs)

        # Add the loaded VHDL file to our list and return it.
        self.files.add(vhd)
        return vhd

    def order(self, require=None):
        """Determines a possible compile order for the files in this list.
        `require` can optionally be set to a list of entities (each optionally
        prefixed with the library name, separated by a period, if a library
        other than "work" is desired) that must be compiled; in this case files
        that are not necessary to compile those will not be included in the
        returned compile order. The order is returned as a list of VhdFiles."""

        # Construct a mapping from libray-name two-tuples to VhdFiles to test
        # for name conflicts and to resolve them later. Also perform dependency
        # resolution for each of the VhdFiles.
        entities = {}
        packages = {}
        for vhd in self.files:
            for ent in vhd.entity_defs:
                if (vhd.lib, ent) in entities:
                    raise ResolutionError(
                        'Entity %s.%s defined in both %s and %s' %
                        (vhd.lib, ent, vhd.fname, entities[(vhd.lib, ent)].fname))
                entities[(vhd.lib, ent)] = vhd
            for pkg in vhd.package_defs:
                if (vhd.lib, pkg) in packages:
                    raise ResolutionError(
                        'Package %s.%s defined in both %s and %s' %
                        (vhd.lib, pkg, vhd.fname, packages[(vhd.lib, pkg)].fname))
                packages[(vhd.lib, pkg)] = vhd
            vhd.resolve(self.files)

        # Find the toplevel.
        if require:
            require_vhds = set()
            for req in require:
                req = req.split('.', maxsplit=1)
                unit = req[-1].lower()
                lib = req[0].lower() if len(req) > 1 else 'work'
                found = False
                for namespec, vhd in entities.items():
                    elib, eunit = namespec
                    if fnmatch.fnmatchcase(elib.lower(), lib) and fnmatch.fnmatchcase(eunit.lower(), unit):
                        require_vhds.add(vhd)
                        found = True
                if not found:
                    print('Warning: %s.%s did not match anything.' % (lib, unit), file=sys.stderr)
        else:
            require_vhds = self.files

        # Find the compile order by assigning a priority to each of the VHDL
        # files. The lowest priority must be compiled last. Within a priority
        # level the order is arbitrary. TODO: the algorithm used to do this has
        # a poor computational complexity and provides no useful data when
        # there is a circular dependency in the input. This can probably be
        # improved a lot.
        order = {}
        pending = set()
        for vhd in require_vhds:
            order[vhd] = 0
            pending.add(vhd)
        counter = 1
        while pending:
            new_pending = set()
            for vhd in pending:
                for before in vhd.before:
                    order[before] = counter
                    new_pending.add(before)
                for anywhere in vhd.anywhere:
                    if anywhere not in order:
                        order[anywhere] = counter
                        new_pending.add(anywhere)
            pending = new_pending
            counter += 1
            if counter > len(entities) + len(packages) + 1:
                raise ResolutionError('There appears to be a circular dependency somewhere...')

        # Store which files are not required by anything else and are thus
        # potential toplevels. This list is sorted by the filenames to be
        # consistent.
        self.top = [vhd for vhd, o in order.items() if o == 0]
        self.top.sort()

        # Determine the compile order by turning the VhdFile->order mapping
        # into a list and then sorting it by priority. The filename of the
        # VHDL files is used to define the sort order within a priority level
        # to make the output consistent.
        order = [(-priority, vhd) for vhd, priority in order.items()]
        order.sort()
        order = [vhd for _, vhd in order]

        return order

    # Debugging stuff.
    def dump(self):
        for vhd in self.files:
            vhd.dump()
