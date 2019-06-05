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
import re
from collections import deque

class StyleError(Exception):
    pass

class ResolutionError(Exception):
    pass

def parse_version(version):
    """Parses a VHDL version string or int, 2- or 4-digit style, to a full
    4-digit version identifier integer."""
    if version is None:
        return None
    version = int(version)
    if version < 70:
        version += 2000
    elif version < 100:
        version += 1900
    return version

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

    def __init__(self, fname, lib='work', override_version=None, desired_version=2008, strict=False, allow_bb=False):
        """Creates a representation of the definitions and uses of a VHDL file
        for dependency resolution. `fname` should be the path to the VHDL file.
        `lib` can be used to specify a nonstandard VHDL library for the file.
        `versions` specifies an iterable of VHDL versions this file is designed
        for as a 2- or 4-digit year. `strict` can be set to True to enforce
        certain style rules when parsing. `allow_bb` can be set to allow
        components defined in this file to remain black boxes, useful for
        vendor libraries containing macros and primitives."""

        # Make sure the filename is canonical, so the hash and equality
        # functions work as intended.
        fname = os.path.realpath(fname)

        # Initialize and save parameters.
        super().__init__()
        self.fname    = fname
        self.lib      = lib
        self.strict   = strict
        self.allow_bb = allow_bb

        # Determine the VHDL versions this file is supposed to be compatible
        # with.
        if override_version is not None:
            versions = (override_version,)
        else:
            versions = map(lambda x: x.group(1), re.finditer(r'\.(19[7-9]\d|20[0-6]\d|\d\d)(?=\.)', fname))
        self.versions = set(map(parse_version, versions))

        # Determine the version that we'll be compiling the file with if we
        # need to.
        self.version = min(self.versions, key=lambda v: abs(v - desired_version), default=desired_version)

        # Determine whether this file is simulation- or synthesis-only.
        self.use_for_synthesis = '.sim.' not in fname
        self.use_for_simulation = '.syn.' not in fname

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

    def resolve_dependencies(self, resolver, ignore_libs={'ieee', 'std'}):
        """Using a function that resolves a VHDL design unit identification
        triplet to a `VhdFile` object, record this file's dependencies in
        `self.before` (files that must be compiled before this file) and
        `self.anywhere` (files that can be compiled at any time, i.e.
        entities that are only used through component declarations). Any use of
        design units from libraries contained in `ignore_libs` are ignored and
        not resolved through `resolver()`. `resolver()` must take the design
        unit type (`'entity'` or `'package'`), the library name, the design
        unit name, and a boolean as argument; the boolean indicates whether the
        dependency is strong (`True`), that is, that the dependent file must be
        compiled before this file. Weak dependencies (`False`) can be compiled
        at any time during the compilation process."""

        self.before = set()
        self.anywhere = set()

        # Record which files to look in for component declarations.
        component_decl_vhds = [self]

        # Figure out which files need to be compiled before this one.
        for unit_type in ('package', 'entity'):
            for lib, name in getattr(self, unit_type + '_uses'):
                if lib in ignore_libs:
                    continue
                if not lib or lib == 'work':
                    lib = self.lib
                try:
                    vhd = resolver(unit_type, lib, name, True)
                except ResolutionError as e:
                    raise ResolutionError(
                        'while resolving %s %s.%s in %s:\n%s' %
                        (unit_type, lib, name, self, e))
                self.before.add(vhd)
                if unit_type == 'package':
                    component_decl_vhds.append(vhd)

        # Resolve component instantiations. We ensure that the component is
        # declared and the entity is defined.
        for comp in self.component_uses:
            try:

                # Look for component declaration.
                for vhd in component_decl_vhds:
                    if comp in vhd.component_defs:
                        lib = vhd.lib
                        allow_bb = vhd.allow_bb
                        break
                else:
                    raise ResolutionError(
                        'could not find component declaration for %s within %s' %
                        (comp, ', '.join(map(str, component_decl_vhds))))

                # Look for the accompanying entity.
                try:
                    self.anywhere.add(resolver('entity', lib, comp, False))
                except ResolutionError as e:
                    raise ResolutionError('black box: %s' % e)

            except ResolutionError as e:
                raise ResolutionError(
                    'while resolving component %s in %s:\n%s' %
                    (comp, self, e))

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

    def __init__(self, mode='sim', desired_version=None, required_version=None):
        """Constructs a VHDL file list. `simulation` specifies whether we're
        compiling for simulation or synthesis. `version` specifies the maximum
        supported VHDL version of the target."""
        super().__init__()
        self.mode = mode
        self.required_version = parse_version(required_version)
        if self.required_version is None:
            if desired_version is None:
                desired_version = 2008
            self.desired_version = parse_version(desired_version)
        else:
            self.desired_version = self.required_version
        self.files = set()
        self.design_units = {}
        self.order = deque()

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

    def add_file(self, *args, **kwargs):
        """Adds a file to the VHDL file list. All arguments are passed directly
        to `VhdFile`'s constructor."""
        kwargs['desired_version'] = self.desired_version
        vhd = VhdFile(*args, **kwargs)
        self.files.add(vhd)
        return vhd

    def move_to_front(self, vhd, stack=()):
        """Moves the specified `VhdFile` object to the front of the compile
        order, taking its dependencies along with it. The file must already
        have been compiled and must already have had its dependencies
        resolved.."""
        if vhd in stack:
            raise ResolutionError('circular dependency:\n - ' + '\n - '.join(stack))
        self.order.remove(vhd)
        self.order.appendleft(vhd)
        stack += (vhd,)
        for vhd_dep in sorted(vhd.before, key=str):
            self.move_to_front(vhd_dep, stack)

    def is_file_filtered_out(self, vhd):
        """Returns a non-empty string when the given `VhdFile` is filtered out
        by this list's configuration with the reason for it being filtered out,
        or `None` if the file is matches all filters."""
        if self.mode == 'sim' and not vhd.use_for_simulation:
            return '%s is synthesis-only' % vhd
        elif self.mode == 'syn' and not vhd.use_for_synthesis:
            return '%s is simulation-only' % vhd
        elif self.required_version is not None and vhd.versions and not self.required_version in vhd.versions:
            return '%s is not compatible with VHDL %s' % (vhd, self.required_version)
        else:
            return None

    def resolve_design_unit(self, unit_type, lib, name, strong_dependency):
        """Resolves the requested design unit to a file. Adds the file to
        the compilation list and resolves its dependencies recusively if the
        file is not in the list yet. If `strong_dependency` is set, the file
        is moved to the front of the compilation list in either case, followed
        by the files it depends strongly upon being moved to the front
        recursively. The design unit is identified by `unit_type`, which must
        be `'entity'` or `'package'`, and its library and VHDL identifier.
        The matching `VhdFile` is returned if the resolution succeeds. A
        `ResolutionError` is raised otherwise."""

        # Construct identification tuple for this design unit.
        ident = (unit_type, lib, name)

        # If we've resolved this unit before, make sure we use the same file.
        vhd = self.design_units.get(ident, None)
        if vhd is None:

            # Find all design units of type unit_type that comply with the
            # specified requirements.
            options = []
            filtered_out = []
            for vhd in self.files:
                if vhd.lib == lib and name in getattr(vhd, unit_type + '_defs'):
                    x = self.is_file_filtered_out(vhd)
                    if x:
                        filtered_out.append(x)
                    else:
                        options.append(vhd)

            # If we didn't find anything compliant, throw an error.
            if not options:
                if filtered_out:
                    raise ResolutionError(
                        '%s %s.%s is defined, but only in files that were filtered out: %s' %
                        (unit_type, lib, name, ', '.join(filtered_out)))
                else:
                    raise ResolutionError(
                        'could not find %s %s.%s' %
                        (unit_type, lib, name))

            # We may end up with multiple options depending on, for instance,
            # VHDL version. The user specifies a desired VHDL version to
            # disambiguate this a little. First, find the supported version
            # that most closely matches the desired version.
            version_options = set()
            for vhd in options:
                if not vhd.versions:
                    # Universal file.
                    version_options = {self.desired_version}
                    break
                version_options.update(vhd.versions)
            best_version = min(version_options, key=lambda v: abs(v - self.desired_version))

            # Now filter out any file that doesn't support the best version
            # we found.
            options = list(filter(lambda vhd: best_version in vhd.versions or not vhd.versions, options))

            # If we still have more than one option, let the user figure it
            # out.
            if len(options) > 1:
                raise ResolutionError(
                    '%s %s.%s is defined in multiple, ambiguous files:\n - %s' %
                    (unit_type, lib, name, '\n - '.join(map(str, options))))

            vhd = options[0]

            # Store the design unit mapping.
            self.design_units[ident] = vhd

            # Resolve the file if it hasn't been resolved yet.
            if vhd not in self.order:
                self.order.appendleft(vhd)
                vhd.resolve_dependencies(self.resolve_design_unit)

                # This file and its dependencies are already at the front of
                # the compile order, so we don't need to move it to the front
                # again even if there was a strong dependency.
                return vhd

        # Move the file to the front of the compile order list if the file
        # whose dependencies were being resolved by the caller strongly depends
        # on it. If we just added the file we don't need to do this.
        if strong_dependency:
            self.move_to_front(vhd)

        return vhd

    def determine_compile_order(self, require=None):
        """Determines a possible compile order for the files in this list.
        `require` can optionally be set to a list of entities (each optionally
        prefixed with the library name, separated by a period, if a library
        other than "work" is desired) that must be compiled; in this case files
        that are not necessary to compile those will not be included in the
        returned compile order. The order is returned as a list of VhdFiles."""

        # Gather a list of all entities within files that were not filtered
        # out.
        entities = set()
        for vhd in self.files:
            if not self.is_file_filtered_out(vhd):
                entities.update(((vhd.lib, name) for name in vhd.entity_defs))

        # If the user specified a list of required entities, filter out
        # entities that are not required.
        if require:
            required_entities = set()
            for req in require:
                req = req.split('.', maxsplit=1)
                name = req[-1].lower()
                lib = req[0].lower() if len(req) > 1 else 'work'
                found = False
                for elib, ename in entities:
                    if fnmatch.fnmatchcase(elib.lower(), lib) and fnmatch.fnmatchcase(ename.lower(), name):
                        required_entities.add((elib, ename))
                        found = True
                if not found:
                    print('Warning: %s.%s did not match anything.' % (lib, name), file=sys.stderr)
            entities = required_entities

        # Sort the entities so the final compile order doesn't depend on
        # Python's nondeterministic set ordering.
        entities = reversed(sorted(entities))

        # Resolve all the entities that we found.
        for lib, name in entities:
            self.resolve_design_unit('entity', lib, name, False)

        # Store which files are not required by anything else and are thus
        # potential toplevels. This list is sorted by the filenames to be
        # consistent.
        self.top = []
        for vhd in self.order:
            for vhd2 in self.order:
                if vhd in vhd2.anywhere or vhd in vhd2.before:
                    break
            else:
                self.top.append(vhd)

    # Debugging stuff.
    def dump(self):
        for vhd in self.files:
            vhd.dump()
