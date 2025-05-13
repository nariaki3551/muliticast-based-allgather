CUDA_HOME ?=
NVCC_GENCODE ?=
HPCX_HOME ?=
PREFIX ?= /usr/local
CUDA_FLAGS = -I$(CUDA_HOME)/include -L$(CUDA_HOME)/lib64 -lcudart

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

build_openpmix: update_submodules_ompi
	cd ompi/3rd-party/openpmix/ && \
        ./autogen.pl && \
        ./configure \
                --prefix=$(PREFIX) \
                --with-libevent \
                --with-hwloc \
                --enable-devel-headers && \
        make -j && \
        make install

build_prrte: update_submodules_ompi build_openpmix
	cd ompi/3rd-party/prrte/ && \
        ./autogen.pl && \
        CPPFLAGS="-I$(PREFIX)/include/pmix" \
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
                --with-cuda=$(CUDA_HOME) \
                --enable-mt && \
        make -j && \
        make install

# ucc configure flags
CONFIGURE_FLAGS := --prefix=$(PREFIX) --with-ucx=$(PREFIX) --with-tls=all
ifneq ($(CUDA_HOME),)
CONFIGURE_FLAGS += --with-cuda=$(CUDA_HOME)
endif
ifneq ($(NVCC_GENCODE),)
CONFIGURE_FLAGS += --with-nvcc-gencode=$(NVCC_GENCODE)
endif
ifneq ($(HPCX_HOME),)
CONFIGURE_FLAGS += --with-sharp=$(HPCX_HOME)/sharp
endif
build_ucc: update_submodules_non_recursive build_ucx
	cd ucc && \
	git submodule update --init --recursive && \
	./autogen.sh && \
	./configure $(CONFIGURE_FLAGS) && \
	make -j && \
	make install

build_ompi: update_submodules_non_recursive build_libevent build_hwloc build_openpmix build_prrte build_ucx build_ucc
	cd ompi && \
	git submodule update --init --recursive && \
        ./autogen.pl && \
        CPPFLAGS="-I$(PREFIX)/include/pmix" \
        ./configure \
                --prefix=$(PREFIX) \
                --with-libevent \
                --with-hwloc \
                --with-pmix=$(PREFIX) \
                --with-prrte=$(PREFIX) \
                --with-ucx=$(PREFIX) \
                --with-ucc=$(PREFIX) \
                --with-cuda=$(CUDA_HOME) \
                --with-cuda-libdir=$(CUDA_HOME)/lib64/stubs \
                $(DEBUG_FLAGS) && \
        make -j && \
        make install
