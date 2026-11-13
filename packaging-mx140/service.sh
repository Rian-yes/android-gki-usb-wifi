#!/system/bin/sh
# service.sh - Magisk/KernelSU late-load service for Samsung Exynos 1380 (MX140)
# Swaps stock in-tree scsc_wlan with monitor-mode + raw-injection patched driver.

MODDIR="${0%/*}"
KMOD="$MODDIR/modules"
LOG="$MODDIR/load.log"
log() { echo "$(date '+%H:%M:%S') $*" >> "$LOG"; }
: > "$LOG"

# 1) Wait for boot completion
n=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ $n -lt 150 ]; do
    sleep 2
    n=$((n+1))
done
sleep 3

# 2) Gracefully bring down Wi-Fi interfaces if active
ip link set wlan0 down 2>/dev/null
ip link set swlan0 down 2>/dev/null
ip link set mon0 down 2>/dev/null
ip link set wlan0mon down 2>/dev/null

# 3) Unload stock in-tree scsc_wlan from RAM
if lsmod | grep -q "^scsc_wlan "; then
    log "Unloading stock scsc_wlan driver..."
    rmmod scsc_wlan 2>/dev/null
fi

# 4) Load patched scsc_wlan.ko
if [ -f "$KMOD/scsc_wlan.ko" ]; then
    log "Loading patched scsc_wlan.ko..."
    insmod "$KMOD/scsc_wlan.ko" 2>>"$LOG"
    if lsmod | grep -q "^scsc_wlan "; then
        log "Patched scsc_wlan successfully loaded into kernel!"
    else
        log "ERROR: insmod scsc_wlan.ko failed"
        exit 1
    fi
else
    log "ERROR: $KMOD/scsc_wlan.ko not found"
    exit 1
fi

# 5) Auto-start wlan0mon if requested
AUTOMON="$MODDIR/automonitor"
[ -f "$AUTOMON" ] || echo 0 > "$AUTOMON"

if [ "$(cat "$AUTOMON" 2>/dev/null)" = "1" ]; then
    log "Auto-monitor requested: creating wlan0mon..."
    IW=/data/data/com.termux/files/usr/bin/iw
    export LD_LIBRARY_PATH=/data/data/com.termux/files/usr/lib
    $IW phy phy0 interface add wlan0mon type monitor 2>/dev/null
    ip link set wlan0mon up 2>/dev/null
    log "wlan0mon is UP in monitor mode"
fi

log "service.sh complete - Samsung MX140 monitor driver active"
