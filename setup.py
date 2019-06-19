#!/usr/bin/env python3

import os
import re
from setuptools import setup
from setuptools.command.test import test as TestCommand

def read(fname):
    with open(os.path.join(os.path.dirname(__file__), fname)) as fildes:
        return fildes.read()

def get_version():
    with open('vhdeps/__init__.py', 'r') as fildes:
        for line in fildes:
            match = re.match("__version__ = '([^']+)'\n", line)
            if match:
                return match.group(1)
    raise ValueError('Could not find package version')

class NoseTestCommand(TestCommand):
    def finalize_options(self):
        TestCommand.finalize_options(self)
        self.test_args = []
        self.test_suite = True

    def run_tests(self):
        # Run nose ensuring that argv simulates running nosetests directly
        import nose
        nose.run_exit(argv=['nosetests'])

setup(
    name = "vhdeps",
    version = get_version(),
    author = "Jeroen van Straten",
    author_email = "j.vanstraten-1@tudelft.nl",
    description = (
        "VHDL dependency analyzer and simulation driver."
    ),
    license = "Apache",
    keywords = "vhdl dependency analyzer simulation",
    url = "https://github.com/abs-tudelft/vhdeps",
    long_description = read('README.md'),
    long_description_content_type = 'text/markdown',
    classifiers = [
        "Development Status :: 3 - Alpha",
        "Intended Audience :: Developers",
        "Topic :: Software Development :: Build Tools",
        "License :: OSI Approved :: Apache Software License",
        "Programming Language :: Python :: 3",
    ],
    project_urls = {
        'Source': 'https://github.com/abs-tudelft/vhdeps',
    },
    packages = ['vhdeps', 'vhdeps.targets'],
    entry_points = {'console_scripts': ['vhdeps=vhdeps:run_cli']},
    python_requires = '>=3',
    install_requires = ['plumbum'],
    setup_requires = ['setuptools-lint', 'pylint'],
    tests_require = ['nose', 'coverage'],
    cmdclass = {'test': NoseTestCommand},
)
