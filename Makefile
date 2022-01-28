it: all

include conf/defaults.mk

ifeq ($(strip $(OUTPUT)),)
OUTPUT := output
endif
OUTPUT := $(abspath $(OUTPUT))
HW := $(if $(findstring $(ARCH),arm-linux-musleabihf),armhf,$(firstword $(subst -, ,$(ARCH))))

include conf/versions
include mk/toolchain.mk
include mk/bearssl.mk
include mk/skaware.mk

.PHONY: it distclean clean all

distclean:
	exec rm -rf $(OUTPUT)

clean:
	ls -1 $(OUTPUT) | grep -vF sources | while read a ; do rm -rf $(OUTPUT)/"$$a" & : ; done ; true

all: rootfs-overlay-arch-tarball symlinks-overlay-arch-tarball rootfs-overlay-noarch-tarball symlinks-overlay-noarch-tarball syslogd-overlay-noarch-tarball


.PHONY: rootfs-overlay-arch rootfs-overlay-arch-tarball
rootfs-overlay-arch: $(OUTPUT)/rootfs-overlay-$(ARCH)/package/admin/execline/command/execlineb
rootfs-overlay-arch-tarball: $(OUTPUT)/s6-overlay-$(HW)-$(VERSION).tar.xz

$(OUTPUT)/rootfs-overlay-$(ARCH)/package/admin/execline/command/execlineb: skaware-install
	exec rm -rf $(OUTPUT)/rootfs-overlay-$(ARCH)
	exec mkdir -p $(OUTPUT)/rootfs-overlay-$(ARCH)
	exec cp -a $(OUTPUT)/staging-$(ARCH)/package $(OUTPUT)/staging-$(ARCH)/command $(OUTPUT)/rootfs-overlay-$(ARCH)/
	exec rm -rf $(OUTPUT)/rootfs-overlay-$(ARCH)/package/*/*/include $(OUTPUT)/rootfs-overlay-$(ARCH)/package/*/*/library

$(OUTPUT)/s6-overlay-$(HW)-$(VERSION).tar.xz: rootfs-overlay-arch
	exec rm -f $@.tmp
	cd $(OUTPUT)/rootfs-overlay-$(ARCH) && tar -Jcvf $@.tmp --owner=0 --group=0 --numeric-owner .
	exec mv -f $@.tmp $@

.PHONY: symlinks-overlay-arch symlinks-overlay-arch-tarball
symlinks-overlay-arch: $(OUTPUT)/symlinks-overlay-arch/usr/bin/execlineb
symlinks-overlay-arch-tarball: $(OUTPUT)/s6-overlay-symlinks-arch-$(VERSION).tar.xz

$(OUTPUT)/symlinks-overlay-arch/usr/bin/execlineb: rootfs-overlay-arch
	exec rm -rf $(OUTPUT)/symlinks-overlay-arch
	exec mkdir -p $(OUTPUT)/symlinks-overlay-arch/usr/bin
	for i in `ls -1 $(OUTPUT)/rootfs-overlay-$(ARCH)/command` ; do ln -s "../../command/$$i" $(OUTPUT)/symlinks-overlay-arch/usr/bin/ ; done

$(OUTPUT)/s6-overlay-symlinks-arch-$(VERSION).tar.xz: symlinks-overlay-arch
	exec rm -f $@.tmp
	cd $(OUTPUT)/symlinks-overlay-arch && tar -Jcvf $@.tmp --owner=0 --group=0 --numeric-owner .
	exec mv -f $@.tmp $@

.PHONY: rootfs-overlay-noarch rootfs-overlay-noarch-tarball
rootfs-overlay-noarch: $(OUTPUT)/rootfs-overlay-noarch/init
rootfs-overlay-noarch-tarball: $(OUTPUT)/s6-overlay-noarch-$(VERSION).tar.xz

TMPDIR1 := $(OUTPUT)/rootfs-overlay-noarch.tmp

