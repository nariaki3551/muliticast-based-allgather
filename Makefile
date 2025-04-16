CXX = mpicxx
CXXFLAGS = -g -O0
CUDA_FLAGS = -I/usr/local/cuda/include -L/usr/local/cuda/lib64 -lcudart
PREFIX = /usr
HPCX_PATH = /app/hpcx-v2.22.1-gcc-doca_ofed-ubuntu22.04-cuda12-x86_64
CUDA_DIR = /usr/local/cuda

.PHONY: all

all:
	build_ucx
	build_ucc
	build_ompi

build_ucx:
	cd ucx \
        && ./autogen.sh \
        && ./contrib/configure-release \
                --prefix=$(PREFIX) \
                --with-cuda=$(CUDA_DIR) \
                --enable-mt \
        && make -j \
        && make install

build_ucc:
	cd ucc \
        && ./autogen.sh \
        && ./configure \
                --prefix=$(PREFIX) \
                --with-ucx=$(PREFIX) \
                --with-tls=all \
                --with-cuda=$(CUDA_DIR) \
                --with-sharp=$(HPCX_PATH)/sharp \
                --with-nvcc-gencode="-gencode=arch=compute_70,code=sm_70" \
        && make -j \
        && make install

build_ompi:
	cd ompi \
        && git submodule update --init --recursive \
        && ./autogen.pl \
        && ./configure \
                --prefix=$(PREFIX) \
                --with-ucx=$(PREFIX) \
                --with-ucc=$(PREFIX) \
                --with-cuda=$(CUDA_DIR) \
                --with-cuda-libdir=/usr/local/cuda/lib64/stubs \
        && make -j \
        && make install
