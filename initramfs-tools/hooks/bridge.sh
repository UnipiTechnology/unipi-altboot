#!/bin/sh

. /usr/share/initramfs-tools/hook-functions

if copy_exec /usr/sbin/nft; then
:
fi
