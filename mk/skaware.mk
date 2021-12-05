SKAWARE := SKALIBS EXECLINE S6 S6_RC S6_LINUX_INIT S6_PORTABLE_UTILS S6_LINUX_UTILS S6_DNS S6_NETWORKING S6_OVERLAY_HELPERS

SKALIBS_DEPENDENCIES :=
EXECLINE_DEPENDENCIES := SKALIBS
S6_DEPENDENCIES := SKALIBS EXECLINE
S6_RC_DEPENDENCIES := SKALIBS EXECLINE S6
S6_LINUX_INIT_DEPENDENCIES := SKALIBS EXECLINE S6
S6_PORTABLE_UTILS_DEPENDENCIES := SKALIBS
S6_LINUX_UTILS_DEPENDENCIES := SKALIBS
S6_DNS_DEPENDENCIES := SKALIBS
S6_NETWORKING_DEPENDENCIES := SKALIBS EXECLINE S6 S6_DNS
S6_OVERLAY_HELPERS_DEPENDENCIES := SKALIBS EXECLINE

SKALIBS_CATEGORY := prog
EXECLINE_CATEGORY := admin
S6_CATEGORY := admin
S6_RC_CATEGORY := admin
S6_LINUX_INIT_CATEGORY := admin
S6_PORTABLE_UTILS_CATEGORY := admin
S6_LINUX_UTILS_CATEGORY := admin
S6_DNS_CATEGORY := web
S6_NETWORKING_CATEGORY := net
S6_OVERLAY_HELPERS_CATEGORY := admin

SKALIBS_TOKEN := libskarnet.a.xyzzy
EXECLINE_TOKEN := execlineb
S6_TOKEN := s6-supervise
S6_RC_TOKEN := s6-rc
S6_LINUX_INIT_TOKEN := s6-linux-init-maker
S6_PORTABLE_UTILS_TOKEN := s6-test
S6_LINUX_UTILS_TOKEN := s6-ps
S6_DNS_TOKEN := s6-dnsip4
S6_NETWORKING_TOKEN := s6-tlsd-io
S6_OVERLAY_HELPERS_TOKEN := s6-overlay-suexec

SKAWARE_OPTIONS := --enable-slashpackage --enable-static-libc --disable-shared
SKALIBS_OPTIONS := --with-default-path=/command:/usr/bin:/bin --with-sysdep-devurandom=yes
EXECLINE_OPTIONS := --disable-pedantic-posix
S6_OPTIONS :=
S6_RC_OPTIONS :=
S6_LINUX_INIT_OPTIONS :=
S6_PORTABLE_UTILS_OPTIONS :=
S6_LINUX_UTILS_OPTIONS :=
S6_DNS_OPTIONS :=
S6_NETWORKING_OPTIONS := --enable-ssl=bearssl --with-ssl-path=$(OUTPUT)/staging-$(ARCH)
S6_OVERLAY_HELPERS_OPTIONS :=

$(OUTPUT)/build-$(ARCH)/s6-networking-$(S6_NETWORKING_VERSION)/config.mak: $(OUTPUT)/staging-$(ARCH)/include/bearssl.h $(OUTPUT)/staging-$(ARCH)/lib/libbearssl.a

.PHONY: skaware-install

define skaware_rules_definition

$(1)_NAME := $(subst _,-,$(shell echo $(1) | tr A-Z a-z))
$(1)_INCLUDE_LOCATION := $(OUTPUT)/staging-$(ARCH)/package/$$($(1)_CATEGORY)/$$($(1)_NAME)/include
$(1)_LIBRARY_LOCATION := $(OUTPUT)/staging-$(ARCH)/package/$$($(1)_CATEGORY)/$$($(1)_NAME)/library

.PHONY: $$($(1)_NAME)-download $$($(1)_NAME)-prepare $$($(1)_NAME)-configure $$($(1)_NAME)-build $$($(1)_NAME)-install

