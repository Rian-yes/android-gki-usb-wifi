#!/system/bin/sh
# service.sh - Magisk/KernelSU late_start service for GKI USB Wi-Fi module.
# Enables native kernel USB hot-plug detection, avoids memory fragmentation
# (-ENOMEM) via proactive compaction, and unifies firmware directory with
# symlinks to prevent camera ISP microcode failures on Samsung/Exynos.

MODDIR="${0%/*}"
KMOD="$MODDIR/modules"
FW="$MODDIR/firmware"
USB_ID="__USB_ID__"
DRV_KO="__DRV_KO__"
DRV_NAME="__DRV_NAME__"

LOG="$MODDIR/load.log"
log() { echo "$(date '+%H:%M:%S') $*" >> "$LOG"; }
: > "$LOG"

# 1) Wait for boot
n=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ $n -lt 150 ]; do sleep 2; n=$((n+1)); done
sleep 5

# 2) Stage firmware in /data/vendor/fw
# Keeps Wi-Fi firmware in /data with vendor_fw_file label for kernel access.
FWDIR=/data/vendor/fw
mkdir -p "$FWDIR/rtw88"
if [ -d "$FW" ]; then
  cp -r "$FW"/* "$FWDIR/" 2>/dev/null
  cp -r "$FW"/* "$FWDIR/rtw88/" 2>/dev/null
fi
chmod -R 755 "$FWDIR"
chcon -R -h u:object_r:vendor_fw_file:s0 "$FWDIR" 2>/dev/null
log "firmware staged at $FWDIR"

# 3) Prevent memory fragmentation for mac80211 queue allocation (native kernel VM tuning)
sysctl -w vm.compaction_proactiveness=50 2>/dev/null || true
sysctl -w vm.min_free_kbytes=32768 2>/dev/null || true
echo 1 > /proc/sys/vm/compact_memory 2>/dev/null || true

# 4) Load kernel modules once (they remain resident in memory)
echo 0 > /sys/bus/usb/drivers_autoprobe 2>/dev/null
for m in "$KMOD"/mac80211.ko \
         "$KMOD"/rtw_core.ko \
         "$KMOD"/rtw_88xxa.ko \
         "$KMOD"/rtw_8723x.ko \
         "$KMOD"/rtw_8723d.ko \
         "$KMOD"/rtw_8821c.ko \
         "$KMOD"/rtw_8822b.ko \
         "$KMOD"/rtw_8822c.ko \
         "$KMOD"/rtw_8812a.ko \
         "$KMOD"/rtw_8814a.ko \
         "$KMOD"/rtw_8821a.ko \
         "$KMOD"/rtw_usb.ko \
         "$KMOD"/__DRV_KO__ \
         "$KMOD"/af_alg.ko "$KMOD"/algif_hash.ko "$KMOD"/algif_skcipher.ko "$KMOD"/algif_rng.ko \
         "$KMOD"/btintel.ko "$KMOD"/btrtl.ko "$KMOD"/btusb.ko \
         "$KMOD"/bnep.ko "$KMOD"/hci_vhci.ko \
         "$KMOD"/*.ko ; do
  [ -e "$m" ] || continue
  base=$(basename "$m" .ko); lsn=$(echo "$base" | tr '-' '_')
  lsmod | grep -q "^$lsn " && continue
  insmod "$m" 2>/dev/null && log "loaded $base"
done
# Re-enable autoprobe so the kernel natively auto-detects and binds on ANY hotplug!
echo 1 > /sys/bus/usb/drivers_autoprobe 2>/dev/null

# 5) If adapter is already plugged in at boot, bind with transient firmware switch
bind_adapter() {
  dev="$1"
  log "found adapter $dev at boot, binding interfaces..."
  ORIG_FW=$(cat /sys/module/firmware_class/parameters/path 2>/dev/null)
  [ -z "$ORIG_FW" ] && ORIG_FW="/vendor/firmware"

  echo 1 > /proc/sys/vm/compact_memory 2>/dev/null || true
  echo "$FWDIR" > /sys/module/firmware_class/parameters/path 2>/dev/null

  for iface in /sys/bus/usb/devices/${dev}:*; do
    [ -d "$iface" ] || continue
    ib=$(basename "$iface")
    # Wi-Fi interface -> rtw driver; Bluetooth interfaces -> btusb.
    # A bind to the wrong driver is rejected harmlessly by the kernel.
    echo "$ib" > "/sys/bus/usb/drivers/$DRV_NAME/bind" 2>/dev/null
    [ -d /sys/bus/usb/drivers/btusb ] && echo "$ib" > /sys/bus/usb/drivers/btusb/bind 2>/dev/null
  done

  # Bring up Bluetooth controller natively so btrtl loads rtl_bt firmware
  if [ -x "$MODDIR/bin/btup" ]; then
    "$MODDIR/bin/btup" up 0 >/dev/null 2>&1 || true
  elif command -v hciconfig >/dev/null 2>&1; then
    hciconfig hci0 up 2>/dev/null || true
  fi
  sleep 2
  echo "$ORIG_FW" > /sys/module/firmware_class/parameters/path 2>/dev/null
  log "adapter $dev bound, firmware path restored to $ORIG_FW"
  if [ -x "$MODDIR/bin/btup" ]; then
    log "bluetooth: $("$MODDIR/bin/btup" status 0 2>/dev/null || echo 'down')"
  else
    log "bluetooth controllers: $(ls /sys/class/bluetooth 2>/dev/null | tr '\n' ' ')"
  fi
}

set_monitor() {
  CHROOT_BIN=/data/data/com.termux/files/usr/bin/chroot
  ROOTFS=/data/local/nhsystem/kali-arm64
  if [ -x "/data/data/com.termux/files/usr/bin/iw" ]; then
    export LD_LIBRARY_PATH=/data/data/com.termux/files/usr/lib
    ip link set wlan1 down 2>/dev/null
    /data/data/com.termux/files/usr/bin/iw dev wlan1 set type monitor 2>/dev/null
    ip link set wlan1 up 2>/dev/null
    log "wlan1 set to MONITOR mode via Termux iw"
  elif [ -x "$CHROOT_BIN" ] && [ -e "$ROOTFS/usr/sbin/iw" ]; then
    ip link set wlan1 down 2>/dev/null
    "$CHROOT_BIN" "$ROOTFS" /usr/sbin/iw dev wlan1 set type monitor 2>/dev/null
    ip link set wlan1 up 2>/dev/null
    log "wlan1 set to MONITOR mode via Kali chroot"
  fi
}

dev=""
for d in /sys/bus/usb/devices/*/idProduct; do
  dir=$(dirname "$d"); [ -f "$dir/idVendor" ] || continue
  if [ "$(cat "$dir/idVendor" 2>/dev/null):$(cat "$d" 2>/dev/null)" = "$USB_ID" ]; then
    dev=$(basename "$dir"); break
  fi
done

if [ -n "$dev" ]; then
  bind_adapter "$dev"
  AUTOMON="$MODDIR/automonitor"
  [ -f "$AUTOMON" ] || echo 1 > "$AUTOMON"
  if [ "$(cat "$AUTOMON" 2>/dev/null)" = "1" ] && ip link show wlan1 >/dev/null 2>&1; then
    set_monitor
  fi
else
  log "adapter not attached at boot; plug in and press Action in KernelSU"
fi

log "service.sh complete - one-shot init done, zero background processes"
