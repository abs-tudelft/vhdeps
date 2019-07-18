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

"""Submodule that manages discovering and loading submodules from the targets
subdirectory."""

import os
import importlib
import argparse

_TARGETS = {}

for fname in os.listdir(os.path.join(os.path.dirname(__file__), 'targets')):
    if fname.endswith('.py'):
        _name = os.path.splitext(os.path.basename(fname))[0]
        if _name in ('__init__', 'shared'):
            continue
        _TARGETS[_name] = importlib.import_module('.targets.' + _name, package=__package__)

def print_help():
    """Prints a list of available targets and documentation."""
    print('Available targets:')
    for name, _ in sorted(_TARGETS.items()):
        print('\n%s %s %s\n' % (
            '-' * ((78 - len(name)) // 2),
            name,
            '-' * ((79 - len(name)) // 2)
        ))
        print(get_argument_parser(name).format_help())

def get_target(name):
    """Returns the module of the target going by the given name. Returns `None`
    if the target does not exist."""
    return _TARGETS.get(name, None)

def get_argument_parser(name):
    """Returns the argparse `ArgumentParser` object for the target going by the
    given name."""
    mod = get_target(name)
    parser = argparse.ArgumentParser(
        prog='vhdeps %s' % name,
        description=mod.__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    if hasattr(mod, 'add_arguments'):
        mod.add_arguments(parser)
    return parser
