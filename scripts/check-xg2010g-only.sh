#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "$0")/.."

fail=0
err() { echo "check-xg2010g-only: $*" >&2; fail=1; }

expected_devices=$'gemtek_xg2010g\ngemtek_xg2010g-ubi'
actual_devices=$(grep -h '^TARGET_DEVICES += ' target/linux/airoha/image/an7581.mk \
	| sed 's/^TARGET_DEVICES += //' | sort || true)
if [[ "$actual_devices" != "$expected_devices" ]]; then
	err "an7581 TARGET_DEVICES mismatch"
	diff -u <(printf '%s\n' "$expected_devices") <(printf '%s\n' "$actual_devices") >&2 || true
fi

if grep -H '^TARGET_DEVICES += ' target/linux/airoha/image/an7583.mk \
	target/linux/airoha/image/en7523.mk 2>/dev/null; then
	err "an7583/en7523 still define target devices"
fi

for f in target/linux/airoha/dts/*; do
	base=$(basename "$f")
	[[ "$base" == "an7581.dtsi" || "$base" == *xg2010g* ]] && continue
	err "unexpected DTS file: $f"
done

for f in *.config; do
	case "$f" in
		2010.config) ;;
		*) err "unexpected build config: $f" ;;
	esac
done

selected=$(grep -E '^CONFIG_TARGET_airoha_an7581_DEVICE_.*=y$' 2010.config \
	| sed 's/.*_DEVICE_//; s/=y//' | sort || true)
case "$selected" in
	gemtek_xg2010g|gemtek_xg2010g-ubi) ;;
	*) err "2010.config must select exactly one XG2010G profile, got: $selected" ;;
esac

bash scripts/apply-xg2010g-package-policy.sh --check 2010.config \
	|| err "optional third-party packages are not disabled in 2010.config"

# Kconfig resolves dependencies after the seed config is applied.  Check the
# resolved build config too, otherwise a dependency could promote an optional
# package back to =y even though the seed config says =m.
if [[ -f .config ]]; then
	bash scripts/apply-xg2010g-package-policy.sh --check .config \
		|| err "optional third-party packages are not disabled in .config"
fi

for pkg in \
	luci-app-onu \
	luci-app-pon-status \
	luci-app-clients \
	luci-app-airoha-npu \
	luci-app-firewall \
	luci-app-package-manager \
	luci-app-ttyd \
	luci-theme-argon \
	luci-theme-bootstrap; do
	grep -qx "CONFIG_PACKAGE_${pkg}=y" 2010.config \
		|| err "required XG2010G package is missing: $pkg"
done

grep -qx 'SAVE_INSTALLED_PKGS=1' package/base-files/files/sbin/sysupgrade \
	|| err "sysupgrade does not save installed packages by default"
[[ -x package/base-files/files/usr/sbin/xg2010g-restore-packages ]] \
	|| err "package restore helper is missing or not executable"
[[ -s package/base-files/files/lib/upgrade/keep.d/xg2010g-configs ]] \
	|| err "XG2010G sysupgrade keep list is missing"
[[ -x package/base-files/files/etc/init.d/xg2010g-restore-packages ]] \
	|| err "package restore init script is missing or not executable"

for path in \
	package/boot/uboot-airoha \
	target/linux/airoha/an7583/base-files \
	package/boot/uboot-tools/uboot-envtools/files/airoha_an7583 \
	1710.config 040.config 040-tf.config config.seed \
	.github/workflows/sync-upstream.yml; do
	[[ ! -e "$path" ]] || err "obsolete path still exists: $path"
done

. scripts/xg2010g-unused-paths.sh
for path in "${xg2010g_unused_paths[@]}"; do
	[[ ! -e "$path" ]] || err "unused path still exists: $path"
done

if grep -Eq '^src-git .*(easytier|ac_agent)' feeds.conf.default; then
	err "feeds.conf.default still contains easytier/ac_agent"
fi
if grep -qx 'CONFIG_FEED_ac_agent=y' 2010.config; then
	err "2010.config still enables the ac_agent feed"
fi

if grep -Eq '1710\.config|040(-tf)?\.config|config_seed' .github/workflows/build-firmware.yml; then
	err "build workflow still references other configs"
fi
grep -q '2010\.config' .github/workflows/build-firmware.yml \
	|| err "build workflow does not use 2010.config"

if grep -RInE 'Device/(airoha_an7581-evb|gemtek_w1700k-ubi|nokia_|gemtek_xr1710g|quantum_q1000k)|TARGET_DEVICES \+= (airoha_an7581-evb|gemtek_w1700k-ubi|nokia_|gemtek_xr1710g|quantum_q1000k)' \
	target/linux/airoha/image/; then
	err "non-XG2010G device definitions remain"
fi

if grep -RInE 'gemtek,(xr1710g|w1700k)|nokia,|quantum,|fiberhome,|znxt,|unionman,' \
	target/linux/airoha/base-files target/linux/airoha/an7581/base-files; then
	err "non-XG2010G board branches remain"
fi

(( fail == 0 )) || exit 1
echo "check-xg2010g-only: ok"
