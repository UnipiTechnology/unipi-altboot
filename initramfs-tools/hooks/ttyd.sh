#!/bin/sh

. /usr/share/initramfs-tools/hook-functions
copy_exec ttyd/build/ttyd /opt/swu/ttyd
if copy_file file /usr/lib/aarch64-linux-gnu/libwebsockets-evlib_ev.so; then :; fi
if copy_file file /usr/lib/aarch64-linux-gnu/libwebsockets-evlib_uv.so; then :; fi
if copy_file file /usr/lib/aarch64-linux-gnu/libwebsockets.so.19; then :; fi
if copy_file file /usr/lib/aarch64-linux-gnu/libev.so.4.0.0; then :; fi
if copy_file file /usr/lib/aarch64-linux-gnu/libdl.so.2; then :; fi
