SRC=src/btls.c src/iol.c src/utils.c
OBJ = $(SRC:%.c=%.o)
LIBNAME = libbtls
PKGCONFNAME = btls.pc

MAJOR_VERSION = $(shell grep BTLS_MAJOR include/btls.h  | awk '{print $$3}')
MINOR_VERSION = $(shell grep BTLS_MINOR include/btls.h  | awk '{print $$3}')
PATCH_VERSION = $(shell grep BTLS_PATCH include/btls.h  | awk '{print $$3}')
SONAME        = $(shell grep BTLS_SONAME include/btls.h | awk '{print $$3}')

# Installation related variables and target
PREFIX ?= /usr/local
INCLUDE_PATH ?= include/btls
LIBRARY_PATH ?= lib
PKGCONF_PATH ?= pkgconfig
INSTALL_INCLUDE_PATH = $(DESTDIR)$(PREFIX)/$(INCLUDE_PATH)
INSTALL_LIBRARY_PATH = $(DESTDIR)$(PREFIX)/$(LIBRARY_PATH)
INSTALL_PKGCONF_PATH = $(INSTALL_LIBRARY_PATH)/$(PKGCONF_PATH)

LIBRESSL_PATH ?= /usr/local/opt/libressl
LIBRESSL_INCLUDE_PATH = $(LIBRESSL_PATH)/include
LIBRESSL_LIBRARY_PATH = $(LIBRESSL_PATH)/lib

# Fallback to gcc when $CC is not in $PATH.
CC := $(shell sh -c 'type $(CC) >/dev/null 2>/dev/null && echo $(CC) || echo gcc')
OPTIMIZATION ?= -O3
WARNINGS = -Wall -W -Wstrict-prototypes -Wwrite-strings
DEBUG_FLAGS ?= -g -ggdb
REAL_CFLAGS = $(OPTIMIZATION) -I./include -I/usr/local/include -fPIC $(CFLAGS) $(WARNINGS) $(DEBUG_FLAGS) $(ARCH) -I$(LIBRESSL_INCLUDE_PATH)
REAL_LDFLAGS = $(LDFLAGS) $(ARCH) -L$(LIBRESSL_LIBRARY_PATH) -L/usr/local/lib -lcrypto -lssl -ltls -ldill

DYLIBSUFFIX = so
STLIBSUFFIX = a
DYLIB_MINOR_NAME = $(LIBNAME).$(DYLIBSUFFIX).$(SONAME)
DYLIB_MAJOR_NAME = $(LIBNAME).$(DYLIBSUFFIX).$(MAJOR_VERSION)
DYLIBNAME = $(LIBNAME).$(DYLIBSUFFIX)
DYLIB_MAKE_CMD = $(CC) -shared -Wl,-soname,$(DYLIB_MINOR_NAME) -o $(DYLIBNAME) $(LDFLAGS)
STLIBNAME = $(LIBNAME).$(STLIBSUFFIX)
STLIB_MAKE_CMD = ar rcs $(STLIBNAME)

# Platform-specific overrides
uname_S := $(shell sh -c 'uname -s 2>/dev/null || echo not')

ifeq ($(uname_S),Darwin)
  DYLIBSUFFIX = dylib
  DYLIB_MINOR_NAME = $(LIBNAME).$(SONAME).$(DYLIBSUFFIX)
  DYLIB_MAKE_CMD = $(CC) -shared -Wl,-install_name,$(DYLIB_MINOR_NAME) -o $(DYLIBNAME) $(REAL_LDFLAGS)
endif

all: $(DYLIBNAME) $(STLIBNAME) $(PKGCONFNAME)

# Deps (use make dep to generate this)
btls.o: src/btls.c include/btls.h include/iol.h include/utils.h
iol.o: src/iol.c include/iol.h include/utils.h
utils.o: src/utils.c include/utils.h

$(DYLIBNAME): $(OBJ)
	$(DYLIB_MAKE_CMD) $(OBJ)

$(STLIBNAME): $(OBJ)
	$(STLIB_MAKE_CMD) $(OBJ)

dynamic: $(DYLIBNAME)
static: $(STLIBNAME)

btls-%: %.o $(STLIBNAME)
	$(CC) $(REAL_CFLAGS) -o $@ $(REAL_LDFLAGS) $< $(STLIBNAME)

%.o: %.c
	$(CC) -c $(REAL_CFLAGS) -std=gnu99 -pedantic $< -o $@

clean:
	rm -rf $(DYLIBNAME) $(STLIBNAME) $(PKGCONFNAME) $(OBJ)

dep:
	$(CC) -MM $(SRC)

INSTALL ?= cp -a

$(PKGCONFNAME): include/btls.h
	@echo "Generating $@ for pkgconfig..."
	@echo prefix=$(PREFIX) > $@
	@echo exec_prefix=\$${prefix} >> $@
	@echo libdir=$(PREFIX)/$(LIBRARY_PATH) >> $@
	@echo includedir=$(PREFIX)/$(INCLUDE_PATH) >> $@
	@echo >> $@
	@echo Name: btls >> $@
	@echo Description: TLS socket library for libdill. >> $@
	@echo Requires.private: libdill libtls >> $@
	@echo Version: $(PKG_VERSION) >> $@
	@echo Libs: -L\$${libdir} -lbtls >> $@
	@echo Libs.private: -ldill -ltls >> $@
	@echo Cflags: -I\$${includedir} >> $@

install: $(DYLIBNAME) $(STLIBNAME) $(PKGCONFNAME)
	mkdir -p $(INSTALL_INCLUDE_PATH) $(INSTALL_LIBRARY_PATH)
	$(INSTALL) include/btls.h $(INSTALL_INCLUDE_PATH)
	$(INSTALL) $(DYLIBNAME) $(INSTALL_LIBRARY_PATH)/$(DYLIB_MINOR_NAME)
	cd $(INSTALL_LIBRARY_PATH) && ln -sf $(DYLIB_MINOR_NAME) $(DYLIBNAME)
	$(INSTALL) $(STLIBNAME) $(INSTALL_LIBRARY_PATH)
	mkdir -p $(INSTALL_PKGCONF_PATH)
	$(INSTALL) $(PKGCONFNAME) $(INSTALL_PKGCONF_PATH)

.PHONY: all clean dep install
