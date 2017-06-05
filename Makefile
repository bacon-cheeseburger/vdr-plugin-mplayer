#
# Makefile for Frontend Status Monitor plugin
#

# The official name of this plugin.
# This name will be used in the '-P...' option of VDR to load the plugin.
# By default the main source file also carries this name.

PLUGIN = mplayer

### The version number of this plugin (taken from the main source file):

#VERSION = $(shell grep 'define PLUGIN_RELEASE' version.h | awk '{ print $$3 }' | sed -e 's/[";]//g')
VERSION = $(shell grep 'static const char VERSION\[\] *=' $(PLUGIN).c | awk '{ print $$6 }' | sed -e 's/[";]//g')
GITTAG  = $(shell git describe --always 2>/dev/null)

### The directory environment:

# Use package data if installed...otherwise assume we're under the VDR source directory:
PKGCFG = $(if $(VDRDIR),$(shell pkg-config --variable=$(1) $(VDRDIR)/vdr.pc),$(shell PKG_CONFIG_PATH="$$PKG_CONFIG_PATH:../../.." pkg-config --variable=$(1) vdr))
LIBDIR = $(call PKGCFG,libdir)
LOCDIR = $(call PKGCFG,locdir)
PLGCFG = $(call PKGCFG,plgcfg)
#
TMPDIR ?= /tmp

### The compiler options:

export CFLAGS   = $(call PKGCFG,cflags)
export CXXFLAGS = $(call PKGCFG,cxxflags)
STRIP           ?= /bin/true

### The version number of VDR's plugin API:

APIVERSION = $(call PKGCFG,apiversion)

### Allow user defined options to overwrite defaults:

-include $(PLGCFG)

### The name of the distribution archive:

ARCHIVE = $(PLUGIN)-$(VERSION)
PACKAGE = vdr-$(ARCHIVE)

### The name of the shared object file:

SOFILE = libvdr-$(PLUGIN).so

### Includes and Defines (add further entries here):

INCLUDES +=

DEFINES += -DPLUGIN_NAME_I18N='"$(PLUGIN)"' -D_GNU_SOURCE

ifneq ($(strip $(GITTAG)),)
DEFINES += -DGITVERSION='"-GIT-$(GITTAG)"'
endif

.PHONY: all all-redirect
all-redirect: all

### The object files (add further files here):

OBJS = $(PLUGIN).o data.o menu.o setup-mplayer.o player-mplayer.o

### The main target:

all: $(SOFILE) i18n

### Implicit rules:

%.o: %.c
	@echo CC $@
	$(Q)$(CXX) $(CXXFLAGS) -c $(DEFINES) $(INCLUDES) -o $@ $<

### Dependencies:

MAKEDEP = $(CXX) -MM -MG
DEPFILE = .dependencies
##DEPFILES = $(subst i18n.c,,$(subst version.c,,$(OBJS:%.o=%.c) $(OBJS2:%.o=%.c)))
#DEPFILES = $(subst i18n.c,,$(subst version.c,,$(OBJS:%.o=%.c)))
$(DEPFILE): Makefile
#$(DEPFILE): Makefile $(DEPFILES) $(wildcard *.h)
	$(Q)$(MAKEDEP) $(CXXFLAGS) $(DEFINES) $(INCLUDES) $(OBJS:%.o=%.c) > $@
##	$(Q)$(MAKEDEP) $(CXXFLAGS) $(DEFINES) $(INCLUDES) $(subst i18n.c,,$(subst version.c,,$(OBJS2:%.o=%.c))) > $@
#	$(Q)$(MAKEDEP) $(CXXFLAGS) $(DEFINES) $(INCLUDES) $(DEPFILES) > $@

-include $(DEPFILE)

### Internationalization (I18N):

PODIR     = po
I18Npo    = $(wildcard $(PODIR)/*.po)
I18Nmo    = $(addsuffix .mo, $(foreach file, $(I18Npo), $(basename $(file))))
I18Nmsgs  = $(addprefix $(DESTDIR)$(LOCDIR)/, $(addsuffix /LC_MESSAGES/vdr-$(PLUGIN).mo, $(notdir $(foreach file, $(I18Npo), $(basename $(file))))))
I18Npot   = $(PODIR)/$(PLUGIN).pot

%.mo: %.po
	@echo MO $@
	$(Q)msgfmt -c -o $@ $<

$(I18Npot): $(wildcard *.c)
	@echo GT $@
	$(Q)xgettext -C -cTRANSLATORS --no-wrap --no-location -k -ktr -ktrNOOP --package-name=vdr-$(PLUGIN) --package-version=$(VERSION) --msgid-bugs-address='<see README>' -o $@ `ls $^`

%.po: $(I18Npot)
	@echo PO $@
	$(Q)msgmerge -U --no-wrap --no-location --backup=none -q -N $@ $<
	@touch $@

$(I18Nmsgs): $(DESTDIR)$(LOCDIR)/%/LC_MESSAGES/vdr-$(PLUGIN).mo: $(PODIR)/%.mo
	@echo IN $@
	$(Q)install -D -m644 $< $@

.PHONY: i18n
i18n: $(I18Nmo) $(I18Npot)

install-i18n: $(I18Nmsgs)

### Targets:

$(SOFILE): $(OBJS)
	@echo LD $@
	$(Q)$(CXX) $(CXXFLAGS) $(LDFLAGS) -shared $(OBJS) -o $@
	$(Q)$(STRIP) $@

#version.c: FORCE
#	@echo >$@.new "/* this file will be overwritten without warning */"; \
#	echo >>$@.new 'const char *PluginVersion =' '"'$(VERSION)'";'; \
#	diff $@.new $@ >$@.diff 2>&1; \
#	if test -s $@.diff; then mv -f $@.new $@; fi; \
#	rm -f $@.new $@.diff;

FORCE:

install-lib: $(SOFILE)
	@echo IN $(DESTDIR)$(LIBDIR)/$^.$(APIVERSION)
	$(Q)install -D $^ $(DESTDIR)$(LIBDIR)/$^.$(APIVERSION)

install: install-lib install-i18n

dist: $(I18Npo) clean
	@-rm -rf $(TMPDIR)/$(ARCHIVE)
	@mkdir $(TMPDIR)/$(ARCHIVE)
	@cp -a * $(TMPDIR)/$(ARCHIVE)
	@tar czf $(PACKAGE).tgz -C $(TMPDIR) $(ARCHIVE)
	@-rm -rf $(TMPDIR)/$(ARCHIVE)
	@echo Distribution package created as $(PACKAGE).tgz

clean:
	@-rm -f $(PODIR)/*.mo $(PODIR)/*.pot
	@-rm -f $(OBJS) $(DEPFILE) *.so *.tgz core* *~

.PHONY: cppcheck
cppcheck:
	$(Q)cppcheck --language=c++ --enable=all -v -f $(OBJS:%.o=%.c)
