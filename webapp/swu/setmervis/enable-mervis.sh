#!/bin/sh

mkdir -p /tmp/__root
if blkid -p -o export /dev/root0part | grep -q '^TYPE=btrfs'; then
    mount -t btrfs /dev/root0part -o subvol=/rootfs /tmp/__root
else
    mount /dev/root0part /tmp/__root
fi

if cd /tmp/__root/etc/systemd/system/multi-user.target.wants 2>/dev/null; then
    rm -f cacert-update.service cacert-update.timer mervisconfigtool.service mervisfcgi.service mervisrt.service 
    ln -s /lib/systemd/system/mervisrt.service mervisrt.service
    ln -s /lib/systemd/system/mervisconfigtool.service mervisconfigtool.service
	ln -s /lib/systemd/system/mervisfcgi.service mervisfcgi.service
	ln -s /lib/systemd/system/cacert-update.service cacert-update.service
	ln -s /lib/systemd/system/cacert-update.timer cacert-update.timer
fi
if cd /tmp/__root/etc/nginx/sites-enabled 2>/dev/null; then
    rm -f mervis
    ln -s ../sites-available/mervis .
fi
cd /
umount /tmp/__root
