#!/system/bin/sh
# action.sh - runs when you press the "Action" button on this module in
# Magisk Manager (Magisk v27+) or KernelSU. Toggles wlan1 between MONITOR and
# MANAGED, and remembers the choice for next boot.
#
# Output shows up in the app's dialog.

MODDIR="${0%/*}"
AUTOMON="$MODDIR/automonitor"

IW=""
if [ -x "/data/data/com.termux/files/usr/bin/iw" ]; then
  export LD_LIBRARY_PATH=/data/data/com.termux/files/usr/lib
  IW="/data/data/com.termux/files/usr/bin/iw"
elif [ -x "/data/local/nhsystem/kali-arm64/usr/sbin/iw" ]; then
  CHROOT_BIN=/data/data/com.termux/files/usr/bin/chroot
  ROOTFS=/data/local/nhsystem/kali-arm64
  IW="$CHROOT_BIN $ROOTFS /usr/sbin/iw"
fi

echo "GKI USB Wi-Fi — monitor mode toggle"
echo ""

if ! ip link show wlan1 >/dev/null 2>&1; then
  echo "wlan1 not present."
  echo "Plug the adapter in, wait a few seconds, then press Action again."
  exit 0
fi

if [ -z "$IW" ]; then
  echo "iw tool not found in Termux or Kali chroot."
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
