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

"""Core dependency analysis module for vhdeps."""

import re
import os
import sys
import functools
import fnmatch
from collections import deque

class StyleError(Exception):
    """Thrown to indicate that a style error was detected during a strict
    import."""

class ResolutionError(Exception):
    """Thrown when a dependency of a required file could not be resolved."""

def _parse_version(version):
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
class VhdFile:
    """Represents a VHDL file."""

    ENTITY_DEF = re.compile(
        r'entity\s+([a-zA-Z][a-zA-Z0-9_]*)\s+is')
    ENTITY_USE = re.compile(
        r':\s*entity\s+(([a-zA-Z][a-zA-Z0-9_]*)\.)?'
        r'([a-zA-Z][a-zA-Z0-9_]*)\s*[(\sport)|(\sgeneric)|;]')
    ENTITY_IGNORE = re.compile(
        r'\-\-\s*pragma\s+vhdeps\s+ignore\s+entity\s+([a-zA-Z0-9_\.]+)')
    COMPONENT_DEF = re.compile(
        r'component\s+([a-zA-Z][a-zA-Z0-9_]*)\s+is')
    COMPONENT_USE = re.compile(
        r':\s*(?:component\s+)?([a-zA-Z][a-zA-Z0-9_]*)\s*((\sport)|(\sgeneric))\s+map')
    COMPONENT_IGNORE = re.compile(
        r'\-\-\s*pragma\s+vhdeps\s+ignore\s+component\s+([a-zA-Z0-9_\.]+)')
    PACKAGE_DEF = re.compile(
        r'package\s+([a-zA-Z][a-zA-Z0-9_]*)\s+is')
    PACKAGE_USE = re.compile(
        r'use\s+([a-zA-Z][a-zA-Z0-9_]*)\.([a-zA-Z][a-zA-Z0-9_]*)')
    PACKAGE_IGNORE = re.compile(
        r'\-\-\s*pragma\s+vhdeps\s+ignore\s+package\s+([a-zA-Z0-9_\.]+)')
    TIMEOUT = re.compile(
        r'\-\-\s*pragma\s+simulation\s+timeout\s+([0-9]+(?:\.[0-9]*)?\s+[pnum]?s)')

    def __init__(self, fname, lib='work', override_version=None,
                 desired_version=2008, strict=False, allow_bb=False):
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
        self.fname = fname
        self.lib = lib
        self.strict = strict
        self.allow_bb = allow_bb

        # Determine the VHDL versions this file is supposed to be compatible
        # with.
        if override_version is not None:
            versions = (override_version,)
        else:
            versions = map(lambda x: x.group(1),
                           re.finditer(r'\.(19[7-9]\d|20[0-6]\d|\d\d)(?=\.)', fname))
        self.versions = set(map(_parse_version, versions))

        # Determine the version that we'll be compiling the file with if we
        # need to.
        self.version = min(self.versions,
                           key=lambda v: abs(v - desired_version), default=desired_version)

        # Determine whether this file is simulation- or synthesis-only.
        self.use_for_synthesis = '.sim.' not in fname
        self.use_for_simulation = '.syn.' not in fname

        # Read and "parse" the file. "Parsing" is limited to stripping comments
        # and pattern matching to keep things simple.
        try:
            with open(fname, 'r') as fildes:
                contents = fildes.read().lower()
        except Exception as exc:
            raise RuntimeError('failed to read VHDL file at %s: %s' % (self.fname, exc))
        sim_timeout = [match.group(1)for match in self.TIMEOUT.finditer(contents)]

        entity_ignore = {
            match.group(1)
            for match in self.ENTITY_IGNORE.finditer(contents)}
        component_ignore = {
            match.group(1)
            for match in self.COMPONENT_IGNORE.finditer(contents)}
        package_ignore = {
            match.group(1)
            for match in self.PACKAGE_IGNORE.finditer(contents)}

        contents = ' '.join((line.split('--')[0] for line in contents.split('\n')))

        self.entity_defs = sorted({
            match.group(1)
            for match in self.ENTITY_DEF.finditer(contents)})
        self.entity_uses = sorted({
            (match.group(2), match.group(3))
            for match in self.ENTITY_USE.finditer(contents)
            if match.group(3) not in entity_ignore})
        self.component_defs = sorted({
            match.group(1)
            for match in self.COMPONENT_DEF.finditer(contents)})
        self.component_uses = sorted({
            match.group(1)
            for match in self.COMPONENT_USE.finditer(contents)
            if match.group(1) not in component_ignore})
        self.package_defs = sorted({
            match.group(1)
            for match in self.PACKAGE_DEF.finditer(contents)})
        self.package_uses = sorted({
            (match.group(1), match.group(2))
            for match in self.PACKAGE_USE.finditer(contents)
            if match.group(2) not in package_ignore})

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

        # Before and anywhere are populated by resolve_dependencies.
        self.before = None
        self.anywhere = None

    def resolve_dependencies(self, resolver, ignore_libs=None):
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

        # Don't run again if we've already resolved our dependencies.
        if self.before is not None:
            return

        if ignore_libs is None:
            ignore_libs = {'ieee', 'std'}

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
                    vhd = resolver(unit_type, lib, name)
                except ResolutionError as exc:
                    raise ResolutionError(
                        'while resolving %s %s.%s in %s:\n%s' %
                        (unit_type, lib, name, self, exc))

                # If the resolved file is ourself, assume that the design units
                # are listed in the correct order; if they're not, there's
                # nothing vhdeps can do about it, anyway. Either way, the
                # dependency does not matter for our compile order analysis, so
                # we ignore it.
                if vhd is self:
                    continue

                # Make sure the dependency is compiled before us.
                self.before.add(vhd)

                # Included packages can define components. So, when we look for
                # components later, make sure we look in this file as well.
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
                        'could not find component declaration for %s within:\n - %s' %
                        (comp, '\n - '.join(map(str, component_decl_vhds))))

                # Look for the accompanying entity and make sure it is compiled
                # at some point. If the component was defined in a file
                # included through -X (allow_bb == True), we accept that the
                # component is a black box if we can't find the entity.
                try:
                    self.anywhere.add(resolver('entity', lib, comp))
                except ResolutionError as exc:
                    if not allow_bb:
                        raise ResolutionError('black box: %s' % exc)

            except ResolutionError as exc:
                raise ResolutionError(
                    'while resolving component %s in %s:\n%s' %
                    (comp, self, exc))

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
        if not isinstance(other, VhdFile):
            return False
        return self.fname == other.fname

    def __lt__(self, other):
        if not isinstance(other, VhdFile):
            raise TypeError('cannot compare VhdFile with %s' % type(other).__name__)
        return self.fname < other.fname

    def __str__(self):
        return self.fname

    __repr__ = __str__

