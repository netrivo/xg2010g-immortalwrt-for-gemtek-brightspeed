RAMFS_COPY_BIN='fitblk fit_check_sign'

REQUIRE_IMAGE_METADATA=1

. /lib/upgrade/gemtek-ubi.sh

airoha_require_ubi_layout()
{
	local ubidev volume fip_volume

	ubidev="$(nand_find_ubi ubi)"
	[ -n "$ubidev" ] || {
		echo "UBI is not initialized; create the base volumes from U-Boot recovery."
		return 1
	}

	for volume in fip ubootenv ubootenv2 "$@"; do
		if ! nand_find_volume "$ubidev" "$volume" >/dev/null; then
			echo "UBI base volume $volume is missing; repair the layout from U-Boot recovery."
			return 1
		fi
	done

	fip_volume="$(nand_find_volume "$ubidev" fip)"
	[ "$(cat "/sys/class/ubi/$fip_volume/data_bytes")" -gt 0 ] || {
		echo "The fip volume does not contain BL31/U-Boot; install the boot chain first."
		return 1
	}
}

platform_check_image() {
	local board=$(board_name)

	[ "$#" -gt 1 ] && return 1

	case "$board" in
	gemtek,xg2010g-ubi|\
	gemtek,xg2010g-2g-ubi|\
	gemtek,xg2010g-2g)
		gemtek_ubi_layout_check "$board" || {
			echo "Unsupported Gemtek UBI layout; refusing sysupgrade."
			return 1
		}
		fit_check_image "$1"
		return $?
		;;
	gemtek,xg2010g)
		fit_check_image "$1"
		return $?
		;;
	esac

	return 0
}

platform_do_upgrade() {
	local board=$(board_name)

	case "$board" in
		gemtek,xg2010g-ubi|\
		gemtek,xg2010g-2g-ubi|\
		gemtek,xg2010g-2g)
			gemtek_ubi_layout_check "$board" &&
				airoha_require_ubi_layout factory && fit_do_upgrade "$1"
			;;
		gemtek,xg2010g)
			fit_do_upgrade "$1"
			;;
		*)
			nand_do_upgrade "$1"
			;;
	esac
}
