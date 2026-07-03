#!/bin/sh

if [ ! -r /scripts/functions ]; then
    # script is not running from initramdisk
    exit 0
fi

if echo "${bootdev:-}" | grep -q "mmc"; then
    exit
fi

#. /scripts/init-premount/fix-fdisk.sh.in
. /scripts/init-premount/ledfunc.sh.in
setled_deploy_mode

# mount tmpfs if not mounted
mount | grep -q "/tmp" || mount -o mode=1777,nosuid,nodev -t tmpfs tmpfs /tmp

if [ ! -d /opt/swupdate ]; then
    . /scripts/functions
    wait_for_udev 10
    . /scripts/init-premount/hwcheck.sh.in

    #configure_networking
    setled_deploy_mode

    ip li set up dev lo
    mounted=""
    if echo "${bootdev}" | grep -q ":"; then
        iface=eth0
        udhcpc -b -i "${iface}" -x "hostname:unipi-final-mode" -s "/scripts/init-premount/udhcp.script"
        if nfsmount -o nolock "${bootdev}" /root; then
           mounted=NFS
        fi
    else
        for _ in 0 1 2; do
            usbdev=$(find /dev/disk/by-path -type l -name '*-usb-*part1' ! -name 'platform-ci_hdrc.0-*' | head -1)
            if [ -n "$usbdev" ]; then
                usbdev=$(readlink -f "$usbdev")
                mount "$usbdev" /root  && mounted=USB && break
            fi
            sleep 3
        done
    fi

    if [ -f "/root/uboot.swu" ]; then
      if ! /opt/swu/swupdate -vi /root/uboot.swu; then
          setled_error
          while true; do sleep 1000; done
      fi
    fi

    if [ -n "${mounted}" ] && [ -f "/root/archive.zip" ]; then
      rm -f /tmp/archive.fifo 2> /dev/null
      mkfifo /tmp/archive.fifo
      7za e -so /root/archive.zip > /tmp/archive.fifo &
      if /opt/swu/swupdate -vi /tmp/archive.fifo; then
          setled_ok
      else
          setled_error
          while true; do sleep 1000; done
      fi
    fi
    rm -f /tmp/archive.fifo 2> /dev/null

    if [ -n "${mounted}" ] && [ -f "/root/archive.swu" ]; then

      if /opt/swu/swupdate -vi /root/archive.swu; then
          setled_ok
      else
          setled_error
          while true; do sleep 1000; done
      fi
    fi

    setled_reboot_mode

    sync
    sleep 0.5
    sync

    echo b >/proc/sysrq-trigger
fi
