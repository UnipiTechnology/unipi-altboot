#!/bin/sh

#mkdir -p ${DESTDIR}/etc/systemd/network
#touch ${DESTDIR}/etc/systemd/network/99-default.link

. /usr/share/initramfs-tools/hook-functions
copy_exec /usr/bin/fw_printenv
copy_exec /usr/bin/fw_setenv
if copy_file file /etc/fw_env.config ; then
:
fi
if copy_file file /etc/uboot-initial.env ; then
:
fi
