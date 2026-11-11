#!/system/bin/sh
# action.sh - runs when you press the "Action" button on this module in
# Magisk Manager (Magisk v27+) or KernelSU. Toggles wlan1 between MONITOR and
# MANAGED, and remembers the choice for next boot.
#
# Output shows up in the app's dialog.

MODDIR="${0%/*}"
AUTOMON="$MODDIR/automonitor"
FWDIR=/data/vendor/fw
DRV_NAME="__DRV_NAME__"
USB_ID="__USB_ID__"

IW=""
if [ -x "/data/data/com.termux/files/usr/bin/iw" ]; then
  export LD_LIBRARY_PATH=/data/data/com.termux/files/usr/lib
  IW="/data/data/com.termux/files/usr/bin/iw"
elif [ -x "/data/local/nhsystem/kali-arm64/usr/sbin/iw" ]; then
  CHROOT_BIN=/data/data/com.termux/files/usr/bin/chroot
  ROOTFS=/data/local/nhsystem/kali-arm64
  IW="$CHROOT_BIN $ROOTFS /usr/sbin/iw"
fi

echo "GKI USB Wi-Fi (__DRV_NAME__) — Control & Toggle"
echo ""

# If adapter is plugged in but wlan1 is not present, bind with transient firmware path
if ! ip link show wlan1 >/dev/null 2>&1; then
  for d in /sys/bus/usb/devices/*/idProduct; do
    dir=$(dirname "$d"); [ -f "$dir/idVendor" ] || continue
    if [ "$(cat "$dir/idVendor"):$(cat "$d")" = "$USB_ID" ]; then
      dev=$(basename "$dir")
      echo "Found adapter $dev. Initializing firmware & binding..."
      ORIG_FW=$(cat /sys/module/firmware_class/parameters/path 2>/dev/null)
      [ -z "$ORIG_FW" ] && ORIG_FW="/vendor/firmware"
      echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
      echo 1 > /proc/sys/vm/compact_memory 2>/dev/null || true
      echo "$FWDIR" > /sys/module/firmware_class/parameters/path 2>/dev/null
      for iface in /sys/bus/usb/devices/${dev}:*; do
        [ -d "$iface" ] || continue
        echo "$(basename "$iface")" > "/sys/bus/usb/drivers/$DRV_NAME/bind" 2>/dev/null
      done
      sleep 2
      echo "$ORIG_FW" > /sys/module/firmware_class/parameters/path 2>/dev/null
      break
    fi
  done
fi

if ! ip link show wlan1 >/dev/null 2>&1; then
  echo "wlan1 not present."
  echo "Plug the adapter in, wait 2 seconds, then press Action again."
  exit 0
fi

if [ -z "$IW" ]; then
  echo "wlan1 is active, but iw tool not found in Termux or Kali chroot."
  exit 0
fi

cur=$($IW dev wlan1 info 2>/dev/null | grep -o 'type [a-z]*' | head -1 | cut -d' ' -f2)
echo "current mode: ${cur:-unknown}"

if [ "$cur" = "monitor" ]; then
  ip link set wlan1 down 2>/dev/null
  $IW dev wlan1 set type managed 2>/dev/null
  ip link set wlan1 up 2>/dev/null
  echo 0 > "$AUTOMON"
  echo ""
  echo "-> switched to MANAGED (auto-enable on boot: OFF)"
else
  ip link set wlan1 down 2>/dev/null
  $IW dev wlan1 set type monitor 2>/dev/null
  ip link set wlan1 up 2>/dev/null
  echo 1 > "$AUTOMON"
  echo ""
  echo "-> switched to MONITOR (auto-enable on boot: ON)"
fi

new=$($IW dev wlan1 info 2>/dev/null | grep -o 'type [a-z]*' | head -1 | cut -d' ' -f2)
echo "now: ${new:-unknown}"
