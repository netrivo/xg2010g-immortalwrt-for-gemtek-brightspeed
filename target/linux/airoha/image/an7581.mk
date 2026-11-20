define Device/gemtek_xg2010g-common
  DEVICE_VENDOR := Gemtek
  DEVICE_PACKAGES := fitblk kmod-leds-gpio kmod-gpio-button-hotplug \
	kmod-phy-airoha-en8811h kmod-phy-realtek rtl826x-firmware \
	kmod-nf-conntrack-bridge kmod-nft-bridge \
	kmod-airoha-en7572 kmod-airoha-xpon airoha-ponctl airoha-pond \
	kmod-airoha-tod kmod-airoha-en7581-pcm-spi \
	-airoha-an7581-mt7996-board -airoha-en7581-mt7996-npu-firmware \
	-kmod-mac80211 -kmod-mt7996-firmware -kmod-mt7996e \
	-wpad-mbedtls -wpad-mesh-mbedtls -wireless-regdb
  BLOCKSIZE := 128k
  PAGESIZE := 2048
  UBINIZE_OPTS := -E 5
  KERNEL_IN_UBI := 1
  KERNEL := kernel-bin | gzip
  IMAGES := sysupgrade.itb
  # The dynamic UBI fit volume is recreated to the uploaded image size.
  # The 128 MiB package limit is independent of UBI volume placement.
  IMAGE_SIZE := 131072k
  IMAGE/sysupgrade.itb := append-kernel | \
	fit gzip $$(KDIR)/image-$$(firstword $$(DEVICE_DTS)).dtb external-static-with-rootfs | \
	append-metadata | check-size
  SOC := an7581
endef

define Device/gemtek_xg2010g-ubi-common
  DEVICE_VARIANT := UBI
  DEVICE_COMPAT_VERSION := 2.0
  DEVICE_COMPAT_MESSAGE := Firmware requires the XG2010G OpenWrt U-Boot UBI layout \
       with bl2 at 0x00000000 and ubi starting at 0x00020000, containing \
       fip, ubootenv, ubootenv2, factory and fit. Do not force an upgrade from \
       the legacy 0x00600000 layout. Preserve bl2 and the boot/calibration volumes.
endef

define Device/gemtek_xg2010g
  # DEVICE_DTS must be set before the common block: the common IMAGE line
  # uses := and freezes $(firstword $(DEVICE_DTS)) at eval time.
  DEVICE_DTS := an7581-xg2010g
  $(call Device/gemtek_xg2010g-common)
  DEVICE_MODEL := XG2010G
  SUPPORTED_DEVICES := gemtek,xg2010g
endef
TARGET_DEVICES += gemtek_xg2010g

define Device/gemtek_xg2010g-ubi
  # DEVICE_DTS must be set before the common block: the common IMAGE line
  # uses := and freezes $(firstword $(DEVICE_DTS)) at eval time.
  DEVICE_DTS := an7581-gemtek-xg2010g-ubi
  $(call Device/gemtek_xg2010g-common)
  $(call Device/gemtek_xg2010g-ubi-common)
  DEVICE_MODEL := XG2010G
  # One image covers the 1 GiB and 2 GiB boards: U-Boot publishes the DRAM
  # size detected by BL2, which overrides the fallback in the device tree.
  # The 2 GiB compatibles are kept so upgrades from the old variant work.
  SUPPORTED_DEVICES := gemtek,xg2010g-ubi gemtek,xg2010g \
	gemtek,xg2010g-2g-ubi gemtek,xg2010g-2g
endef
TARGET_DEVICES += gemtek_xg2010g-ubi
