# SPDX-License-Identifier: GPL-2.0
#
# Makefile for Patched USB HID Gadget Function Driver (f_hid_fix)
# Targets Samsung Galaxy A35 5G (SM-A356E) Exynos 1380 GKI 5.15.153
#

ccflags-y += -I$(src) -O2 -std=gnu11 -Wno-declaration-after-statement -Wno-error

obj-m := usb_f_hid_fix.o usb_f_hid.o
usb_f_hid_fix-objs := f_hid.o
usb_f_hid-objs := f_hid_std.o
