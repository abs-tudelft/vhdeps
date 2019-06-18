#!/usr/bin/env python3

import os
from setuptools import setup

def read(fname):
    with open(os.path.join(os.path.dirname(__file__), fname)) as f:
        return f.read()

setup(
    name = "vhdeps",
    version = "0.0.3",
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
)
