CXX = mpicxx
CXXFLAGS = -g -O0
CUDA_DIR ?= /usr/local/cuda
PREFIX ?= /usr
HPCX_DIR ?= /opt/hpcx-v2.22.1-gcc-doca_ofed-ubuntu22.04-cuda12-x86_64
CUDA_FLAGS = -I$(CUDA_DIR)/include -L$(CUDA_DIR)/lib64 -lcudart

.PHONY: all

all: build_ompi

update_submodules_non_recursive:
	git submodule update --init

update_submodules_ompi: update_submodules_non_recursive
	cd ompi && \
        git submodule update --init --recursive

build_libevent:
	@echo "Using apt-installed libevent"

build_hwloc:
	@echo "Using apt-installed hwloc"

build_openpmix: update_submodules_ompi build_libevent build_hwloc
	cd ompi/3rd-party/openpmix/ && \
        ./autogen.pl && \
        ./configure \
                --prefix=$(PREFIX) \
                --with-libevent \
                --with-hwloc \
                --enable-devel-headers && \
        make -j && \
        make install

build_prrte: update_submodules_ompi build_libevent build_hwloc build_openpmix
	cd ompi/3rd-party/prrte/ && \
        ./autogen.pl && \
        ./configure \
                --prefix=$(PREFIX) \
                --with-libevent \
                --with-hwloc \
                --with-pmix=$(PREFIX) && \
        make -j && \
        make install

build_ucx: update_submodules_non_recursive
	cd ucx && \
	git submodule update --init --recursive && \
        ./autogen.sh && \
        ./contrib/configure-release \
                --prefix=$(PREFIX) \
                --with-cuda=$(CUDA_DIR) \
                --enable-mt && \
        make -j && \
        make install

build_ucc: update_submodules_non_recursive build_ucx
	cd ucc && \
	git submodule update --init --recursive && \
        ./autogen.sh && \
        ./configure \
                --prefix=$(PREFIX) \
                --with-ucx=$(PREFIX) \
                --with-tls=all \
                --with-cuda=$(CUDA_DIR) \
                --with-nvcc-gencode="-gencode=arch=compute_70,code=sm_70" \
                --with-sharp=$(HPCX_DIR)/sharp && \
        make -j && \
        make install

build_ompi: update_submodules_non_recursive build_libevent build_hwloc build_openpmix build_prrte build_ucx build_ucc
	cd ompi && \
	git submodule update --init --recursive && \
        ./autogen.pl && \
        ./configure \
                --prefix=$(PREFIX) \
                --with-libevent \
                --with-hwloc \
                --with-pmix=$(PREFIX) \
                --with-prrte=$(PREFIX) \
                --with-ucx=$(PREFIX) \
                --with-ucc=$(PREFIX) \
                --with-cuda=$(CUDA_DIR) \
                --with-cuda-libdir=$(CUDA_DIR)/lib64/stubs \
                $(DEBUG_FLAGS) && \
        make -j && \
        make install
