FROM abstudelft/ghdl-gcc-python

ADD . .
RUN python3 setup.py build
RUN python3 setup.py test
RUN python3 setup.py sdist
RUN python3 setup.py bdist_wheel
RUN bash -c "bash <(curl -s https://codecov.io/bash)"
