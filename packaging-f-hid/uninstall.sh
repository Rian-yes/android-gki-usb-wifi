#!/system/bin/sh
# uninstall.sh - Best-effort cleanup upon module removal
for m in usb_f_hid_fix usb_f_hid; do
    rmmod "$m" 2>/dev/null || true
done
