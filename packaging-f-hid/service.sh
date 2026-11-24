#!/system/bin/sh
# service.sh - Magisk/KernelSU late_start service for Patched USB HID Gadget
# Loads the hotplug-safe f_hid driver on Samsung Exynos 1380 GKI 5.15

MODDIR="${0%/*}"
KMOD="$MODDIR/modules"
LOG="/data/local/tmp/f_hid_load.log"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG"; }
: > "$LOG"
log "f_hid_fix service starting..."

# 1) Wait for system boot completion
n=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ $n -lt 120 ]; do
    sleep 2
    n=$((n+1))
done

# 2) Load patched kernel module
if [ -f "$KMOD/usb_f_hid_fix.ko" ]; then
    log "Inserting usb_f_hid_fix.ko..."
    insmod "$KMOD/usb_f_hid_fix.ko" 2>> "$LOG" || true
fi

if [ -f "$KMOD/usb_f_hid.ko" ] && ! lsmod | grep -qE "usb_f_hid_fix|usb_f_hid"; then
    log "Inserting usb_f_hid.ko..."
    insmod "$KMOD/usb_f_hid.ko" 2>> "$LOG" || true
fi

# 3) Check driver registration
if lsmod | grep -qE "usb_f_hid"; then
    log "Patched USB HID driver loaded successfully!"
else
    log "Warning: Module insertion reported error or already built-in."
fi

log "Service finished."
