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
    print()
    for name, mod in sorted(_targets.items()):
        print(' - %s' % name)
        print('   ' + '\n   '.join(mod.__doc__.split('\n')))
        print()

def get_target(name):
    target = _targets.get(name, None)
    if target is None:
        print('Unknown target "%s".' % name, file=sys.stderr)
        print('Specify --targets to get a listing of all supported targets.', file=sys.stderr)
        sys.exit(1)
    return target
