#!/system/bin/sh
# service.sh - Magisk/KernelSU late_start service for the GKI USB Wi-Fi module.
# Loads mac80211 + the USB driver the safe way (autoprobe off, then sysfs bind)
# so watchdogs cannot panic during module insertion.
#
# This file is generated into the flashable ZIP; MODDIR is the module's own dir.

MODDIR="${0%/*}"                      # this module's install dir
KMOD="$MODDIR/modules"
FW="$MODDIR/firmware"
USB_ID="__USB_ID__"                   # filled in by the build (e.g. 0bda:d723)
DRV_KO="__DRV_KO__"                   # leaf module filename (e.g. rtw_8723du.ko)
DRV_NAME="__DRV_NAME__"               # driver dir under /sys/bus/usb/drivers (e.g. rtw_8723du)

LOG="$MODDIR/load.log"
log() { echo "$(date '+%H:%M:%S') $*" >> "$LOG"; }
: > "$LOG"

# 1) wait for boot + a stable moment
n=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ $n -lt 150 ]; do sleep 2; n=$((n+1)); done
sleep 10

# Warn if more than one adapter module is enabled - they fight over wlan1.
N=$(ls -d /data/adb/modules/gki_usb_wifi_* 2>/dev/null | wc -l)
if [ "$N" -gt 1 ]; then
  log "WARNING: $N gki_usb_wifi modules are installed. Enable only the one for"
  log "         the adapter you're using, then reboot - two will conflict."
fi

# 2) Stage firmware in /data/vendor/fw with vendor_fw_file label (accessible by kernel under SELinux Enforcing)
FWDIR=/data/vendor/fw
mkdir -p "$FWDIR/rtw88"
if [ -d "$FW" ]; then
  cp -r "$FW"/* "$FWDIR/" 2>/dev/null
  cp -r "$FW"/* "$FWDIR/rtw88/" 2>/dev/null
fi
chmod -R 755 "$FWDIR"
chcon -R u:object_r:vendor_fw_file:s0 "$FWDIR" 2>/dev/null
log "firmware staged at $FWDIR"

# 3) load modules with USB autoprobe OFF so module_init never touches the HW
echo 0 > /sys/bus/usb/drivers_autoprobe 2>/dev/null
for m in "$KMOD"/mac80211.ko \
         "$KMOD"/rtw_core.ko \
         "$KMOD"/rtw_8723x.ko \
         "$KMOD"/rtw_8723d.ko \
         "$KMOD"/rtw_usb.ko \
         "$KMOD"/rtw_8723du.ko \
         "$KMOD"/*.ko ; do
  [ -e "$m" ] || continue
  base=$(basename "$m" .ko); lsn=$(echo "$base" | tr '-' '_')
  lsmod | grep -q "^$lsn " && continue
  insmod "$m" 2>/dev/null && log "loaded $base"
done
echo 1 > /sys/bus/usb/drivers_autoprobe 2>/dev/null

# 4) defragment memory for mac80211 high-order queue allocation
echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
echo 1 > /proc/sys/vm/compact_memory 2>/dev/null || true

# 5) Transient firmware path switch during USB bind (preserves camera firmware path)
bind_adapter() {
  ORIG_FW=$(cat /sys/module/firmware_class/parameters/path 2>/dev/null)
  [ -z "$ORIG_FW" ] && ORIG_FW="/vendor/firmware"
  echo "$FWDIR" > /sys/module/firmware_class/parameters/path 2>/dev/null

  for iface in /sys/bus/usb/devices/${1}:*; do
    [ -d "$iface" ] || continue
    ib=$(basename "$iface")
    echo "$ib" > "/sys/bus/usb/drivers/$DRV_NAME/bind" 2>/dev/null && log "bound $ib"
  done

  sleep 2
  echo "$ORIG_FW" > /sys/module/firmware_class/parameters/path 2>/dev/null
  log "restored firmware path to $ORIG_FW"
}

find_dev() {
  for d in /sys/bus/usb/devices/*/idProduct; do
    dir=$(dirname "$d"); [ -f "$dir/idVendor" ] || continue
    [ "$(cat "$dir/idVendor"):$(cat "$d")" = "$USB_ID" ] && { basename "$dir"; return 0; }
  done; return 1
}

dev=$(find_dev)
if [ -n "$dev" ]; then
  log "found adapter $dev, binding with transient firmware path..."
  bind_adapter "$dev"
else
  log "card not attached at boot; ready for plug-in"
fi

# 6) set monitor mode once wlan1 exists
CHROOT_BIN=/data/data/com.termux/files/usr/bin/chroot
ROOTFS=/data/local/nhsystem/kali-arm64

set_monitor_bg() {
  (
    i=0
    while [ $i -lt 300 ]; do          # up to ~10 min
      if ip link show wlan1 >/dev/null 2>&1; then
        if [ -x "/data/data/com.termux/files/usr/bin/iw" ]; then
          export LD_LIBRARY_PATH=/data/data/com.termux/files/usr/lib
          ip link set wlan1 down 2>/dev/null
          /data/data/com.termux/files/usr/bin/iw dev wlan1 set type monitor 2>/dev/null
          ip link set wlan1 up 2>/dev/null
          log "wlan1 set to MONITOR mode via Termux iw"
          return 0
        elif [ -x "$CHROOT_BIN" ] && [ -e "$ROOTFS/usr/sbin/iw" ]; then
          ip link set wlan1 down 2>/dev/null
          "$CHROOT_BIN" "$ROOTFS" /usr/sbin/iw dev wlan1 set type monitor 2>/dev/null
          ip link set wlan1 up 2>/dev/null
          log "wlan1 set to MONITOR mode via Kali chroot"
          return 0
        fi
      fi
      sleep 2; i=$((i+1))
    done
    log "monitor mode not set - use the Action button in Magisk, or set it manually"
  ) &
}

# only try if the module is configured to auto-enable monitor (default: yes)
AUTOMON="$MODDIR/automonitor"
[ -f "$AUTOMON" ] || echo 1 > "$AUTOMON"
if [ "$(cat "$AUTOMON" 2>/dev/null)" = "1" ]; then
  set_monitor_bg
  log "monitor mode: auto-enable requested (background)"
else
  log "monitor mode: auto-enable disabled (toggle via Magisk Action button)"
fi

log "done"
