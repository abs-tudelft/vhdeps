FROM abstudelft/ghdl-gcc-python:latest

ADD . /src
WORKDIR /src
RUN python3 setup.py install && \
    rm -rf /src
