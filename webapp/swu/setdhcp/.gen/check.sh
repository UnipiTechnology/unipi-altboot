#!/bin/sh

test "${HAS_ETH0}" = "1" -a "${HAS_ETH1}" != "1"
