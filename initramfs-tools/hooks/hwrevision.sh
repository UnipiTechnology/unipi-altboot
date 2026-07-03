#!/bin/sh

# Create HWREVISION  file for swupdate

mkdir -p ${DESTDIR}/etc
echo "${HWREVISION}" > ${DESTDIR}/etc/hwrevision
