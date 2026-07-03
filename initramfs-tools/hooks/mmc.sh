#!/bin/sh

. /usr/share/initramfs-tools/hook-functions
copy_exec /usr/bin/mmc usr/bin
if copy_file file /lib/firmware/imx/sdma/sdma-imx7d.bin; then :; fi
