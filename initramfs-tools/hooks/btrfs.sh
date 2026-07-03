#!/bin/sh

. /usr/share/initramfs-tools/hook-functions
copy_exec /bin/btrfs
# the mkfs.btrfs binary was in /bin in buster, but since bullseye it resides in /sbin
if [ -f /bin/mkfs.btrfs ]; then
    copy_exec /bin/mkfs.btrfs
else
    copy_exec /sbin/mkfs.btrfs
fi
