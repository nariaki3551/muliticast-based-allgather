CUDA_HOME ?=
NVCC_GENCODE ?=
HPCX_HOME ?=
PREFIX ?= /usr/local
DEBUG ?= 0
CUDA_FLAGS = -I$(CUDA_HOME)/include -L$(CUDA_HOME)/lib64 -lcudart

ifeq ($(DEBUG), 1)
DEBUG_FLAGS = --enable-debug
endif

.PHONY: all

all: build_ompi


update_submodules_non_recursive:
	git submodule update --init

update_submodules_ucx: update_submodules_non_recursive
	cd ucx && \
        git submodule update --init --recursive

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
        mkdir -p build && \
        cd build && \
        ../configure \
                --prefix=$(PREFIX) \
                --with-libevent \
                --with-hwloc \
                --enable-devel-headers && \
        make -j && \
        make install

build_prrte: update_submodules_ompi build_openpmix
	cd ompi/3rd-party/prrte/ && \
        ./autogen.pl && \
        mkdir -p build && \
        cd build && \
        CPPFLAGS="-I$(PREFIX)/include/pmix" \
        ../configure \
                --prefix=$(PREFIX) \
                --with-libevent \
                --with-hwloc \
                --with-pmix=$(PREFIX) && \
        make -j && \
        make install

# ucx -------------------------------------------------------
UCX_CONFIGURE_FLAGS := \
        --prefix=$(PREFIX) \
        --with-cuda=$(CUDA_HOME) \
        --enable-mt \
        $(DEBUG_FLAGS)

build_ucx: update_submodules_ucx
	cd ucx && \
        ./autogen.sh && \
        mkdir -p build && \
        cd build && \
        ../contrib/configure-release \
                $(UCX_CONFIGURE_FLAGS) && \
        make -j && \
        make install

reconfigure_and_build_ucx:
	cd ucx/build && \
	../contrib/configure-release \
		$(UCX_CONFIGURE_FLAGS) && \
	make -j && \
	make install

rebuild_ucx:
	cd ucx/build && \
	make -j && \
	make install

# ucc -------------------------------------------------------
UCC_CONFIGURE_FLAGS := \
        --prefix=$(PREFIX) \
        --with-ucx=$(PREFIX) \
        --with-tls=all \
        --with-cuda=$(CUDA_HOME) \
        $(DEBUG_FLAGS)
ifneq ($(NVCC_GENCODE),)
UCC_CONFIGURE_FLAGS += --with-nvcc-gencode=$(NVCC_GENCODE)
endif
ifneq ($(HPCX_HOME),)
UCC_CONFIGURE_FLAGS += --with-sharp=$(HPCX_HOME)/sharp
endif

build_ucc: build_ucx
	cd ucc && \
	./autogen.sh && \
	mkdir -p build && \
	cd build && \
	../configure $(UCC_CONFIGURE_FLAGS) && \
	make -j && \
	make install

reconfigure_and_build_ucc:
	cd ucc/build && \
	../configure $(UCC_CONFIGURE_FLAGS) && \
	make -j && \
	make install

rebuild_ucc:
	cd ucc/build && \
	make -j && \
	make install

# ompi -------------------------------------------------------
OMPI_CONFIGURE_FLAGS := \
        --prefix=$(PREFIX) \
        --with-libevent \
        --with-hwloc \
        --with-pmix=$(PREFIX) \
        --with-prrte=$(PREFIX) \
        --with-ucx=$(PREFIX) \
        --with-ucc=$(PREFIX) \
        --with-cuda=$(CUDA_HOME) \
        --with-cuda-libdir=$(CUDA_HOME)/lib64/stubs \
        $(DEBUG_FLAGS)

build_ompi: update_submodules_ompi build_libevent build_hwloc build_openpmix build_prrte build_ucx build_ucc
	cd ompi && \
        ./autogen.pl && \
        mkdir -p build && \
        cd build && \
        CPPFLAGS="-I$(PREFIX)/include/pmix" \
        ../configure \
                $(OMPI_CONFIGURE_FLAGS) && \
        make -j && \
        make install

reconfigure_and_build_ompi:
	cd ompi/build && \
	../configure \
		$(OMPI_CONFIGURE_FLAGS) && \
        make -j && \
        make install

rebuild_ompi:
	cd ompi/build && \
        make -j && \
        make install
