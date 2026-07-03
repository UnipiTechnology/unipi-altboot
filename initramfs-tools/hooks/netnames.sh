#!/bin/sh

mkdir -p ${DESTDIR}/etc/systemd/network
touch ${DESTDIR}/etc/systemd/network/73-usb-net-by-mac.link
touch ${DESTDIR}/etc/systemd/network/99-default.link
