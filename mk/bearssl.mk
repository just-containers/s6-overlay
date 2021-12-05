BEARSSL_URLDIR := https://www.bearssl.org/git

.PHONY: bearssl-download bearssl-prepare bearssl-build bearssl-install

bearssl-download: $(OUTPUT)/sources/bearssl-$(BEARSSL_VERSION)/Makefile
bearssl-prepare: $(OUTPUT)/build-$(ARCH)/bearssl-$(BEARSSL_VERSION)/Makefile
bearssl-build: $(OUTPUT)/build-$(ARCH)/bearssl-$(BEARSSL_VERSION)/build/libbearssl.a
bearssl-install: $(OUTPUT)/staging-$(ARCH)/include/bearssl.h $(OUTPUT)/staging-$(ARCH)/lib/libbearssl.a

$(OUTPUT)/sources/BearSSL/Makefile:
	exec rm -rf $(OUTPUT)/sources/BearSSL
	exec mkdir -p $(OUTPUT)/sources
	cd $(OUTPUT)/sources && git clone $(BEARSSL_URLDIR)/BearSSL
	exec touch $@

$(OUTPUT)/build-$(ARCH)/bearssl-$(BEARSSL_VERSION)/inc/bearssl.h: $(OUTPUT)/sources/BearSSL/Makefile
	exec rm -rf $(OUTPUT)/build-$(ARCH)/bearssl-$(BEARSSL_VERSION)
	exec mkdir -p $(OUTPUT)/build-$(ARCH)
	exec cp -a $(OUTPUT)/sources/BearSSL $(OUTPUT)/build-$(ARCH)/bearssl-$(BEARSSL_VERSION)
	cd $(OUTPUT)/build-$(ARCH)/bearssl-$(BEARSSL_VERSION) && git checkout $(BEARSSL_VERSION)
	exec touch $@

$(OUTPUT)/build-$(ARCH)/bearssl-$(BEARSSL_VERSION)/build/libbearssl.a: $(TOOLCHAIN_PATH)/bin/$(ARCH)-gcc $(OUTPUT)/build-$(ARCH)/bearssl-$(BEARSSL_VERSION)/inc/bearssl.h
	cd $(OUTPUT)/build-$(ARCH)/bearssl-$(BEARSSL_VERSION) && $(MAKE) lib CC=$(TOOLCHAIN_PATH)/bin/$(ARCH)-gcc LD=$(TOOLCHAIN_PATH)/bin/$(ARCH)-gcc LDDLL=$(TOOLCHAIN_PATH)/bin/$(ARCH)-gcc

$(OUTPUT)/staging-$(ARCH)/include/bearssl.h: $(OUTPUT)/build-$(ARCH)/bearssl-$(BEARSSL_VERSION)/inc/bearssl.h
	exec mkdir -p $(OUTPUT)/staging-$(ARCH)/include
	exec cp -a $(OUTPUT)/build-$(ARCH)/bearssl-$(BEARSSL_VERSION)/inc/*.h $(OUTPUT)/staging-$(ARCH)/include/

$(OUTPUT)/staging-$(ARCH)/lib/libbearssl.a: $(OUTPUT)/build-$(ARCH)/bearssl-$(BEARSSL_VERSION)/build/libbearssl.a
	exec mkdir -p $(OUTPUT)/staging-$(ARCH)/lib
	exec cp -f $(OUTPUT)/build-$(ARCH)/bearssl-$(BEARSSL_VERSION)/build/libbearssl.a $(OUTPUT)/staging-$(ARCH)/lib/libbearssl.a
