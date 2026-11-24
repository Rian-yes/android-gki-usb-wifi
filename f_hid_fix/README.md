# Patched USB HID Gadget Function Driver (`f_hid_fix`)

## Background & Bug Description
On Samsung Galaxy A35 5G (`SM-A356E`, Exynos 1380 / `s5e8835`) running Android 13/14 GKI kernel `5.15.153` (`android13-5.15`, commit `e787d6ac4af04c06a0120ad773820d43f9b851a9`), running a USB HID gadget (such as a FIDO2 / WebAuthn hardware security key) crashes the kernel whenever:
1. The USB cable is unplugged while a userspace process holds `/dev/hidg0` open.
2. The userspace listener process is interrupted or terminated (`SIGTERM` / `SIGKILL`).
3. The UDC (USB Device Controller) unbinds or resets.

### Root Cause
In Linux kernel 5.15, the in-tree `drivers/usb/gadget/function/f_hid.c`:
- **Waitqueue & Spinlock Lifecycle Corruption (CVE-2026-31721):** `hidg_bind()` re-initializes spinlocks (`write_spinlock`, `read_spinlock`) and waitqueues (`read_queue`, `write_queue`) on every UDC bind cycle, clobbering active waiter pointers while userspace file descriptors or epoll queues are sleeping on them.
- **Missing Reader Wakeup & Drain:** When `hidg_disable()` tears down the endpoints, it frees requests without signaling blocked readers in `wait_event_interruptible(hidg->read_queue)`. When the application subsequently exits, `f_hidg_release()` runs during unbind and trips over invalid pointers.
- **Exynos DWC3 DMA Panic:** Samsung's Exynos DWC3 controller driver (`dwc3-exynos` / `dwc3_ep_dequeue`) faults with a kernel NULL pointer dereference / DMA ring corruption when active endpoints are abruptly closed without synchronization.

## Upstream Fixes Incorporated
This driver backports the critical upstream fixes:
1. **Persistent Synchronization Lifecycle:** Spinlocks, waitqueues, and completed OUT request lists are initialized strictly once in `hidg_alloc()`, preserving waiter stability across UDC bind/unbind cycles.
2. **Device State Tracking (`disabled` flag):** Adds `hidg->disabled` to track endpoint availability. Upon `hidg_disable()`, the flag is set and `wake_up_interruptible()` is dispatched to both `read_queue` and `write_queue`.
3. **Graceful Readers Exit:** `f_hidg_intout_read()` and `f_hidg_ssreport_read()` inspect `hidg->disabled` and immediately return `-ESHUTDOWN` instead of locking the thread.
4. **Safe Release Cleanup:** `f_hidg_release()` flushes waiting readers/writers before freeing private handles.
5. **ConfigFS Alias Registration:** Registers as `"hid_fix"`, `"f_hid"`, and `"hid"`, allowing seamless ConfigFS instantiation without conflicting with stock built-in functions.

## Usage in ConfigFS
```bash
# Example ConfigFS instantiation
mkdir -p /config/usb_gadget/g1/functions/hid_fix.usb0
echo 0 > /config/usb_gadget/g1/functions/hid_fix.usb0/subclass
echo 0 > /config/usb_gadget/g1/functions/hid_fix.usb0/protocol
echo 64 > /config/usb_gadget/g1/functions/hid_fix.usb0/report_length
# Write report descriptor...
ln -s /config/usb_gadget/g1/functions/hid_fix.usb0 /config/usb_gadget/g1/configs/b.1/f1
```
