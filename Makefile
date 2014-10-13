
TARGETS=pint-config pinttop pint-export ph-stable ph-reach phc libpint ph-stat ph-exec ph2thomas

MISC_TOOLS = \
	converters/bcx2ph\
	converters/CNA2ph\
	converters/ginml2ph\
	converters/ginml2K\
	converters/K2an\
	converters/an2ph\


all: $(TARGETS)

$(TARGETS):
	make -f target/$@

%_clean:
	make -f target/$* clean

test: all
	make -f tests/Makefile
	cd tests && ./pinttests

test_clean:
	make -f tests/Makefile clean

clean: $(addsuffix _clean,$(TARGETS)) test_clean

apidoc:
	rm -f docs/api/*
	ocamldoc -sort -html -d docs/api -I bindings -I pintlib -I phlib \
		-t "Pint OCaml API" \
		bindings/r.mli pintlib/*.mli phlib/*.mli *.mli


RELNAME=$(shell date -I)
RELBRANCH=master

PREFIX=/usr
DESTDIR=

%_install: %
	make -f target/$* PREFIX=$(PREFIX) DESTDIR=$(DESTDIR) install

misc_install:
	for i in $(MISC_TOOLS); do \
		install -m 0755 $$i $(DESTDIR)$(PREFIX)/bin; \
	done

install: $(addsuffix _install,$(TARGETS)) misc_install

pre-release:
	sed -i 's/:.*##VERSION##/: "$(RELNAME)",##VERSION##/' setup.py
	DEBEMAIL="loic.pauleve@ens-cachan.org" DEBFULLNAME="Loic Pauleve" debchange -v $(RELNAME) Release $(RELNAME)
	DEBEMAIL="loic.pauleve@ens-cachan.org" DEBFULLNAME="Loic Pauleve" debchange -r --distribution unstable
	git commit -a -m "release $(RELNAME)"

release:
	git tag $(RELNAME)
	git archive -o ../pint-$(RELNAME).zip --prefix pint-$(RELNAME)/ $(RELBRANCH)

OSX_W=/tmp/osx-pint/pint-$(RELNAME)
OSX_PREFIX=/pint
OSX_SHARE=$(OSX_PREFIX)/share
OSX_ROOT=$(OSX_W)$(OSX_PREFIX)
OSX_BIN=$(OSX_ROOT)/bin
OSX_TARGETS=phc ph-stat ph-stable ph-reach ph-exec ph2thomas pint-config pint-export
OSX_DMG=../pint-$(RELNAME).dmg

# should be called using ./dist/osx/do.sh
#dist-osx: $(OXS_BINS)
dist-osx:
	-rm -rf $(OSX_W)
	make DESTDIR="$(OSX_W)" PREFIX="$(OSX_PREFIX)" \
		PINT_SHARE_PATH="$(OSX_SHARE)" \
		$(addsuffix _install,$(OSX_TARGETS)) misc_install
	#install -d $(OSX_W_BIN)
	#install -m 755 $(OSX_BINS:%=bin/%) $(MISC_TOOLS) $(OSX_W_BIN)
	install -m 644 dist/osx/*.dylib $(OSX_BIN)
	for i in $(OSX_TARGETS); do \
		install -m 755 -b -B .mac dist/osx/wrapper.sh $(OSX_BIN)/$$i; \
	done
	#install -d $(OSX_W_SHARE)/contrib/ph2thomas
	#install -m 644 contrib/ph2thomas/*.lp $(OSX_W_SHARE)/contrib/ph2thomas
	MISC_TOOLS="$(MISC_TOOLS)" ./dist/osx/gen_install.sh > $(OSX_ROOT)/install.sh
	chmod 655 $(OSX_ROOT)/install.sh
	install -d $(OSX_ROOT)/examples
	install -m 644 examples/* $(OSX_ROOT)/examples
	install -m 644 dist/osx/README $(OSX_ROOT)
	-rm -f $(OSX_DMG)
	hdiutil create -srcfolder $(OSX_W) -volname pint-$(RELNAME) -fs HFS+ $(OSX_DMG)
	-rm -rf $(OSX_W)

dist-deb:
	dpkg-buildpackage -d	

