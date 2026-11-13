#!/system/bin/sh
# uninstall.sh - Cleanup on module removal
MODDIR="${0%/*}"
ip link set wlan0mon down 2>/dev/null
iw dev wlan0mon del 2>/dev/null
# Stock scsc_wlan will reload on next reboot
