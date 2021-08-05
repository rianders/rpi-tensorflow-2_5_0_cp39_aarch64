FROM --platform=linux/arm64 arm64v8/python AS base

WORKDIR tensorflow-build

RUN apt-get update && apt-get install -y --no-install-recommends \
 build-essential python3-pip zip unzip curl openjdk-11-jdk \
 make cmake wget libhdf5-dev libc-ares-dev libeigen3-dev \
 libatlas-base-dev libopenblas-dev libblas-dev \
 gfortran liblapack-dev
  

RUN  pip3 install numpy==1.19.5

RUN pip3 install --upgrade setuptools
RUN pip3 install pybind11 Cython
RUN pip3 install h5py==3.1.0
RUN pip3 install --upgrade wrapt
RUN pip3 install --upgrade wrapt
RUN pip3 install gast==0.4.0
RUN pip3 install absl-py astunparse
RUN pip3 install flatbuffers google_pasta
RUN pip3 install opt_einsum protobuf
RUN pip3 install -U --user six termcolor wheel mock
RUN pip3 install typing_extensions
RUN pip3 install keras_applications --no-deps
RUN pip3 install keras_preprocessing --no-deps


FROM base AS getbazelandtensorflow
#Build Bazil
COPY bazel-3.7.2-dist.zip .
COPY tensorflow.zip .

RUN unzip bazel-3.7.2-dist.zip
RUN unzip tensorflow.zip

FROM getbazelandtensorflow AS buildbazel
 
COPY compile.sh ./bazel/scripts/bootstrap/

#WORKDIR tensorflow-build/bazel

RUN env EXTRA_BAZEL_ARGS="--host_javabase=@local_jdk//:jdk" bash ./compile.sh

RUN cp output/bazel /usr/local/bin/bazel

#Build tensorflow

FROM buildbazel AS unziptensorflow
#WORKDIR /tensorflow-build/
#RUN  wget -O tensorflow.zip https://github.com/tensorflow/tensorflow/archive/v2.5.0.zip

#RUN  unzip ../tensorflow.zip

FROM unziptensorflow AS buildtensorflow

WORKDIR tensorflow-2.5.0
RUN ./configure
RUN bazel clean

RUN bazel --host_jvm_args=-Xmx1624m build \
             --config=opt \
             --config=noaws \
             --config=nogcp \
             --config=nohdfs \
             --config=nonccl \
             --config=monolithic \
             --config=v2 \
             --local_cpu_resources=1 \
             --define=tflite_pip_with_flex=true \
             --copt=-ftree-vectorize \
             --copt=-funsafe-math-optimizations \
             --copt=-ftree-loop-vectorize \
             --copt=-fomit-frame-pointer \
             //tensorflow/tools/pip_package:build_pip_package

CMD [ "/bin/bash"]
