# Samsung Exynos Camera Failure & Kernel Watchdog Reset Bug Report

## Overview

When the `android-gki-usb-wifi` module is installed on Samsung Exynos devices (tested on Samsung Galaxy A35 5G / `SM-A356E` with Exynos 1380 on kernel `5.15.153-android13-3-28444519`), opening the Camera app fails (both front and rear cameras), and the device subsequently hard-freezes and reboots via hardware watchdog reset (`CLUSTER0_WDTRESET`).

This document details the root cause, exact crash logs, affected code paths, and the resolution.

---

## 1. Root Cause Analysis

### Issue A: Global Kernel Parameter Override (`firmware_class/parameters/path`)

In `packaging/service.sh`:
```bash
FWDIR=/data/local/tmp/fw
...
echo "$FWDIR" > /sys/module/firmware_class/parameters/path
```

#### Why this breaks the system:
`/sys/module/firmware_class/parameters/path` is a **global Linux kernel setting** that applies to **all** kernel drivers calling `request_firmware()`, not just the USB Wi-Fi driver.

On Samsung Exynos devices, the proprietary Camera ISP driver (`fimc_is` / `pablo_libs`) dynamically loads camera sensor microcode and tuning data via `request_firmware()` from `/vendor/firmware/`:
- `is_mcu_fw.bin` (Camera MCU firmware)
- `pablo_icpufw.bin` (Camera ICPU firmware, ~7 MB)
- `setfile_imx882.bin` (Main sensor tuning parameters, ~13 MB)
- `setfile_gc08a3.bin` (Front sensor parameters, ~8.5 MB)
- `setfile_3l6.bin` (Ultra-wide sensor parameters, ~9.5 MB)

When `service.sh` overrides `firmware_class/parameters/path` to `$FWDIR` (`/data/local/tmp/fw`), the kernel stops searching `/vendor/firmware` for **all** hardware.

When any camera app opens:
1. `cameraserver` requests sensor power-up.
2. `fimc_is` calls `request_firmware("pablo_icpufw.bin")`.
3. The kernel searches `$FWDIR`, fails to find the camera firmware, and aborts initialization.
4. The camera power domain (`CAM_D`) remains unpowered (`pd off`).
5. `pablo_libs` attempts a register read on the unpowered Camera Serial Interface (CSIS) bus at physical address `0x151F9801`.
6. The bus hardware triggers a **Synchronous External Abort (SLVERR)**, and Samsung's hardware watchdog forces an immediate device reset.

#### Extracted Evidence from Device Ramdump (`/data/log/dumpstate_latest_lastkmsg.log.gz`):
```text
@= WATCHDOG RESET / PC = readb+0x34/0x80 [pablo_libs] / BUS = CSIS_P,0x151f9801,SLVERR
[ 1228.068890] [3: kworker/3:3: 7189] synchronous external abort (0x96000010) at 0xffffffc015769801[0x0151f9801]
[ 1228.068949] exynos-itmon-v2 exynos-itmon: 24 irq, CAM_D group, pd off, 0 errors
[ 1228.069117] > Master         : CLUSTER0_P CPU3__
[ 1228.069117] > Target         : CSIS_P (Camera Serial Interface Subsystem)
[ 1228.069117] > Target Address : 0x151F9801
[ 1228.069117] > Type           : READ
[ 1228.069117] > Error code     : Error Detect by the Slave(SLVERR)
[ 1228.069463] debug-snapshot dss: Caller: dbg_snapshot_do_dpm_policy+0xe4/0x164 [dss], WDTRESET right now!
```

---

### Issue B: Hardcoded USB Interface ID (`${dev}:1.0`) on Combo Chips

In `packaging/service.sh`:
```bash
[ -e "$DRV/${dev}:1.0" ] || echo "${dev}:1.0" > "$DRV/bind" 2>/dev/null
```

#### Why this fails on combo adapters (e.g. Realtek RTL8723DU):
The script assumes all USB Wi-Fi adapters expose their WLAN function on USB interface `:1.0`.
RTL8723DU (`0bda:d723`) is a dual Wi-Fi + Bluetooth combo adapter:
- Interface `1-1:1.0`: Bluetooth (`bInterfaceClass 0xe0`, `01`, `01`)
- Interface `1-1:1.1`: Bluetooth Alternate (`bInterfaceClass 0xe0`, `01`, `01`)
- Interface `1-1:1.2`: Wi-Fi (`bInterfaceClass 0xff`, `ff`, `ff`)

Because `rtw_8723du` only binds to vendor-specific Wi-Fi interfaces (`0xff`), writing `${dev}:1.0` to `$DRV/bind` is rejected by the driver, leaving the Wi-Fi interface (`1-1:1.2`) unbound and `wlan1` absent.

---

### Issue C: High-Order Memory Allocation Failure in `mac80211`

When `rtw_register_hw` initializes `mac80211`:
```text
ieee80211_register_hw -> ieee80211_txq_setup_flows -> kmalloc_order -> __alloc_pages_slowpath
rtw_8723du: probe of 1-1:1.2 failed with error -12 (-ENOMEM)
```
On Android devices with fragmented RAM, high-order contiguous page allocations (orders 4–6) fail under normal system uptime.

---

## 2. The Resolution

