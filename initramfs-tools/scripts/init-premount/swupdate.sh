#!/bin/sh

if [ ! -r /scripts/functions ]; then
    # script is not running from initramdisk
    exit 0
fi


if echo "${bootdev:-}" | grep -q "usb"; then
    exit
fi

#. /scripts/init-premount/fix-fdisk.sh.in
. /scripts/init-premount/ledfunc.sh.in

setled_web_mode

# mount tmpfs if not mounted
mount | grep -q "/tmp" || mount -o mode=1777,nosuid,nodev -t tmpfs tmpfs /tmp

if [ ! -d /opt/swupdate ]; then

    . /scripts/functions
    wait_for_udev 10
	# generating ssl key before hw check to wait for usb eth
    openssl req -x509 -newkey rsa:4096 -keyout /etc/key.pem -out /etc/cert.pem -sha256 -days 3650 -nodes -subj "/CN=192.168.200.200"
    . /scripts/init-premount/hwcheck.sh.in

    if [ -f /opt/swu/webapp.tar.gz ]; then ( cd /opt/swu && tar xzf webapp.tar.gz ); fi
    if [ -f /opt/swu/js_gen.sh ]; then ( cd /opt/swu && sh js_gen.sh ); fi

    #configure_networking
    hostname "$(cat /sys/firmware/devicetree/base/unipi-model)-sn$(cat /sys/firmware/devicetree/base/unipi-serial)-service-mode"
    if [ "$(hostname)" = "-sn-service-mode" ]; then
        hostname "unipi${series_name}-service-mode"
    fi
    setled_web_mode
    ip li set up dev lo
    mkdir -p /var/lib/misc
    mkdir -p /var/run
    if [ "${HAS_ETH1}" = "1" ]; then
        if brctl addbr br0 2>/dev/null; then
            if [ "${HAS_ETH0}" = "1" ]; then
                brctl addif br0 eth0 || true
                ip li set address $(cat /sys/class/net/eth0/address) dev br0 || true
                ip li set up eth0 || true
            fi
            brctl addif br0 eth1 || true
            ip li set up eth1 || true
            iface=br0
            nft -f - <<EOF
flush ruleset
table bridge filter {
  chain forward {
    type filter hook forward priority -200; policy drop;
  }
}
EOF
        fi
    elif [ "${HAS_ETH0}" = "1" ]; then
        iface=eth0
    fi
    if [ -n "${iface}" ]; then
        series_name=""
        [ "${IS_AXON}" = "1" ] && series_name="-axon"
        [ "${IS_ZULU}" = "1" ]   &&  series_name="-zulu"
        [ "${IS_G1}" = "1" ] && series_name="-gate"
        [ "${IS_RPI}" = "1" ] && series_name="-rpi"
        udhcpc -b -i "${iface}" -x "hostname:$(hostname)" -s "/scripts/init-premount/udhcp.script" # Run DHCP client on backround
        ip ad add 192.168.200.200/24 dev "${iface}" # Assign static IP
    fi

    # workaround, so the script is not loaded by hooks
    chmod +x /scripts/init-premount/sh-l.sh
    chmod +x /scripts/init-premount/login.sh

    . /scripts/init-premount/mmcfunc.sh.in
    if read_emmc_gp; then
        TTY_SH=/scripts/init-premount/login.sh
    else
        TTY_SH=/scripts/init-premount/sh-l.sh
    fi

    AUTH_DOMAIN="unipi.altboot"
    AUTH_USER="unipi"
    AUTH_PASS="$(pwgen -vn 16 1)"
    MD5=$(printf "$AUTH_USER:$AUTH_DOMAIN:$AUTH_PASS" | md5sum -t | cut -d\  -f 1)
    printf "$AUTH_USER:$AUTH_DOMAIN:$MD5\n" > /etc/htdigest

	echo 'printf "You can use this terminal to manage your device or follow these link for graphical interface:\n"' > /etc/profile

    ip ad ls | sed -n 's#^.*inet \+\([^/]\+\)/.*$#\1#p' | while read ip; do
        if [ "$ip" != "127.0.0.1" ]; then
        echo "printf '\n      \033]8;;https://%s:%s@%s:88/\033\Open SWUPDATE page on %s\033]8;;\033\\ \n\n\n' '$AUTH_USER' '$AUTH_PASS' '$ip' '$ip'"
        fi
    done >> /etc/profile

    /opt/swu/ttyd -p 443 -S -C /etc/cert.pem -K /etc/key.pem -W "${TTY_SH}" &
    nft add table ip nat
    nft add chain ip nat prerouting { type nat hook prerouting priority -100 \; }
    nft add rule ip nat prerouting tcp dport 80 redirect to 443

    cd /opt/swu && \
    exec /opt/swu/swupdate -l 3 \
         -w "-r /opt/swu -p 88 --auth-domain $AUTH_DOMAIN --global-auth-file /etc/htdigest -s -C /etc/cert.pem -K /etc/key.pem" \
         -p '/bin/sh /scripts/init-premount/reboot.sh'
fi
