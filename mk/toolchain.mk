ifeq ($(strip $(TOOLCHAIN_PATH)),)

TOOLCHAIN_URLDIR := https://skarnet.org/toolchains/cross

TOOLCHAIN_SUFFIX := $(shell grep -E ^$(ARCH)[[:blank:]] conf/toolchains | { read a b; echo "$$b"; })
ifeq ($(TOOLCHAIN_SUFFIX),)
$(error Unsupported ARCH variable: $(ARCH). Check conf/toolchains for supported ones.)
endif

TOOLCHAIN_PATH := $(OUTPUT)/sources/$(ARCH)_$(TOOLCHAIN_SUFFIX)-$(TOOLCHAIN_VERSION)

$(TOOLCHAIN_PATH).tar.xz:
	exec mkdir -p $(OUTPUT)/sources
	cd $(OUTPUT)/sources && $(DL_CMD) $(TOOLCHAIN_URLDIR)/$(ARCH)_$(TOOLCHAIN_SUFFIX)-$(TOOLCHAIN_VERSION).tar.xz

$(TOOLCHAIN_PATH)/bin/$(ARCH)-gcc: $(TOOLCHAIN_PATH).tar.xz
	cd $(OUTPUT)/sources && tar -Jxpvf $(ARCH)_$(TOOLCHAIN_SUFFIX)-$(TOOLCHAIN_VERSION).tar.xz
	exec touch $(TOOLCHAIN_PATH)/bin/$(ARCH)-gcc

endif
