# unipi-altboot

Alternate 'rescue' boot for Unipi Patron (Zulu based) PLC, Unipi G1xx
and Unipi Edge gateways.
Usually invoked by pushing button on PLC during early boot process.
Load linux kernel and only initramdisk without any mounted storage.
Init script starts network on eth0 (dhcp + 192.168.200.200)

Runs ttyd (https://github.com/tsl0922/ttyd) - terminal over web on tcp/443
Runs swupdate (https://github.com/sbabic/swupdate) with https interface on tcp/88

