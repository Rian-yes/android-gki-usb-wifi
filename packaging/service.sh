#!/system/bin/sh
# service.sh - Magisk late_start service for the GKI USB Wi-Fi module.
# Loads mac80211 + the USB driver the SAFE way (autoprobe off, then sysfs bind)
# so the Unisoc native_hang_monitor watchdog can't panic on the slow firmware
# upload. Waits for the device to be unlocked first (CE storage / stable USB).
#
# This file is generated into the flashable ZIP; MODDIR is the module's own dir.

MODDIR="${0%/*}"                      # this module's install dir
KMOD="$MODDIR/modules"
FW="$MODDIR/firmware"
USB_ID="__USB_ID__"                   # filled in by the build (e.g. 0e8d:7612)
DRV_KO="__DRV_KO__"                   # leaf module filename (e.g. mt76x2u.ko)
DRV_NAME="__DRV_NAME__"               # driver dir under /sys/bus/usb/drivers (e.g. mt76x2u)

LOG="$MODDIR/load.log"
log() { echo "$(date '+%H:%M:%S') $*" >> "$LOG"; }
: > "$LOG"

# 1) wait for boot + a stable moment
n=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ $n -lt 150 ]; do sleep 2; n=$((n+1)); done
sleep 20


# Warn if more than one adapter module is enabled - they fight over wlan1.
N=$(ls -d /data/adb/modules/gki_usb_wifi_* 2>/dev/null | wc -l)
if [ "$N" -gt 1 ]; then
  log "WARNING: $N gki_usb_wifi modules are installed. Enable only the one for"
  log "         the adapter you're using, then reboot - two will conflict."
fi

# 3) load modules with USB autoprobe OFF so module_init never touches the HW
echo 0 > /sys/bus/usb/drivers_autoprobe 2>/dev/null
for m in "$KMOD"/mac80211.ko "$KMOD"/mt76.ko "$KMOD"/mt76-usb.ko \
         "$KMOD"/mt76x02-lib.ko "$KMOD"/mt76x02-usb.ko \
         "$KMOD"/mt76x2-common.ko "$KMOD"/*.ko ; do
  [ -e "$m" ] || continue
  base=$(basename "$m" .ko); lsn=$(echo "$base" | tr '-' '_')
  lsmod | grep -q "^$lsn " && continue
  insmod "$m" 2>/dev/null && log "loaded $base"
done
echo 1 > /sys/bus/usb/drivers_autoprobe 2>/dev/null

# 4) if the card is already attached, bind it now (firmware upload happens here,
#    outside module_init → watchdog can't fire). Retry with USB reset on timeout.
DRV="/sys/bus/usb/drivers/$DRV_NAME"
find_dev() {
  for d in /sys/bus/usb/devices/*/idProduct; do
    dir=$(dirname "$d"); [ -f "$dir/idVendor" ] || continue
    [ "$(cat "$dir/idVendor"):$(cat "$d")" = "$USB_ID" ] && { basename "$dir"; return 0; }
  done; return 1
}
dev=$(find_dev)
if [ -z "$dev" ]; then
  # No card at boot (the normal case). Skip binding, but DO continue to the
  # monitor-mode watcher below - it waits for wlan1 to show up on plug-in.
  log "card not attached; modules ready, will bind on plug-in"
else

attempt=1
echo 1 > /proc/sys/vm/compact_memory 2>/dev/null || true
while [ $attempt -le 3 ]; do
  for iface in /sys/bus/usb/devices/${dev}:*; do
    [ -d "$iface" ] || continue
    ib=$(basename "$iface")
    [ -e "$DRV/$ib" ] || echo "$ib" > "$DRV/bind" 2>/dev/null
  done
  i=0; while [ $i -lt 12 ]; do ip link show wlan1 >/dev/null 2>&1 && break; sleep 1; i=$((i+1)); done
  if ip link show wlan1 >/dev/null 2>&1; then log "wlan1 up (attempt $attempt)"; break; fi
  log "wlan1 not up (attempt $attempt) - USB reset"
  echo "$dev" > /sys/bus/usb/drivers/usb/unbind 2>/dev/null; sleep 2
  echo "$dev" > /sys/bus/usb/drivers/usb/bind   2>/dev/null; sleep 3
  dev=$(find_dev) || break
  attempt=$((attempt+1))
done
fi

# 5) set monitor mode once wlan1 exists AND the Kali chroot is usable.
#    Runs in the background so boot is never held up; gives up quietly after
#    ~10 min (e.g. NetHunter never opened this session).
CHROOT_BIN=/data/data/com.termux/files/usr/bin/chroot
ROOTFS=/data/local/nhsystem/kali-arm64

set_monitor_bg() {
  (
    i=0
    while [ $i -lt 300 ]; do          # up to ~10 min
      if ip link show wlan1 >/dev/null 2>&1; then
        if [ -x "/data/data/com.termux/files/usr/bin/iw" ]; then
          export LD_LIBRARY_PATH=/data/data/com.termux/files/usr/lib
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

# Write a pre-filled compatibility-report link to a file for anyone who wants
# to share their result. Nothing is sent and nothing opens - it just sits here.
{
  enc() { printf '%s' "$1" | sed -e 's|%|%25|g' -e 's| |%20|g' -e 's|/|%2F|g' \
          -e 's|(|%28|g' -e 's|)|%29|g' -e 's|:|%3A|g' -e 's|&|%26|g'; }
  ADP=""
  for d in /sys/bus/usb/devices/*/idProduct; do
    dd=$(dirname "$d"); [ -f "$dd/idVendor" ] || continue
    id="$(cat "$dd/idVendor"):$(cat "$d")"
    case "$id" in 0e8d:*|0bda:*|148f:*|0cf3:*|0846:*) ADP="$id";; esac
  done
  {
    echo "If this worked (or didn't) on your device, sharing it helps others"
    echo "with the same hardware skip the guesswork. Open this link, fill in the"
    echo "device model, and submit. Nothing is sent automatically."
    echo ""
    echo "https://github.com/markatsos/android-gki-usb-wifi/issues/new?template=compatibility.yml&kernel=$(enc "$(uname -r)")&adapter=$(enc "$ADP")"
  } > "$MODDIR/report-link.txt" 2>/dev/null
} 2>/dev/null
log "optional: a pre-filled compatibility-report link is in report-link.txt"

log "done"
