#!/bin/sh


TRAILING_STR=$(date +%s)
mkdir -p /tmp/__root
if blkid -p -o export /dev/root0part | grep -q '^TYPE=btrfs'; then
    mount -t btrfs /dev/root0part -o subvol=/rootfs /tmp/__root
else
    mount /dev/root0part /tmp/__root
fi

# Install default setting for systemd-networkd type network
if ! [ -L /tmp/__root/etc/systemd/system/multi-user.target.wants/systemd-networkd.service ]; then
    # enable systemd-networkd
    ln -s /usr/lib/systemd/system/systemd-networkd.service /tmp/__root/etc/systemd/system/multi-user.target.wants
fi
mkdir -p /tmp/__root/etc/systemd/network
if cd /tmp/__root/etc/systemd/network; then
    for f in $(ls -1 -- *.network *.link *.netdev 2> /dev/null); do
        mv "${f}"  ".${f}.${TRAILING_STR}" # Backup old file
    done
    ln -s /dev/null 73-usb-net-by-mac.link
    ln -s /dev/null 99-default.link
    cat > 10-eth.network <<EOF
[Match]
Name=eth*

[Network]
Bridge=br0
EOF
    cat > 10-br0.network <<EOF
[Match]
Name=br0

[Network]
DHCP=ipv4
EOF
    cat > 10-br0.netdev <<EOF
[NetDev]
Name=br0
Kind=bridge
EOF
fi

cd / || exit
umount /tmp/__root
rmdir /tmp/__root
