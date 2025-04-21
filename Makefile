CUDA_DIR ?= /usr/local/cuda
PREFIX ?= /usr/local
HPCX_DIR ?= /opt/hpcx-v2.22.1-gcc-doca_ofed-ubuntu22.04-cuda12-x86_64
NVCC_GENCODE ?= -gencode=arch=compute_70,code=sm_70
CUDA_FLAGS = -I$(CUDA_DIR)/include -L$(CUDA_DIR)/lib64 -lcudart
export LD_LIBRARY_PATH := $(PREFIX)/lib:$(LD_LIBRARY_PATH)

.PHONY: all

all: build_ompi

init_ucx:
	git submodule update --init ucx && \
        cd ucx
	# git checkout v1.18.0

init_ompi:
	git submodule update --init ompi && \
        cd ompi
	# git checkout v5.0.7

update_submodules_ucx: init_ucx
	cd ucx && \
        git submodule update --init --recursive

update_submodules_ompi: init_ompi
	cd ompi && \
        git submodule update --init --recursive

build_libevent: init_ompi
	cd ompi/3rd-party && \
	tar -xf libevent-2.1.12-stable.tar.gz && \
	cd libevent-2.1.12-stable && \
	./configure --prefix=$(PREFIX) && \
	make -j && \
	make install

build_hwloc: init_ompi
	cd ompi/3rd-party && \
	tar -xf hwloc-2.7.1.tar.gz && \
	cd hwloc-2.7.1 && \
	./configure --prefix=$(PREFIX) && \
	make -j && \
	make install

build_openpmix: update_submodules_ompi build_libevent build_hwloc
	cd ompi/3rd-party/openpmix/ && \
        ./autogen.pl && \
        ./configure \
                --prefix=$(PREFIX) \
                --with-libevent=$(PREFIX) \
                --with-hwloc=$(PREFIX) \
                --enable-devel-headers && \
        make -j && \
        make install

build_prrte: update_submodules_ompi build_libevent build_hwloc build_openpmix
	cd ompi/3rd-party/prrte/ && \
        ./autogen.pl && \
        CPPFLAGS="-I$(PREFIX)/include/pmix" \
        ./configure \
                --prefix=$(PREFIX) \
                --with-libevent=$(PREFIX) \
                --with-hwloc=$(PREFIX) \
                --with-pmix=$(PREFIX) && \
        make -j && \
        make install

build_ucx: update_submodules_ucx
	cd ucx && \
        ./autogen.sh && \
        ./contrib/configure-release \
                --prefix=$(PREFIX) \
                --with-cuda=$(CUDA_DIR) \
                --enable-mt && \
        make -j && \
        make install

build_ucc: build_ucx
	cd ucc && \
	./autogen.sh && \
        ./configure \
                --prefix=$(PREFIX) \
                --with-ucx=$(PREFIX) \
                --with-tls=all \
                --with-cuda=$(CUDA_DIR) \
                --with-nvcc-gencode=$(NVCC_GENCODE) \
                --with-sharp=$(HPCX_DIR)/sharp && \
        make -j && \
        make install

build_ompi: update_submodules_ompi build_libevent build_hwloc build_openpmix build_prrte build_ucx build_ucc
	cd ompi && \
        ./autogen.pl && \
        CPPFLAGS="-I$(PREFIX)/include/pmix" \
        ./configure \
                --prefix=$(PREFIX) \
                --with-libevent=$(PREFIX) \
                --with-hwloc=$(PREFIX) \
                --with-pmix=$(PREFIX) \
                --with-prrte=$(PREFIX) \
                --with-ucx=$(PREFIX) \
                --with-ucc=$(PREFIX) \
                --with-cuda=$(CUDA_DIR) \
                --with-cuda-libdir=$(CUDA_DIR)/lib64/stubs \
                $(DEBUG_FLAGS) && \
        make -j && \
        make install
