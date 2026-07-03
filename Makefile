
### REQUIRES to setup KERNEL and KERNEL_VER

#KERNEL = vmlinux-$(KERNEL_VER)
INITRAMDISK = initrd.img-$(KERNEL_VER)


ifeq ($(shell echo "$${PRODUCT}"),neuron64u)
DTB = altboot.dtbo
BOOT_TEMPLATE = boot.edge.template
export HWREVISION=neuron 1.0
else
ifeq ($(shell echo "$${PRODUCT}"),edge)
DTB = altboot.dtbo
BOOT_TEMPLATE = boot.edge.template
export HWREVISION=$(PRODUCT) 1.0
else
DTB_ALTBOOT = unipi-$(PRODUCT)-altboot.dtb
DTB = unipi-$(PRODUCT).dtb
BOOT_TEMPLATE = boot.template
export HWREVISION=$(PRODUCT) 1.0
endif
endif


PKG_KERNEL = /boot/$(KERNEL)
PKG_DTB = $(DTB)

SRC = $(BOOT_TEMPLATE)

ALTSRC  = README
ALTSRC += boot.cmd
ALTSRC += boot.scr
ALTSRC += $(PKG_KERNEL)
ALTSRC += $(INITRAMDISK)
ALTSRC += $(PKG_DTB)


WEBAPP = build/webapp.tar.gz
TTYD = ttyd/build/ttyd
BUSYBOX = busybox/busybox
SWUPDATE = swupdate/swupdate
CPIO_BUILDER = /usr/bin/cpio-builder

.PHONY: all clean install ttyd swupdate initrd webapp

all: $(ALTSRC)

boot.cmd: $(BOOT_TEMPLATE)
	@sed "s/#KERNEL#/$(KERNEL)/g;s/#INITRAMDISK#/$(INITRAMDISK)/g" $(BOOT_TEMPLATE) >$@ || rm $@

%.scr: %.cmd
	mkimage -C none -A arm -T script -d $< $@

%.dtb:
	gzip -cd /usr/share/doc/unipi-kernel/$(DTB_ALTBOOT).gz > $(PKG_DTB) || cp /boot/$(DTB) .

altboot.dtbo:
	cp /boot/overlays/altboot.dtbo .

# use cpio with dereference and set root:root as owner - goes to FAT fs
$(CPIO_IMG): $(SRC_ALT) $(SRC)
	@for i in $^; do echo $$i; done | cpio -ov -H newc -L -R 0:0 > _tmp_ || (rm _tmp_ && false);
	@gzip - <_tmp_ > $@
	@rm _tmp_


cleanwebapp:
	@rm -rf build

$(WEBAPP):
	@set -e; cd webapp; make; make install DESTDIR=../build

webapp: $(WEBAPP)


clean:
	-@rm -f boot.scr boot.cmd 
	-@rm -f $(DTB)
	-@rm -f uboot-initial.env uboot.env
	-@rm -f initrd.img-*
	-@rm -rf build/boot
	-@cd ttyd && rm -rf build
	-@cd swupdate &&  [ -r Makefile ] && make clean
	-@cd webapp && [ -r Makefile ] &&  make clean

$(SWUPDATE): 
	@test -e swupdate/.git || { echo "Git submodule swupdate is not initialized" >&2; exit 1; }
	@cp swupdate.config swupdate/.config
	@cd swupdate; [ -f .patch.applied ] || ( patch -p 1 <../swupdate.patch && touch .patch.applied )
	@#cd swupdate; [ -f .patch2.applied ] || ( patch -p 1 <../swupdate-hw.patch && touch .patch2.applied )
	@cd swupdate; if [ "$${PRODUCT}" = "g1" ]; then patch -p 1 <../swupdate-g1.patch; fi
	@( cd swupdate; make scripts_basic; make -j 4 )

$(TTYD):
	@test -e ttyd/.git || { echo "Git submodule ttyd is not initialized" >&2; exit 1; }
	@set -e; cd ttyd; mkdir -p build; cd build; cmake ..; make

$(BUSYBOX):
	@test -e busybox/.git || { echo "Git submodule busybox is not initialized" >&2; exit 1; }
	@cp busybox.config busybox/configs/altboot_defconfig
	@set -e; cd busybox; make altboot_defconfig; make -j 4


swupdate: $(SWUPDATE) 

ttyd:  $(TTYD)

$(CPIO_BUILDER):
	cd cpio-builder && ./autogen.sh && ./configure --prefix=/usr && make && make install

initrd: $(INITRAMDISK)

$(INITRAMDISK): ttyd swupdate $(CPIO_BUILDER) $(WEBAPP) $(BUSYBOX)
	install -m 755 $(BUSYBOX) /usr/bin
	. ./initramfs-tools/ initramfs.conf; \
	mkinitramfs -o  $@ "$(KERNEL_VER)" -d ./initramfs-tools

install: 
	install -d "$(DESTDIR)/boot/altboot"
	install $(ALTSRC) "$(DESTDIR)/boot/altboot"
	if [ -r /boot/*.compatible ]; then \
	    install /boot/*.compatible "$(DESTDIR)/boot/altboot"; \
	fi

