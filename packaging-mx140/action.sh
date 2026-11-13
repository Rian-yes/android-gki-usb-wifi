#!/system/bin/sh
# action.sh - One-press toggle for Samsung Exynos 1380 (MX140) Monitor Mode (wlan0mon)
# Magisk v27+ / KernelSU Action Button

MODDIR="${0%/*}"
AUTOMON="$MODDIR/automonitor"
LOG="$MODDIR/load.log"

export LD_LIBRARY_PATH=/data/data/com.termux/files/usr/lib:$LD_LIBRARY_PATH
IW=/data/data/com.termux/files/usr/bin/iw
[ -x "$IW" ] || IW=/usr/sbin/iw
[ -x "$IW" ] || IW=iw

echo "=== Samsung Exynos 1380 (MX140) Monitor Tool ==="

# Check if wlan0mon already exists
if ip link show wlan0mon >/dev/null 2>&1; then
    echo "[*] wlan0mon is currently ACTIVE."
    echo "[*] Stopping wlan0mon..."
    ip link set wlan0mon down 2>/dev/null
    $IW dev wlan0mon del 2>/dev/null
    echo 0 > "$AUTOMON"
    echo "[-] Toggled: wlan0mon removed. Normal Wi-Fi restored."
    exit 0
fi

# Bring up wlan0mon
echo "[*] Enabling wlan0mon on phy0..."
# If driver not loaded, load it
if ! lsmod | grep -q "^scsc_wlan "; then
    if [ -f "$MODDIR/modules/scsc_wlan.ko" ]; then
        echo "[*] Loading patched scsc_wlan.ko..."
        insmod "$MODDIR/modules/scsc_wlan.ko" 2>/dev/null
    fi
fi

# Ensure slot is available and add wlan0mon
$IW phy phy0 interface add wlan0mon type monitor 2>/dev/null || \
$IW dev wlan0mon set type monitor 2>/dev/null

ip link set wlan0mon up 2>/dev/null

if ip link show wlan0mon >/dev/null 2>&1; then
    echo 1 > "$AUTOMON"
    echo "[+] SUCCESS: wlan0mon is UP in MONITOR mode!"
    echo "[+] Ready for airodump-ng / aireplay-ng / wifite."
    echo "    airodump-ng wlan0mon"
else
    echo "[-] FAILED: Could not bring up wlan0mon. Check dmesg."
    exit 1
fi
