TARGET = btls
LIB_NAME = btls
PKG_NAME = btls
PKG_VERSION = 0.1.0
PKGCONFNAME = btls.pc

PREFIX ?= /usr/local
INCLUDE_PATH ?= include/btls
LIBRARY_PATH ?= lib
PKGCONF_PATH ?= pkgconfig
INSTALL_INCLUDE_PATH = $(PREFIX)/$(INCLUDE_PATH)
INSTALL_LIBRARY_PATH = $(PREFIX)/$(LIBRARY_PATH)
INSTALL_PKGCONF_PATH = $(INSTALL_LIBRARY_PATH)/$(PKGCONF_PATH)

TLSPREFIX ?= /usr/local/opt/libressl

UNAME := $(shell uname)

INSTALL ?= cp -a

all: $(TARGET) $(PKGCONFNAME)

$(TARGET): *.c
	clang -c *.c -I$(TLSPREFIX)/include -mmacosx-version-min=10.10
ifeq ($(UNAME), Linux)
	ar -rcs lib$(LIB_NAME).a *.o
endif
ifeq ($(UNAME), Darwin)
	libtool -dynamic *.o -o lib$(LIB_NAME).dylib \
	 	-lSystem -macosx_version_min 10.10 \
	 	-lcrypto -lssl -ltls \
	 	-L/usr/local/opt/libressl/lib \
	 	-ldill
endif
	rm *.o

install: $(TARGET) $(PKGCONFNAME)
	mkdir -p $(TARGET)/usr/local/lib
	mkdir -p $(TARGET)/usr/local/include/$(TARGET)
	cp *.h $(TARGET)/usr/local/include/$(TARGET)
ifeq ($(UNAME), Darwin)
	# copy .dylib
	cp lib$(LIB_NAME).dylib $(TARGET)/usr/local/lib/
endif
ifeq ($(UNAME), Linux)
	# copy .a
	cp lib$(LIB_NAME).a $(TARGET)/usr/local/lib/
endif
	mkdir -p $(PREFIX)
	cp -r $(TARGET)/usr/local/* $(PREFIX)/
	mkdir -p $(INSTALL_PKGCONF_PATH)
	$(INSTALL) $(PKGCONFNAME) $(INSTALL_PKGCONF_PATH)

package:
ifeq ($(UNAME), Linux)
	mkdir -p $(TARGET)/DEBIAN
	mkdir -p $(TARGET)/usr/local/lib
	mkdir -p $(TARGET)/usr/local/include/$(TARGET)
	cp *.h $(TARGET)/usr/local/include/$(TARGET)
	cp lib$(LIB_NAME).a $(TARGET)/usr/local/lib/
	touch $(TARGET)/DEBIAN/control
	echo "Package: $(PKG_NAME)" >> $(TARGET)/DEBIAN/control
	echo "Version: $(PKG_VERSION)" >> $(TARGET)/DEBIAN/control
	echo "Section: custom" >> $(TARGET)/DEBIAN/control
	echo "Priority: optional" >> $(TARGET)/DEBIAN/control
	echo "Architecture: all" >> $(TARGET)/DEBIAN/control
	echo "Essential: no" >> $(TARGET)/DEBIAN/control
	echo "Installed-Size: 16224" >> $(TARGET)/DEBIAN/control
	echo "Maintainer: zewo.io" >> $(TARGET)/DEBIAN/control
	echo "Description: $(TARGET)" >> $(TARGET)/DEBIAN/control
	dpkg-deb --build $(TARGET)
	rm -rf $(TARGET)
endif

$(PKGCONFNAME): btls.h
	@echo "Generating $@ for pkgconfig..."
	@echo prefix=$(PREFIX) > $@
	@echo exec_prefix=\$${prefix} >> $@
	@echo libdir=$(PREFIX)/$(LIBRARY_PATH) >> $@
	@echo includedir=$(PREFIX)/$(INCLUDE_PATH) >> $@
	@echo >> $@
	@echo Name: $(TARGET) >> $@
	@echo Description: TLS socket library for libdill. >> $@
	@echo Requires.private: libdill libtls >> $@
	@echo Version: $(PKG_VERSION) >> $@
	@echo Libs: -L\$${libdir} -lbtls >> $@
	@echo Libs.private: -ldill -ltls >> $@
	@echo Cflags: -I\$${includedir} >> $@

.PHONY: all install package
