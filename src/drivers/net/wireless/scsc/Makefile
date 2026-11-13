# ----------------------------------------------------------------------------
# Makefile for Samsung SCSC WLAN Driver (Exynos 1380 / S5E8835)
# Configured to mirror Samsung Official Build for Galaxy A35 (Android 14 / GKI 5.15)
# ----------------------------------------------------------------------------

KBUILD_CFLAGS += -Wframe-larger-than=4096
clean-files := *.o *.ko

ccflags-y += -O2 -std=gnu11 -Wno-declaration-after-statement -Wno-error
ccflags-y += -I$(src)
ccflags-y += -I$(src)/../../../../include
ccflags-y += -I$(src)/../../../../include/scsc
ccflags-y += -I$(src)/../../../../include/soc
ccflags-y += -I$(src)/../../../misc/samsung/scsc

# Samsung Official Config Flags for Exynos 1380 (s5e8835-a35xjvxx_defconfig)
ccflags-y += -DSCSC_SEP_VERSION=14
ccflags-y += -DCONFIG_SCSC_WLAN_MAX_INTERFACES=12
ccflags-y += -DCONFIG_SCSC_WLAN_KEY_MGMT_OFFLOAD=1
ccflags-y += -DCONFIG_SCSC_WLAN_HIP4_PROFILING=1
ccflags-y += -DCONFIG_SCSC_WLAN_RX_NAPI=1
ccflags-y += -DCONFIG_SCSC_WLAN_ANDROID=1
ccflags-y += -DCONFIG_SCSC_WLAN_GSCAN_ENABLE=1
ccflags-y += -DCONFIG_SCSC_WLAN_WES_NCHO=1
ccflags-y += -DCONFIG_SCSC_WLAN_MUTEX_DEBUG=1
ccflags-y += -DCONFIG_SCSC_WLAN_HANG_TEST=1
ccflags-y += -DCONFIG_SCSC_WLAN_ENHANCED_LOGGING=1
ccflags-y += -DCONFIG_SCSC_WLAN_WIFI_SHARING=1
ccflags-y += -DCONFIG_SCSC_WLAN_SAE_CONFIG=1
ccflags-y += -DCONFIG_SCSC_WLAN_ENABLE_MAC_RANDOMISATION=1
ccflags-y += -DCONFIG_SCSC_AP_INTERFACE_NAME=\"swlan0\"
ccflags-y += -DCONFIG_SCSC_WLAN_ACS_ENABLE=1
ccflags-y += -DCONFIG_SCSC_WLAN_MHS_STATIC_INTERFACE=1
ccflags-y += -DCONFIG_SCSC_WIFI_NAN_ENABLE=1
ccflags-y += -DCONFIG_SCSC_WLAN_NUM_ANTENNAS=1
ccflags-y += -DCONFIG_SCSC_WLAN_SET_PREFERRED_ANTENNA=1
ccflags-y += -DCONFIG_SCSC_WLAN_SILENT_RECOVERY=1
ccflags-y += -DCONFIG_SCSC_WLAN_ARP_FLOW_CONTROL=1
ccflags-y += -DCONFIG_SCSC_WLAN_ENHANCED_BIGDATA=1
ccflags-y += -DCONFIG_SCSC_WLAN_HE=1
ccflags-y += -DCONFIG_SCSC_WLAN_TX_API=1
ccflags-y += -DCONFIG_SCSC_WLAN_LOG_2_USER_SP=1
ccflags-y += -DCONFIG_SCSC_WLAN_LOAD_BALANCE_MANAGER=1
ccflags-y += -DCONFIG_SCSC_WLAN_TRACEPOINT_DEBUG=1
ccflags-y += -DCONFIG_SCSC_WLAN_HOST_DPD=1
ccflags-y += -DCONFIG_SCSC_WLAN_SAP_POWER_SAVE=1
ccflags-y += -DCONFIG_SCSC_WLAN_TPUT_MONITOR=1
ccflags-y += -DCONFIG_SCSC_WLAN_CUSTOM_TX_POWER=1
ccflags-y += -DCONFIG_SCSC_WLAN_TAS=1
ccflags-y += -DCONFIG_SCSC_PRINTK=1
ccflags-y += -DCONFIG_SCSC_DEBUG_COMPATIBILITY=1
ccflags-y += -DCONFIG_SCSC_CORE_CM=1
ccflags-y += -DCONFIG_SCSC_CORE=1
ccflags-y += -DCONFIG_SCSC_INDEPENDENT_SUBSYSTEM=1
ccflags-y += -DCONFIG_SCSC_WIFILOGGER=1

obj-m := scsc_wlan.o

# Official Samsung object list for scsc_wlan
scsc_wlan-y := hip4.o hip4_sampler.o mbulk.o dev.o cfg80211_ops.o netif.o rx.o tx.o ba.o ba_replay.o \
	sap_mlme.o sap_ma.o sap_dbg.o sap_test.o \
	mib.o mib_text_convert.o debug.o debug_frame.o procfs.o mgt.o mlme.o udi.o \
	log_clients.o src_sink.o fw_test.o cac.o txbp.o ioctl.o traffic_monitor.o \
	load_manager.o dpd_mmap.o reg_info.o log2us.o ini_config.o tdls_manager.o \
	scsc_wlan_mmap.o qsfs.o slsi_tracepoint_debug.o hip.o cm_if.o nl80211_vendor.o \
	nl80211_vendor_nan.o mlme_nan.o
