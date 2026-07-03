#!/bin/sh

mkdir -p /tmp/__root
if blkid -p -o export /dev/root0part | grep -q '^TYPE=btrfs'; then
    mount -t btrfs /dev/root0part -o subvol=/rootfs /tmp/__root
else
    mount /dev/root0part /tmp/__root
fi

if cd /tmp/__root/etc/systemd/system/multi-user.target.wants 2>/dev/null; then
    rm -f evok.service
    ln -s /lib/systemd/system/evok.service evok.service
fi

cd /
umount /tmp/__root