class VhdList:
    """Represents a list of all VHDL files available for compilation."""

    def __init__(self, mode='sim', desired_version=None, required_version=None):
        """Constructs a VHDL file list. `simulation` specifies whether we're
        compiling for simulation or synthesis. `version` specifies the maximum
        supported VHDL version of the target."""
        super().__init__()
        self.mode = mode
        self.required_version = _parse_version(required_version)
        if self.required_version is None:
            if desired_version is None:
                desired_version = 2008
            self.desired_version = _parse_version(desired_version)
        else:
            self.desired_version = self.required_version
        self.files = set()
        self.design_units = {}
        self.order = deque()
        self.top = []

    def add_dir(self, dirname, recursive=True, **kwargs):
        """Adds a directory to the VHDL file list. `dirname` specifies the root
        directory, `recursive` specifies whether we should recurse into
        subdirectories. `add_file` is called for all `*.vhd` and `*.vhdl` files
        encountered using the specified keyword arguments."""
        for basename in os.listdir(dirname):
            fname = os.path.join(dirname, basename)
            if os.path.isdir(fname):
                if recursive:
                    self.add_dir(fname, recursive, **kwargs)
            elif basename.lower().endswith('.vhd') or basename.lower().endswith('.vhdl'):
                self.add_file(fname, **kwargs)

    def add_file(self, *args, **kwargs):
        """Adds a file to the VHDL file list. All arguments are passed directly
        to `VhdFile`'s constructor."""
        kwargs['desired_version'] = self.desired_version
        vhd = VhdFile(*args, **kwargs)
        self.files.add(vhd)
        return vhd

    def _is_file_filtered_out(self, vhd):
        """Returns a non-empty string when the given `VhdFile` is filtered out
        by this list's configuration with the reason for it being filtered out,
        or `None` if the file is matches all filters."""
        if self.mode == 'sim' and not vhd.use_for_simulation:
            return '%s is synthesis-only' % vhd
        if self.mode == 'syn' and not vhd.use_for_synthesis:
            return '%s is simulation-only' % vhd
        if self.required_version is not None:
            if vhd.versions:
                if not self.required_version in vhd.versions:
                    return '%s is not compatible with VHDL %s' % (vhd, self.required_version)
        return None

    def _resolve_design_unit(self, unit_type, lib, name):
        """Resolves the requested design unit to a file. Also resolves its
        dependencies recusively if the file is not in the list yet. The design
        unit is identified by `unit_type`, which must be `'entity'` or
        `'package'`, and its library and VHDL identifier. The matching
        `VhdFile` is returned if the resolution succeeds. A `ResolutionError`
        is raised otherwise."""

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
                    filter_reason = self._is_file_filtered_out(vhd)
                    if filter_reason:
                        filtered_out.append(filter_reason)
                    else:
                        options.append(vhd)

            # If we didn't find anything compliant, throw an error.
            if not options:
                if filtered_out:
                    raise ResolutionError(
                        '%s %s.%s is defined, but only in files that were filtered out:\n - %s' %
                        (unit_type, lib, name, '\n - '.join(filtered_out)))
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
            options = list(filter(
                lambda vhd: best_version in vhd.versions or not vhd.versions, options))

            # If we still have more than one option, let the user figure it
            # out.
            if len(options) > 1:
                raise ResolutionError(
                    '%s %s.%s is defined in multiple, ambiguous files:\n - %s' %
                    (unit_type, lib, name, '\n - '.join(map(str, options))))

            vhd = options[0]

            # Store the design unit mapping.
            self.design_units[ident] = vhd

            # Resolve this file's dependencies recursively.
            vhd.resolve_dependencies(self._resolve_design_unit)

        return vhd

    def _move_to_front(self, vhd, stack=()):
        """Moves the specified `VhdFile` object to the front of the compile
        order, taking its dependencies along with it. The file must already
        have been compiled and must already have had its dependencies
        resolved.."""
        if vhd in stack:
            raise ResolutionError('circular dependency:\n - ' + '\n - '.join(map(str, stack)))
        self.order.remove(vhd)
        self.order.appendleft(vhd)
        stack += (vhd,)
        for vhd_dep in sorted(vhd.before, key=str):
            self._move_to_front(vhd_dep, stack)

    def _add_to_compile_order(self, vhd, strong_dependency=False):
        """Adds the given resolved VHDL file to the compile order list if it is
        not in the list yet. If it was already in the list but this function
        was called due to a strong dependency of another file we just added
        (`strong_dependency` is set), the file is moved to the front of the
        compilation list, along with all its strong dependencies recursively.
        If this causes a cycle, a `ResolutionError` is raised."""

        # Resolve the file if it hasn't been resolved yet.
        if vhd not in self.order:
            self.order.appendleft(vhd)
            for dependency in sorted(vhd.before, key=str):
                self._add_to_compile_order(dependency, True)
            for dependency in sorted(vhd.anywhere, key=str):
                self._add_to_compile_order(dependency, False)

            # This file and its dependencies are already at the front of
            # the compile order, so we don't need to move it to the front
            # again even if there was a strong dependency.
            return vhd

        # Move the file to the front of the compile order list if the file
        # whose dependencies were being resolved by the caller strongly depends
        # on it. If we just added the file we don't need to do this.
        if strong_dependency:
            self._move_to_front(vhd)

        return vhd

    def determine_compile_order(self, require=None):
        """Determines a possible compile order for the files in this list.
        `require` can optionally be set to a list of design units (each
        optionally prefixed with the library name, separated by a period, if a
        library other than "work" is desired) that must be compiled; in this
        case files that are not necessary to compile those will not be included
        in the returned compile order. The order is returned as a list of
        `VhdFile`s."""

        # Gather a list of all design units within files that were not filtered
        # out.
        units = set()
        for vhd in self.files:
            if not self._is_file_filtered_out(vhd):
                units.update((('entity', vhd.lib, name) for name in vhd.entity_defs))
                units.update((('package', vhd.lib, name) for name in vhd.package_defs))

        # If the user specified a list of required design units, filter out
        # design units that are not required.
        if require:
            required_units = set()
            for req in require:
                req = req.split('.', maxsplit=1)
                name = req[-1].lower()
                lib = req[0].lower() if len(req) > 1 else 'work'
                found = False
                for etyp, elib, ename in units:
                    if fnmatch.fnmatchcase(elib.lower(), lib):
                        if fnmatch.fnmatchcase(ename.lower(), name):
                            required_units.add((etyp, elib, ename))
                            found = True
                if not found:
                    print('Warning: %s.%s did not match anything.' % (lib, name), file=sys.stderr)
            units = required_units

        # Sort the design units so the final compile order doesn't depend on
        # Python's nondeterministic set ordering.
        units = reversed(sorted(units))

        # Resolve all the entities that we found.
        units = [self._resolve_design_unit(typ, lib, name) for typ, lib, name in units]

        # Add the entities to the compile order.
        for unit in units:
            self._add_to_compile_order(unit)

        # Store which files are not required by anything else and are thus
        # potential toplevels. This list is sorted by the filenames to be
        # consistent.
        self.top = []
        for vhd in self.order:
            if not vhd.entity_defs:
                continue
            for vhd2 in self.order:
                if vhd in vhd2.anywhere or vhd in vhd2.before:
                    break
            else:
                self.top.append(vhd)
