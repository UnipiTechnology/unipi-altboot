
# must be run vin /bin/sh

if [ ! -d /opt/swupdate ]; then
    if [ -f /sys/bus/iogroup/devices/iogroup1/reboot ]; then
        echo 1 > /sys/bus/iogroup/devices/iogroup1/reboot || true
    fi

    sync
    sleep 0.5
    sync

    . /scripts/init-premount/ledfunc.sh.in

    setled_reboot_mode

    echo b >/proc/sysrq-trigger
fi
