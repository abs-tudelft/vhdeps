#!/usr/bin/env python3

import os
import re
from setuptools import setup
from setuptools.command.test import test as TestCommand
from setuptools.command.build_py import build_py as BuildCommand

def read(fname):
    with open(os.path.join(os.path.dirname(__file__), fname)) as fildes:
        return fildes.read()

class NoseTestCommand(TestCommand):
    def finalize_options(self):
        TestCommand.finalize_options(self)
        self.test_args = []
        self.test_suite = True

    def run_tests(self):
        # Run nose ensuring that argv simulates running nosetests directly
        import nose
        nose.run_exit(argv=['nosetests'])

class BuildWithVersionCommand(BuildCommand):
    def run(self):
        BuildCommand.run(self)
        if not self.dry_run:
            version_fname = os.path.join(self.build_lib, 'vhdeps', 'version.py')
            with open(version_fname, 'w') as fildes:
                fildes.write('__version__ = """' + self.distribution.metadata.version + '"""\n')

setup(
    name = 'vhdeps',
    version_config={
        'version_format': '{tag}+{sha}',
        'starting_version': '0.0.1'
    },
    author = 'Jeroen van Straten',
    author_email = 'j.vanstraten-1@tudelft.nl',
    description = (
        'VHDL dependency analyzer and simulation driver.'
    ),
    license = 'Apache',
    keywords = 'vhdl dependency analyzer simulation',
    url = 'https://github.com/abs-tudelft/vhdeps',
    long_description = read('README.md'),
    long_description_content_type = 'text/markdown',
    classifiers = [
        'Development Status :: 3 - Alpha',
        'Intended Audience :: Developers',
        'Topic :: Software Development :: Build Tools',
        'License :: OSI Approved :: Apache Software License',
        'Programming Language :: Python :: 3',
    ],
    project_urls = {
        'Source': 'https://github.com/abs-tudelft/vhdeps',
    },
    packages = ['vhdeps', 'vhdeps.targets'],
    entry_points = {'console_scripts': ['vhdeps=vhdeps:run_cli']},
    python_requires = '>=3',
    install_requires = ['plumbum'],
    setup_requires = [
        'better-setuptools-git-version',
        'setuptools-lint',
        'pylint'
    ],
    tests_require = ['nose', 'coverage'],
    cmdclass = {
        'test': NoseTestCommand,
        'build_py': BuildWithVersionCommand,
    },
)
