#!/system/bin/sh
# action.sh - One-press toggle & binder for RTL8723DU GKI Wi-Fi
MODDIR="${0%/*}"
AUTOMON="$MODDIR/automonitor"
FWDIR=/data/vendor/fw
DRV_NAME="__DRV_NAME__"
USB_ID="__USB_ID__"

export LD_LIBRARY_PATH=/data/data/com.termux/files/usr/lib
IW=""
[ -x "/data/data/com.termux/files/usr/bin/iw" ] && IW="/data/data/com.termux/files/usr/bin/iw"

echo "=== GKI USB Wi-Fi ($DRV_NAME) ==="

# Find adapter port dynamically (handles direct OTG or powered USB hub)
dev=""
for d in /sys/bus/usb/devices/*/idProduct; do
  dir=$(dirname "$d")
  v=$(cat "$dir/idVendor" 2>/dev/null)
  p=$(cat "$d" 2>/dev/null)
  if [ "$v:$p" = "$USB_ID" ]; then
    dev=$(basename "$dir")
    break
  fi
done

if [ -z "$dev" ]; then
  echo "[-] Adapter $USB_ID not detected on USB."
  echo "[!] Plug in the adapter/hub and press Action again."
  exit 0
fi

# Step 0: Bluetooth half of the combo chip (btusb) - bind if no hci device yet
if [ -d /sys/bus/usb/drivers/btusb ] && [ -z "$(ls /sys/class/bluetooth 2>/dev/null)" ]; then
  echo "[*] Binding Bluetooth interfaces (btusb)..."
  ORIG_FW=$(cat /sys/module/firmware_class/parameters/path 2>/dev/null)
  [ -z "$ORIG_FW" ] && ORIG_FW="/vendor/firmware"
  echo "$FWDIR" > /sys/module/firmware_class/parameters/path 2>/dev/null
  for iface in /sys/bus/usb/devices/${dev}:*; do
    [ -d "$iface" ] || continue
    echo "$(basename "$iface")" > /sys/bus/usb/drivers/btusb/bind 2>/dev/null
  done
  sleep 2
  for h in /sys/class/bluetooth/hci*; do
    [ -d "$h" ] || continue
    hname=$(basename "$h")
    if command -v hciconfig >/dev/null 2>&1; then
      hciconfig "$hname" up 2>/dev/null || true
    elif [ -x /data/local/nhsystem/kali-arm64/usr/bin/hciconfig ]; then
      chroot /data/local/nhsystem/kali-arm64 /usr/bin/hciconfig "$hname" up 2>/dev/null || true
    fi
  done
  sleep 2
  echo "$ORIG_FW" > /sys/module/firmware_class/parameters/path 2>/dev/null
fi
if [ -n "$(ls /sys/class/bluetooth 2>/dev/null)" ]; then
  echo "[+] Bluetooth: $(ls /sys/class/bluetooth | tr '\n' ' ')"
else
  echo "[!] No hci device (check: dmesg | grep -iE 'btusb|rtl_bt')"
fi

# Step 1: Bind if wlan1 is not present
if ! ip link show wlan1 >/dev/null 2>&1; then
  echo "[*] Initializing hardware & binding adapter ($dev)..."
  ORIG_FW=$(cat /sys/module/firmware_class/parameters/path 2>/dev/null)
  [ -z "$ORIG_FW" ] && ORIG_FW="/vendor/firmware"

  # Defragment memory to prevent -ENOMEM
  echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
  echo 1 > /proc/sys/vm/compact_memory 2>/dev/null || true

  # 2-second transient firmware switch (stock firmware protected)
  echo "$FWDIR" > /sys/module/firmware_class/parameters/path 2>/dev/null
  for iface in /sys/bus/usb/devices/${dev}:*; do
    [ -d "$iface" ] || continue
    ib=$(basename "$iface")
    echo "$ib" > "/sys/bus/usb/drivers/$DRV_NAME/bind" 2>/dev/null
  done
  sleep 2
  echo "$ORIG_FW" > /sys/module/firmware_class/parameters/path 2>/dev/null
fi

if ! ip link show wlan1 >/dev/null 2>&1; then
  echo "[-] Error: Failed to bring up wlan1. Check dmesg."
  exit 1
fi

# Step 2: Ensure wlan1 is UP and check/toggle mode
# If wlan1 was put into state DOWN by wifite or another app, resurrect it
if [ -n "$IW" ]; then
  cur=$($IW dev wlan1 info 2>/dev/null | grep -o "type [a-z]*" | head -1 | cut -d" " -f2)
  echo "[+] Adapter active: wlan1"
  echo "    Current mode: ${cur:-unknown}"

  if [ "$cur" = "monitor" ]; then
    ip link set wlan1 down 2>/dev/null
    $IW dev wlan1 set type managed 2>/dev/null
    ip link set wlan1 up 2>/dev/null
    echo "[->] Toggled to: MANAGED"
  else
    ip link set wlan1 down 2>/dev/null
    $IW dev wlan1 set type monitor 2>/dev/null
    ip link set wlan1 up 2>/dev/null
    echo "[->] Toggled to: MONITOR (ready for airodump-ng / wifite)"
  fi
else
  ip link set wlan1 up 2>/dev/null
  echo "[+] wlan1 is UP."
fi
