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

import os
import sys
import importlib
import argparse

_targets = {}

for fname in os.listdir(os.path.join(os.path.dirname(__file__), 'targets')):
    if not fname.endswith('.py'):
        continue
    name = os.path.splitext(os.path.basename(fname))[0]
    if name == '__init__':
        continue
    _targets[name] = importlib.import_module('.targets.' + name, package=__package__)

def print_targets():
    """Prints a list of available targets and documentation."""
    print('Available targets:')
    for name, mod in sorted(_targets.items()):
        print('\n%s %s %s\n' % (
            '-' * ((78 - len(name)) // 2),
            name,
            '-' * ((79 - len(name)) // 2)
        ))
        print(get_argument_parser(name).format_help())

def get_target(name):
    target = _targets.get(name, None)
    if target is None:
        print('Unknown target "%s".' % name, file=sys.stderr)
        print('Specify --targets to get a listing of all supported targets.', file=sys.stderr)
        sys.exit(1)
    return target

def get_argument_parser(name):
    mod = get_target(name)
    parser = argparse.ArgumentParser(
        prog='%s %s' % (sys.argv[0], name),
        description=mod.__doc__)
    if hasattr(mod, 'add_arguments'):
        mod.add_arguments(parser)
    return parser
