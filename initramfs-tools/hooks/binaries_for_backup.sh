#!/bin/sh

. /usr/share/initramfs-tools/hook-functions

copy_exec "$(which pigz)"

# Be carefull with copying/renaming files in new initramfs tools
# Use full name without symlinks in directory
copy_exec "$(which cpio)" /usr/bin/cpio_with_crc
#overwrite busybox version of fdisk
[ -f ${DESTDIR}/usr/sbin/fdisk ] && rm ${DESTDIR}/usr/sbin/fdisk
copy_exec "$(which fdisk)"
copy_exec "$(which mkfs.exfat)"
copy_exec "$(which cpio-builder)"
copy_exec "$(which zip)"
copy_exec "/usr/lib/7zip/7za"
copy_exec "$(which mkfs.ext4)"
[ -f ${DESTDIR}/usr/sbin/mke2fs ] && rm ${DESTDIR}/usr/sbin/mke2fs
if copy_exec "$(which mke2fs)"; then
:
fi