### Fix 1: Unified Firmware Staging via Stock Vendor Symlinks
Instead of overriding the firmware path exclusively with Wi-Fi firmware (which breaks the camera) or relying on transient path switching (which fails on automatic hot-reload when unplugged and replugged), the optimal solution is a **Unified Firmware Directory**:

1. Stage the Wi-Fi firmware in `/data/vendor/fw/rtw88/`.
2. Create symlinks for all stock files in `/vendor/firmware/*` into `/data/vendor/fw/`:
   ```bash
   for f in /vendor/firmware/*; do
     b=$(basename "$f")
     [ -e "/data/vendor/fw/$b" ] || ln -sf "$f" "/data/vendor/fw/$b"
   done
   ```
3. Point `/sys/module/firmware_class/parameters/path` to `/data/vendor/fw`.

**Result:**
- The Camera ISP finds all its microcode (`is_mcu_fw.bin`, `pablo_icpufw.bin`, `setfile_imx882.bin`) via the symlinks with zero delays.
- The USB Wi-Fi dongle finds its firmware on automatic hot-plug at any time without needing background watcher scripts or manual action keys.
- Zero modifications to system partitions or `/vendor` (everything stays inside `/data`).

### Fix 2: Proactive Memory Compaction (Fixing -ENOMEM on Hotplug)
Samsung's default kernel configuration disables proactive memory compaction (`vm.compaction_proactiveness = 0`). Over device uptime, RAM fragments, causing `mac80211` queue allocation to fail (`-ENOMEM` / error `-12`) during USB insertion.

Enabling proactive compaction allows the kernel's native `kcompactd` to maintain contiguous page pools in the background:
```bash
sysctl -w vm.compaction_proactiveness=50
sysctl -w vm.min_free_kbytes=32768
```

### Fix 3: Dynamic Interface Enumeration
Replace the hardcoded `:1.0` interface binding with dynamic interface iteration:
```bash
for iface in /sys/bus/usb/devices/${dev}:*; do
  [ -d "$iface" ] || continue
  ib=$(basename "$iface")
  [ -e "$DRV/$ib" ] || echo "$ib" > "$DRV/bind" 2>/dev/null
done
```
This binds any valid interface belonging to the USB device (including `:1.2` on combo chips) while ignoring mismatched interfaces safely.
### Fix 4: Universal `iw` Tool Detection
Check Termux's native `iw` binary before falling back to Kali chroot:
```bash
if [ -x "/data/data/com.termux/files/usr/bin/iw" ]; then
  export LD_LIBRARY_PATH=/data/data/com.termux/files/usr/lib
  IW="/data/data/com.termux/files/usr/bin/iw"
```

---

## 3. GitHub Issue Template for Upstream (`markatsos/android-gki-usb-wifi`)

```markdown
### Bug Report: Overriding `/sys/module/firmware_class/parameters/path` breaks Camera ISP and causes Watchdog Reset on Samsung Exynos devices

#### Summary
On Samsung Exynos devices (tested on Galaxy A35 5G / SM-A356E, kernel 5.15 GKI), installing the module causes camera failure (both front/back) and crashes the phone (`CLUSTER0_WDTRESET`) when any camera app is opened.

#### Root Cause
In `packaging/service.sh`:
`echo "$FWDIR" > /sys/module/firmware_class/parameters/path`

This overrides the global kernel firmware search path. Samsung's Exynos camera ISP (`fimc_is` / `pablo_libs`) loads camera microcode (`is_mcu_fw.bin`, `pablo_icpufw.bin`, `setfile_imx882.bin`) from `/vendor/firmware/` via `request_firmware()`. Because `parameters/path` is redirected to `$FWDIR`, camera firmware loading fails. The uninitialized camera sensor triggers an AXI slave abort (`SLVERR`) on the CSIS bus (`0x151F9801`), tripping the hardware watchdog.

#### Log Evidence (from kernel lastkmsg / pstore)
`RSTSTAT: RSVD8 CLUSTER0_WDTRESET / PC: readb+0x34/0x80 [pablo_libs] / BUS: CSIS_P,0x151f9801,SLVERR`
`synchronous external abort (0x96000010) at 0xffffffc015769801[0x0151f9801]`
`Target: CSIS_P, CAM_D group, pd off`

#### Additional Issue: Combo Chip Binding
RTL8723DU and other combo chips expose Bluetooth on interface `:1.0` and Wi-Fi on `:1.2`. Hardcoding `echo "${dev}:1.0" > "$DRV/bind"` in `service.sh` fails to bind the Wi-Fi interface.

#### Suggested Solution
1. Use a transient firmware path switch during device bind instead of permanently overriding it:
   ```bash
   ORIG_FW=$(cat /sys/module/firmware_class/parameters/path 2>/dev/null)
   [ -z "$ORIG_FW" ] && ORIG_FW="/vendor/firmware"
   echo "$FWDIR" > /sys/module/firmware_class/parameters/path
   # bind interfaces...
   sleep 2
   echo "$ORIG_FW" > /sys/module/firmware_class/parameters/path
   ```
2. Bind all interfaces dynamically (`for iface in /sys/bus/usb/devices/${dev}:*; do echo $(basename $iface) > "$DRV/bind"; done`).
3. Call `echo 1 > /proc/sys/vm/compact_memory` before loading to avoid `-ENOMEM` in `mac80211` queue allocation.
```
