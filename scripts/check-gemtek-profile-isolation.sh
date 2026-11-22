#!/usr/bin/env bash

set -Eeuo pipefail

usage() {
	cat >&2 <<'EOF'
usage: check-gemtek-profile-isolation.sh --config <file> [--kernel-config <file>] [--manifest <file> ...]
EOF
	exit 2
}

config_file=""
kernel_config=""
manifests=()

while (( $# > 0 )); do
	case "$1" in
		--config)
			(( $# >= 2 )) || usage
			config_file="$2"
			shift 2
			;;
		--kernel-config)
			(( $# >= 2 )) || usage
			kernel_config="$2"
			shift 2
			;;
		--manifest)
			(( $# >= 2 )) || usage
			manifests+=("$2")
			shift 2
			;;
		*)
			usage
			;;
	esac
done

[[ -n "$config_file" && -f "$config_file" ]] || usage
[[ -z "$kernel_config" || -f "$kernel_config" ]] || {
	echo "kernel config not found: $kernel_config" >&2
	exit 1
}
for manifest in ${manifests[@]+"${manifests[@]}"}; do
	[[ -f "$manifest" ]] || {
		echo "manifest not found: $manifest" >&2
		exit 1
	}
done

selected=$(grep -E '^CONFIG_(TARGET_airoha_an7581_DEVICE|TARGET_DEVICE_airoha_an7581_DEVICE)_[a-z0-9_.-]+=y$' "$config_file" \
	| sed 's/.*_DEVICE_//; s/=y//' | sort -u || true)
[[ -n "$selected" ]] || {
	echo "no airoha an7581 device selected in $config_file" >&2
	exit 1
}
while IFS= read -r device; do
	case "$device" in
		gemtek_xg2010g|gemtek_xg2010g-ubi|gemtek_xg2010g-2g|gemtek_xg2010g-2g-ubi) ;;
		*) echo "unexpected device selected: $device" >&2; exit 1 ;;
	esac
done <<<"$selected"

profile="xg2010g"
policy_file="$(dirname "$0")/xg2010g-package-policy.txt"
[[ -f "$policy_file" ]] || {
	echo "package policy not found: $policy_file" >&2
	exit 1
}
forbidden_packages='(airoha-an7581-mt7996-board|airoha-en7581-mt7996-npu-firmware|hostapd.*|iw|iw-full|iwinfo|kmod-(mac80211.*|mt76.*|mt7996.*)|ucode-mod-nl80211|wireless-regdb|wpad.*)'
forbidden_build_config='CONFIG_TARGET_ROOTFS_INITRAMFS=y'
required_packages=(
	kmod-nf-conntrack-bridge
	kmod-nft-bridge
	kmod-airoha-en7572
	kmod-airoha-xpon
	airoha-ponctl
	airoha-pond
	luci-app-onu
	kmod-airoha-en7581-pcm-spi
)
manifest_required_packages=("${required_packages[@]}" kmod-airoha-tod)
forbidden_kernel='CONFIG_MT(76|7996).*=(y|m)'
required_kernel='CONFIG_PTP_1588_CLOCK_AIROHA_TOD=m'

failed=0

if grep -En "^CONFIG_(PACKAGE|DEFAULT)_${forbidden_packages}=y$" "$config_file"; then
	echo "$profile config selects forbidden packages" >&2
	failed=1
fi

for package in "${required_packages[@]}"; do
	if ! grep -Fqx "CONFIG_PACKAGE_${package}=y" "$config_file"; then
		echo "$profile config is missing required package: $package" >&2
		failed=1
	fi
done

if [[ -n "$forbidden_build_config" ]] && grep -Fqx "$forbidden_build_config" "$config_file"; then
	echo "$profile config enables initramfs and can overwrite the normal kernel used by the size-limited FIT image" >&2
	failed=1
fi

if [[ -n "$kernel_config" ]]; then
	if grep -En "^${forbidden_kernel}$" "$kernel_config"; then
		echo "$profile kernel enables a forbidden subsystem" >&2
		failed=1
	fi

	while IFS= read -r required; do
		[[ -n "$required" ]] || continue
		if ! grep -Eq "^${required}$" "$kernel_config"; then
			echo "$profile kernel is missing required symbol: $required" >&2
			failed=1
		fi
	done < <(tr '|' '\n' <<<"$required_kernel")
fi

for manifest in ${manifests[@]+"${manifests[@]}"}; do
	if grep -En "^${forbidden_packages}([[:space:]]|$)" "$manifest"; then
		echo "$profile manifest contains forbidden packages: $manifest" >&2
		failed=1
	fi

	while IFS= read -r package; do
		[[ -n "$package" ]] || continue
		while IFS= read -r pattern; do
			[[ -z "$pattern" || "$pattern" == \#* ]] && continue
			case "$package" in
				$pattern)
					echo "$profile manifest contains policy-blocked package $package: $manifest" >&2
					failed=1
					;;
			esac
		done < "$policy_file"
	done < <(awk '{print $1}' "$manifest")

	for package in "${manifest_required_packages[@]}"; do
		if ! grep -Eq "^${package}([[:space:]]|$)" "$manifest"; then
			echo "$profile manifest is missing required package $package: $manifest" >&2
			failed=1
		fi
	done
done

(( failed == 0 )) || exit 1
echo "Gemtek profile isolation check passed: $profile"
