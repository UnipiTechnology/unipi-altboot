#!/bin/sh


TRAILING_STR=$(date +%s)
mkdir -p /tmp/__root
if blkid -p -o export /dev/root0part | grep -q '^TYPE=btrfs'; then
    mount -t btrfs /dev/root0part -o subvol=/rootfs /tmp/__root
else
    mount /dev/root0part /tmp/__root
fi

# Install default setting for ifupdown type network
if [ -L /tmp/__root/etc/systemd/system/multi-user.target.wants/networking.service ]; then
    mkdir -p /tmp/__root/etc/network
    if cd /tmp/__root/etc/network; then
        if [ -f interfaces ]; then
            cp interfaces interfaces."${TRAILING_STR}" # Backup old file
        fi
        cat > interfaces <<EOF
# interfaces(5) file used by ifup(8) and ifdown(8)
# Include files from /etc/network/interfaces.d:
source-directory /etc/network/interfaces.d
EOF
        mkdir -p interfaces.d
        if cd interfaces.d; then
            for f in $(ls -1 -- * 2> /dev/null ); do
                mv "${f}"  ".${f}.${TRAILING_STR}" # Backup old file
            done
            cat > eth0 <<EOF
allow-hotplug eth0
iface eth0 inet static
	address 192.168.200.200
	netmask 255.255.255.0
	gateway 192.168.200.1
	dns-nameservers 8.8.8.8
EOF
        fi
    fi
fi

# Install default setting for systemd-networkd type network
if [ -L /tmp/__root/etc/systemd/system/multi-user.target.wants/systemd-networkd.service ]; then
    mkdir -p /tmp/__root/etc/systemd/network
    if cd /tmp/__root/etc/systemd/network; then
        for f in $(ls -1 -- *.network *.link *.netdev 2> /dev/null ); do
            mv "${f}"  ".${f}.${TRAILING_STR}" # Backup old file
        done
        ln -s /dev/null 99-default.link
        cat > 10-wired.network <<EOF
[Match]
Name=eth0

[Network]
DNS=8.8.8.8
Address=192.168.200.200/24
Gateway=192.168.200.1
EOF
    fi
fi

cd / || exit
umount /tmp/__root
rmdir /tmp/__root
