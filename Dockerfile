FROM ubuntu:21.04 AS builder

# Env variables
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONPATH="$PYTHONPATH:/code/SuperBuild/install/lib/python3.9/dist-packages:/code/SuperBuild/install/lib/python3.8/dist-packages:/code/SuperBuild/install/bin/opensfm" \
    LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/code/SuperBuild/install/lib"

# Prepare directories
WORKDIR /code

# Copy everything
COPY . ./

# Use old-releases for 21.04
RUN printf "deb http://old-releases.ubuntu.com/ubuntu/ hirsute main restricted\ndeb http://old-releases.ubuntu.com/ubuntu/ hirsute-updates main restricted\ndeb http://old-releases.ubuntu.com/ubuntu/ hirsute universe\ndeb http://old-releases.ubuntu.com/ubuntu/ hirsute-updates universe\ndeb http://old-releases.ubuntu.com/ubuntu/ hirsute multiverse\ndeb http://old-releases.ubuntu.com/ubuntu/ hirsute-updates multiverse\ndeb http://old-releases.ubuntu.com/ubuntu/ hirsute-backports main restricted universe multiverse" > /etc/apt/sources.list

RUN apt update
RUN apt install -y python3 python3-pip python3-distutils
RUN pip3 install "cython<3.0.0" wheel
RUN pip3 install pyyaml==5.4.1 --no-build-isolation
RUN sed -i 's/pyyaml==5.4/pyyaml==5.4.1/g' requirements.txt
RUN pip install opencv-python
RUN apt install -y libgl1-mesa-glx
# Run the build
RUN bash configure.sh install 1
#|| true
#RUN cd SuperBuild/build && make

# Clean Superbuild
RUN bash configure.sh clean
### END Builder

### Use a second image for the final asset to reduce the number and
# size of the layers.
FROM ubuntu:21.04

# Env variables
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONPATH="$PYTHONPATH:/code/SuperBuild/install/lib/python3.9:/code/SuperBuild/install/lib/python3.8/dist-packages:/code/SuperBuild/install/bin/opensfm" \
    LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/code/SuperBuild/install/lib" \
    PDAL_DRIVER_PATH="/code/SuperBuild/install/bin"

WORKDIR /code

# Copy everything we built from the builder
COPY --from=builder /code /code

# Copy the Python libraries installed via pip from the builder
COPY --from=builder /usr/local /usr/local

# Use old-releases for 21.04
RUN printf "deb http://old-releases.ubuntu.com/ubuntu/ hirsute main restricted\ndeb http://old-releases.ubuntu.com/ubuntu/ hirsute-updates main restricted\ndeb http://old-releases.ubuntu.com/ubuntu/ hirsute universe\ndeb http://old-releases.ubuntu.com/ubuntu/ hirsute-updates universe\ndeb http://old-releases.ubuntu.com/ubuntu/ hirsute multiverse\ndeb http://old-releases.ubuntu.com/ubuntu/ hirsute-updates multiverse\ndeb http://old-releases.ubuntu.com/ubuntu/ hirsute-backports main restricted universe multiverse" > /etc/apt/sources.list
RUN apt update
RUN apt install -y python3 python3-pip python3-distutils
RUN pip3 install "cython<3.0.0" wheel
RUN pip3 install pyyaml==5.4.1 --no-build-isolation
RUN sed -i 's/pyyaml==5.4/pyyaml==5.4.1/g' requirements.txt
RUN pip install opencv-python
RUN apt install -y libgl1-mesa-glx libtbb2

# Install shared libraries that we depend on via APT, but *not*
# the -dev packages to save space!
# Also run a smoke test on ODM and OpenSfM
RUN bash configure.sh installruntimedepsonly \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
  && bash run.sh --help \
  && bash -c "eval $(python3 /code/opendm/context.py) && python3 -c 'from opensfm import io, pymap'"
# Entry point
ENTRYPOINT ["python3", "/code/run.py"]
