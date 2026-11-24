#!/system/bin/sh
# action.sh - One-press status check and diagnostic trigger for KernelSU / Magisk
MODDIR="${0%/*}"
LOG="/data/local/tmp/f_hid_action.log"

echo "=== USB HID Gadget Fix Status ($(date)) ===" > "$LOG"

echo "--- Loaded Modules ---" >> "$LOG"
lsmod | grep -E "usb_f_hid|f_hid" >> "$LOG" 2>&1 || echo "No out-of-tree f_hid module in lsmod" >> "$LOG"

echo "--- Character Devices (/dev/hidg*) ---" >> "$LOG"
ls -la /dev/hidg* >> "$LOG" 2>&1 || echo "No /dev/hidg* devices currently bound" >> "$LOG"

echo "--- USB Gadget ConfigFS State ---" >> "$LOG"
ls -la /config/usb_gadget/ >> "$LOG" 2>&1 || true

cat "$LOG"
