#!/bin/make
# SPDX-License-Identifier: MIT

ARCH=riscv64
OUTFILE=ubuntu.ext4
RELEASE=noble
QEMUARCH=riscv64
UUID:=${shell uuidgen}

.PHONY: prepare

all:
	make umount
	make prepare
	make mount
	make install
	make umount
	make compress

$(RELEASE)-base-$(ARCH).tar.gz:
	wget https://cdimage.ubuntu.com/ubuntu-base/$(RELEASE)/daily/current/$(RELEASE)-base-$(ARCH).tar.gz

prepare: $(RELEASE)-base-$(ARCH).tar.gz
	rm -rf $(OUTFILE)
	truncate $(OUTFILE) -s 750M
	echo $(UUID)
	mkfs.ext4 -U $(UUID) -L root $(OUTFILE)
	sed -e 's|UUUUIIDD|$(uuidgen)|' customize.sh.in > customize.sh
	chmod 755 customize.sh
	mkdir -p mnt/
	sudo mount $(OUTFILE) mnt/
	sudo tar -xzf $(RELEASE)-base-$(ARCH).tar.gz -C mnt/
	sudo umount mnt/; true

mount:
	sudo mount $(OUTFILE) mnt/
	sudo mount devlive -t devtmpfs mnt/dev/
	sudo mount devptslive -t devpts mnt/dev/pts/
	sudo mount proclive -t proc mnt/proc/
	sudo mount syslive -t sysfs mnt/sys/

install:
	cp customize.sh mnt/tmp/
	sudo cp /etc/resolv.conf mnt/etc/resolv.conf
	sudo chroot mnt /tmp/customize.sh
	sudo rm mnt/tmp/customize.sh

umount:
	sync
	sudo umount mnt/sys/; true
	sudo umount mnt/proc/; true
	sudo umount mnt/dev/pts/; true
	sudo umount mnt/dev/; true
	sudo umount mnt/; true

compress:
	xz -z $(OUTFILE) --stdout > $(OUTFILE).$$(date +%Y%m%d).xz

run:
	qemu-system-$(QEMUARCH) \
	-machine virt,acpi=off \
	-m 1G \
	-nographic \
	-kernel Image \
	-append "root=/dev/vda ro" \
	-drive file=ubuntu.ext4,format=raw,id=disk1