$$($(1)_NAME)-download: $(OUTPUT)/sources/$$($(1)_NAME)/Makefile
$$($(1)_NAME)-prepare: $(OUTPUT)/build-$(ARCH)/$$($(1)_NAME)-$$($(1)_VERSION)/Makefile
$$($(1)_NAME)-configure: $(OUTPUT)/build-$(ARCH)/$$($(1)_NAME)-$$($(1)_VERSION)/config.mak
$$($(1)_NAME)-build: $(OUTPUT)/build-$(ARCH)/$$($(1)_NAME)-$$($(1)_VERSION)/$$($(1)_TOKEN)
$$($(1)_NAME)-install: $(OUTPUT)/staging-$(ARCH)/package/$$($(1)_CATEGORY)/$$($(1)_NAME)/include/$$($(1)_NAME)/config.h

$(OUTPUT)/sources/$$($(1)_NAME)/Makefile:
	exec rm -rf $(OUTPUT)/sources/$$($(1)_NAME)
	exec mkdir -p $(OUTPUT)/sources
	cd $(OUTPUT)/sources && git clone $$(if $(filter S6_OVERLAY_%,$(1)),https://github.com/just-containers/$$($(1)_NAME).git,git://git.skarnet.org/$$($(1)_NAME))
	exec touch $$@

$(OUTPUT)/build-$(ARCH)/$$($(1)_NAME)-$$($(1)_VERSION)/Makefile: $(OUTPUT)/sources/$$($(1)_NAME)/Makefile
	exec rm -rf $(OUTPUT)/build-$(ARCH)/$$($(1)_NAME)-$$($(1)_VERSION)
	exec mkdir -p $(OUTPUT)/build-$(ARCH)
	exec cp -a $(OUTPUT)/sources/$$($(1)_NAME) $(OUTPUT)/build-$(ARCH)/$$($(1)_NAME)-$$($(1)_VERSION)
	cd $(OUTPUT)/build-$(ARCH)/$$($(1)_NAME)-$$($(1)_VERSION) && git checkout $$($(1)_VERSION) && rm -rf .git
	exec touch $$@

$(OUTPUT)/build-$(ARCH)/$$($(1)_NAME)-$$($(1)_VERSION)/config.mak: $(TOOLCHAIN_PATH)/bin/$(ARCH)-gcc $(OUTPUT)/build-$(ARCH)/$$($(1)_NAME)-$$($(1)_VERSION)/Makefile $$(foreach dep,$$($(1)_DEPENDENCIES),$(OUTPUT)/staging-$(ARCH)/package/$$($$(dep)_CATEGORY)/$$($$(dep)_NAME)/include/$$($$(dep)_NAME)/config.h)
	cd $(OUTPUT)/build-$(ARCH)/$$($(1)_NAME)-$$($(1)_VERSION) && env "PATH=$(TOOLCHAIN_PATH)/bin:$$(PATH)" "DESTDIR=$(OUTPUT)/staging-$(ARCH)" ./configure --target=$(ARCH) $(SKAWARE_OPTIONS) $$($(1)_OPTIONS)

$(OUTPUT)/build-$(ARCH)/$$($(1)_NAME)-$$($(1)_VERSION)/$$($(1)_TOKEN): $(TOOLCHAIN_PATH)/bin/$(ARCH)-gcc $(OUTPUT)/build-$(ARCH)/$$($(1)_NAME)-$$($(1)_VERSION)/config.mak
	cd $(OUTPUT)/build-$(ARCH)/$$($(1)_NAME)-$$($(1)_VERSION) && env "PATH=$(TOOLCHAIN_PATH)/bin:$$(PATH)" $(MAKE) && env "PATH=$(TOOLCHAIN_PATH)/bin:$$(PATH)" $(MAKE) strip

$(OUTPUT)/staging-$(ARCH)/package/$$($(1)_CATEGORY)/$$($(1)_NAME)/include/$$($(1)_NAME)/config.h: $(OUTPUT)/build-$(ARCH)/$$($(1)_NAME)-$$($(1)_VERSION)/$$($(1)_TOKEN)
	cd $(OUTPUT)/build-$(ARCH)/$$($(1)_NAME)-$$($(1)_VERSION) && env "PATH=$(TOOLCHAIN_PATH)/bin:$$(PATH)" $(MAKE) -L install update global-links DESTDIR=$(OUTPUT)/staging-$(ARCH)

skaware-install: $(OUTPUT)/staging-$(ARCH)/package/$$($(1)_CATEGORY)/$$($(1)_NAME)/include/$$($(1)_NAME)/config.h

endef

$(foreach pkg,$(SKAWARE),$(eval $(call skaware_rules_definition,$(pkg))))
