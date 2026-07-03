#!/bin/sh

. /usr/share/initramfs-tools/hook-functions

mkdir -p ${DESTDIR}/opt/swu/
copy_exec swupdate/swupdate /opt/swu/swupdate
copy_exec /usr/lib/aarch64-linux-gnu/libgcc_s.so.1
if copy_file file uboot.env /boot/uboot.env ; then :; fi
if copy_file file build/webapp.tar.gz /opt/swu/webapp.tar.gz ; then :; fi
copy_exec /usr/bin/pwgen
copy_exec /usr/bin/openssl
if copy_file file /etc/ssl/openssl.cnf /usr/lib/ssl/openssl.cnf ; then :; fi