$(OUTPUT)/rootfs-overlay-noarch/init: layout/rootfs-overlay/init
	exec rm -rf $(TMPDIR1)
	exec mkdir -p $(OUTPUT)
	exec cp -a layout/rootfs-overlay $(TMPDIR1)
	find $(TMPDIR1) -type f -name .empty -print | xargs rm -f --
	find $(TMPDIR1) -name '*@VERSION@*' -print | while read name ; do mv -f "$$name" `echo "$$name" | sed -e 's/@VERSION@/$(VERSION)/'` ; done
	find $(TMPDIR1) -type f -size +0c -print | xargs sed -i -e 's|@SHEBANGDIR@|$(SHEBANGDIR)|g; s/@VERSION@/$(VERSION)/g;' --
	exec ln -s s6-overlay-$(VERSION) $(TMPDIR1)/package/admin/s6-overlay
	exec mv -f $(TMPDIR1) $(OUTPUT)/rootfs-overlay-noarch

$(OUTPUT)/s6-overlay-noarch-$(VERSION).tar.xz: rootfs-overlay-noarch
	exec rm -f $@.tmp
	cd $(OUTPUT)/rootfs-overlay-noarch && tar -Jcvf $@.tmp --owner=0 --group=0 --numeric-owner .
	exec mv -f $@.tmp $@

.PHONY: symlinks-overlay-noarch symlinks-overlay-noarch-tarball
symlinks-overlay-noarch: $(OUTPUT)/symlinks-overlay-noarch/usr/bin/printcontenv
symlinks-overlay-noarch-tarball: $(OUTPUT)/s6-overlay-symlinks-noarch-$(VERSION).tar.xz

$(OUTPUT)/symlinks-overlay-noarch/usr/bin/printcontenv: rootfs-overlay-noarch
	exec rm -rf $(OUTPUT)/symlinks-overlay-noarch
	exec mkdir -p $(OUTPUT)/symlinks-overlay-noarch/usr/bin
	for i in `ls -1 $(OUTPUT)/rootfs-overlay-noarch/command` ; do ln -s "../../command/$$i" $(OUTPUT)/symlinks-overlay-noarch/usr/bin/ ; done

$(OUTPUT)/s6-overlay-symlinks-noarch-$(VERSION).tar.xz: symlinks-overlay-noarch
	exec rm -f $@.tmp
	cd $(OUTPUT)/symlinks-overlay-noarch && tar -Jcvf $@.tmp --owner=0 --group=0 --numeric-owner .
	exec mv -f $@.tmp $@

.PHONY: syslogd-overlay-noarch syslogd-overlay-noarch-tarball
syslogd-overlay-noarch: $(OUTPUT)/syslogd-overlay-noarch/etc/s6-overlay/s6-rc.d/syslogd/run
syslogd-overlay-noarch-tarball: $(OUTPUT)/syslogd-overlay-noarch-$(VERSION).tar.xz

TMPDIR2 := $(OUTPUT)/syslogd-overlay-noarch.tmp

$(OUTPUT)/syslogd-overlay-noarch/etc/s6-overlay/s6-rc.d/syslogd/run: layout/syslogd-overlay/etc/s6-overlay/s6-rc.d/syslogd/run
	exec rm -rf $(TMPDIR2)
	exec mkdir -p $(OUTPUT)
	exec cp -a layout/syslogd-overlay $(TMPDIR2)
	find $(TMPDIR2) -type f -name .empty -print | xargs rm -f --
	find $(TMPDIR2) -name '*@VERSION@*' -print | while read name ; do mv -f "$$name" `echo "$$name" | sed -e 's/@VERSION@/$(VERSION)/'` ; done
	find $(TMPDIR2) -type f -size +0c -print | xargs sed -i -e 's|@SHEBANGDIR@|$(SHEBANGDIR)|g; s/@VERSION@/$(VERSION)/g;' --
	exec mv -f $(TMPDIR2) $(OUTPUT)/syslogd-overlay-noarch

$(OUTPUT)/syslogd-overlay-noarch-$(VERSION).tar.xz: syslogd-overlay-noarch
	exec rm -f $@.tmp
	cd $(OUTPUT)/syslogd-overlay-noarch && tar -Jcvf $@.tmp --owner=0 --group=0 --numeric-owner .
	exec mv -f $@.tmp $@
