#!/bin/sh

mount | grep "/tmp/__usb" && "umount /tmp/__usb"

mkdir -p /tmp/__usb

i=0
while [ $i -le 15 ]; do
    # find partition 1 on usb storage except internal ssd on zulu usb port [0]
    dev=$(find /dev/disk/by-path -type l -name '*-usb-*part1' ! -name 'platform-ci_hdrc.0-*' | head -1)
    if [ -n "$dev" ]; then
        dev=$(readlink -f "$dev")
        if mount "$dev" /tmp/__usb; then
            exit 0
        fi
    fi
    sleep 1
    i=$((i + 1))
done
exit 1
