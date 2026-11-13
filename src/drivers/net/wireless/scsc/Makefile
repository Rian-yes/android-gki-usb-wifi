# Makefile for SCSC WLAN driver (Samsung Exynos 1380 / S5E8835)
# Optimized for out-of-tree build against GKI / ACK 5.15 kernel

ccflags-y += -O2 -std=gnu11 -Wno-declaration-after-statement -Wno-error
ccflags-y += -I$(src)
ccflags-y += -I$(src)/include
ccflags-y += -I$(src)/../../../../include
ccflags-y += -I$(src)/../../../../include/scsc
ccflags-y += -I$(src)/../../../misc/samsung/scsc

# Maxwell SCSC Configs matching s5e8835-a35xjvxx_defconfig
ccflags-y += -DCONFIG_SCSC_WLAN=1
ccflags-y += -DCONFIG_SCSC_WLAN_TX_API=1
ccflags-y += -DCONFIG_SCSC_WLAN_MAX_INTERFACES=12
ccflags-y += -DCONFIG_SCSC_WLAN_RX_NAPI=1
ccflags-y += -DCONFIG_SCSC_WLAN_HIP4_PROFILING=1
ccflags-y += -DCONFIG_SCSC_WLAN_LOAD_BALANCE_MANAGER=1
ccflags-y += -DCONFIG_SCSC_WLAN_HOST_DPD=1
ccflags-y += -DCONFIG_SCSC_WLAN_ANDROID=1
ccflags-y += -DCONFIG_SCSC_WLAN_WES_NCHO=1
ccflags-y += -DCONFIG_SCSC_WLAN_GSCAN_ENABLE=1
ccflags-y += -DCONFIG_SCSC_WIFI_NAN_ENABLE=1
ccflags-y += -DCONFIG_SCSC_WLAN_KEY_MGMT_OFFLOAD=1
ccflags-y += -DCONFIG_SCSC_WLAN_NUM_ANTENNAS=1
ccflags-y += -DCONFIG_SCSC_WLAN_MUTEX_DEBUG=1
ccflags-y += -DCONFIG_SCSC_WLAN_HANG_TEST=1
ccflags-y += -DCONFIG_SCSC_WLAN_ENHANCED_LOGGING=1
ccflags-y += -DCONFIG_SCSC_WLAN_WIFI_SHARING=1
ccflags-y += -DCONFIG_SCSC_WLAN_SAE_CONFIG=1
ccflags-y += -DCONFIG_SCSC_WLAN_ENABLE_MAC_RANDOMISATION=1
ccflags-y += -DCONFIG_SCSC_AP_INTERFACE_NAME=\"swlan0\"
ccflags-y += -DCONFIG_SCSC_WLAN_ACS_ENABLE=1
ccflags-y += -DCONFIG_SCSC_WLAN_MHS_STATIC_INTERFACE=1
ccflags-y += -DCONFIG_SCSC_WLAN_SILENT_RECOVERY=1
ccflags-y += -DCONFIG_SCSC_WLAN_ARP_FLOW_CONTROL=1
ccflags-y += -DCONFIG_SCSC_WLAN_ENHANCED_BIGDATA=1
ccflags-y += -DCONFIG_SCSC_WLAN_HE=1
ccflags-y += -DCONFIG_SCSC_WLAN_LOG_2_USER_SP=1
ccflags-y += -DCONFIG_SCSC_WLAN_TRACEPOINT_DEBUG=1
ccflags-y += -DCONFIG_SCSC_WLAN_SAP_POWER_SAVE=1
ccflags-y += -DCONFIG_SCSC_WLAN_TPUT_MONITOR=1
ccflags-y += -DCONFIG_SCSC_WLAN_CUSTOM_TX_POWER=1
ccflags-y += -DCONFIG_SCSC_WLAN_TAS=1
ccflags-y += -DCONFIG_SCSC_PRINTK=1

obj-m := scsc_wlan.o

scsc_wlan-objs := hip4.o mbulk.o dev.o cfg80211_ops.o netif.o rx.o tx.o ba.o ba_replay.o \
                  sap_mlme.o sap_ma.o sap_dbg.o sap_test.o mib.o mib_text_convert.o \
                  debug.o debug_frame.o procfs.o mgt.o mlme.o udi.o log_clients.o \
                  src_sink.o fw_test.o cac.o txbp.o ioctl.o traffic_monitor.o reg_info.o \
                  log2us.o ini_config.o tdls_manager.o scsc_wlan_mmap.o qsfs.o \
                  hip.o cm_if.o kic.o nl80211_vendor.o nl80211_vendor_nan.o mlme_nan.o \
                  load_manager.o dpd_mmap.o slsi_tracepoint_debug.o hip4_sampler.o
