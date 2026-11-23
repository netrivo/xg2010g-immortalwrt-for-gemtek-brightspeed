# ImmortalWrt for Gemtek XG2010G

**English** · [简体中文 →](README.md)

[![Build](https://img.shields.io/github/actions/workflow/status/netrivo/xg2010g-immortalwrt-for-gemtek-brightspeed/build-firmware.yml?branch=main&label=Build)](https://github.com/netrivo/xg2010g-immortalwrt-for-gemtek-brightspeed/actions/workflows/build-firmware.yml)
[![Upstream](https://img.shields.io/badge/upstream-immortalwrt-blue)](https://github.com/immortalwrt/immortalwrt)
[![Kernel](https://img.shields.io/badge/kernel-6.18-red)](target/linux/generic/kernel-6.18)
[![SoC](https://img.shields.io/badge/SoC-Airoha%20AN7581-orange)](target/linux/airoha)
[![License](https://img.shields.io/badge/license-GPL--2.0-green)](COPYING)

An [ImmortalWrt](https://github.com/immortalwrt/immortalwrt)-based firmware repository for the Gemtek XG2010G
XG(S)-PON gateway. The code base is the 2026-11-13 snapshot of `netrivo/ImmortalWrt-for-Gemtek-brightspeed`
(the commit is recorded in [`.brightspeed-upstream`](.brightspeed-upstream)). This repository **maintains the
XG2010G only**; device definitions, DTS files and configs for the XR1710G, Nokia XG-040G and other boards have
been removed.

- Kernel: Linux 6.18 (currently `6.18.60`, see [`target/linux/generic/kernel-6.18`](target/linux/generic/kernel-6.18))
- Target: `airoha/an7581`, aarch64 Cortex-A53, musl, `apk` package manager
- Significant feature, stability and patch changes are recorded in [CHANGELOG.md](CHANGELOG.md) (Chinese)

> [!WARNING]
> This firmware is for the Gemtek XG2010G only. Do not flash it on an XR1710G or any other AN7581 device.
> On the XG2010G itself, stock-layout and UBI-layout images cannot be interchanged either
> (see [Boot and partition layouts](#boot-and-partition-layouts)).

## Contents

[Quick start](#quick-start) · [Hardware](#hardware) · [Factory defaults](#factory-defaults) ·
[Boot and partition layouts](#boot-and-partition-layouts) · [Package policy](#package-policy) ·
[Upgrades and package restore](#upgrades-and-package-restore) · [Building](#building) ·
[Syncing brightspeed updates](#syncing-brightspeed-updates) · [Check scripts](#check-scripts) ·
[Repository layout](#repository-layout) · [Technical notes](#technical-notes) · [Credits](#credits) · [License](#license)

## Quick start

**1. Download and verify an image.** From [Releases](https://github.com/netrivo/xg2010g-immortalwrt-for-gemtek-brightspeed/releases),
download `*-gemtek_xg2010g-ubi-squashfs-sysupgrade.itb`. Each release contains only this one firmware file; its
SHA256 is in the release notes, so check it after downloading:

```bash
sha256sum immortalwrt-*-gemtek_xg2010g-ubi-squashfs-sysupgrade.itb
```

The package manifest (`*.manifest`) and `*.buildinfo` files are in the matching build's Actions artifacts (kept for 30 days).

**2. Flash.**

- Already running this firmware: LuCI → System → Backup / Flash Firmware → Flash image, with "Keep settings"
  checked. Packages you installed yourself are reinstalled automatically after reboot
  (see [Upgrades and package restore](#upgrades-and-package-restore)).
- First flash, or switching from stock or another third-party firmware: read
  [Boot and partition layouts](#boot-and-partition-layouts) first, confirm the current U-Boot and partition
  layout over serial, and back up the stock partitions.

**3. Change the password right after the first login.** `root` has no password by default and the management
URL is `http://192.168.1.1`. Also review the firewall and SSH settings, then check the optical link and hardware
offload on the PON status and NPU pages.

## Hardware

| Item | Details |
| --- | --- |
| SoC | Airoha/Econet AN7581 / EN7581 |
| CPU | 4x Cortex-A53, ARM64 |
| Memory | 1 GiB or 2 GiB DDR4 (U-Boot passes the actual size; one image fits both) |
| Flash | Winbond W25N04K SPI-NAND, 512 MiB |
| 10G ports x2 | RTL8261N, MDIO addresses 5 / 8 |
| 2.5G port x1 | Airoha EN8811H, MDIO address 0xf |
| 1G port x1 | Built-in switch ePHY |
| PON | EN7572 BOSA, XGPON |
| Voice | AN7581 PCM/SPI (`kmod-airoha-en7581-pcm-spi`); debug notes in [docs/xg2010g-voice-debug.md](docs/xg2010g-voice-debug.md) |
| Wi-Fi / USB / eMMC | No usable module or physical interface |

Device trees: [`an7581-gemtek-xg2010g-ubi.dts`](target/linux/airoha/dts/an7581-gemtek-xg2010g-ubi.dts) (UBI layout) and
[`an7581-xg2010g.dts`](target/linux/airoha/dts/an7581-xg2010g.dts) (stock layout).
Device definitions live in [`target/linux/airoha/image/an7581.mk`](target/linux/airoha/image/an7581.mk).

## Factory defaults

| Item | Default |
| --- | --- |
| Management URL | `http://192.168.1.1` or `http://immortalwrt.lan` |
| Username / password | `root` / no password |
| Hostname | `XG2010G` |
| LAN | `lan1 lan2 lan3 lan4` (panel order: two 10G, 2.5G, 1G) |
| WAN | `pon0` |
| Theme | `luci-theme-argon`, with `luci-theme-bootstrap` as fallback |
| Wi-Fi | None |

Port mapping is defined in [`02_network`](target/linux/airoha/an7581/base-files/etc/board.d/02_network).
After the first flash, run `scripts/check-xg2010g-network.sh` on the device to verify LAN, fw4 and DHCP.

## Boot and partition layouts

| Profile | Boot chain | Partitions |
| --- | --- | --- |
| `gemtek_xg2010g` | Stock bootloader + chainloader U-Boot | `bootloader` / `uenv` / `dsd` / `chainloader@0x600000` / `system` UBI@0x700000 |
| `gemtek_xg2010g-ubi` | OpenWrt U-Boot (`xg2010g` / `xg2010g-2g` targets of [naoki66/uboot-an758x](https://github.com/naoki66/uboot-an758x)) | `bl2@0` / `ubi@0x20000` (fip, ubootenv, ubootenv2, factory, fit) |

The default `2010.config` selects only `gemtek_xg2010g-ubi`, and CI and releases produce only that image.
Its `SUPPORTED_DEVICES` accepts `gemtek,xg2010g-ubi`, `gemtek,xg2010g` and the old `-2g` variants, so 1 GiB and
2 GiB boards use the same image.

> [!WARNING]
> - Never mix the two layouts. The UBI-layout image carries `DEVICE_COMPAT_VERSION 2.0`; **never force an
>   upgrade from the legacy `0x00600000` layout**.
> - Before the first flash, confirm over serial that the running U-Boot matches the chosen profile, and take a
>   full NAND backup — at minimum `bootloader`, `uenv`, `dsd`, `factory`/`art` and calibration data.
> - Upgrades only rewrite the `fit` volume inside `ubi`; `bl2`, `fip`, `ubootenv`, `ubootenv2`, `factory` and
>   `reserved_bmt` must be preserved.
> - `fit` is a dynamic volume that sysupgrade and U-Boot recreate to the new image size; the image limit is set
>   by `IMAGE_SIZE` (currently 128 MiB).

## Package policy

The default image keeps only XG2010G/PON/system management packages and the Argon theme. Optional packages —
proxies, push notifications, media, remote networking and so on — are listed in
[`scripts/xg2010g-package-policy.txt`](scripts/xg2010g-package-policy.txt). They are not installed into the image
but built as `=m` modules. The `.apk` files from the `helloworld` and `pushbot` feeds are published to a per-build
extras repository; everything else installs from the official ImmortalWrt distfeeds. The image installer only
installs `=y` packages, so `=m` adds nothing to the image size.

`2010.config` and `feeds.conf.default` are local policy files: syncing brightspeed keeps this repository's version
and prints the upstream diff for manual review instead of merging it.

- The UI uses `luci-theme-argon` (jerrykuku's argon feed), with `luci-theme-bootstrap` as fallback.
- Simplified Chinese translations of optional apps (`luci-i18n-*-zh-cn`) are built as `=m` with their apps and are
  not in the image; those belonging to `helloworld`/`pushbot` are published with the extras, the rest install from
  the official LuCI feed.
- PON/ONU tools (`luci-app-onu`, `luci-app-pon-status`, `luci-app-clients`, `luci-app-airoha-npu`) are part of the
  device base and stay in the image.
- To put an optional package into the image: delete its line from `scripts/xg2010g-package-policy.txt`, set it to
  `y` in `2010.config`, then rerun the policy check and the build.
- For packages that should only be installed on the device: leave the policy line alone and install them from the
  extras repository after the build.

### Feeds

| Feed | Source | Purpose |
| --- | --- | --- |
| `packages` / `luci` | immortalwrt | Official packages and LuCI, served at runtime by distfeeds |
| `routing` / `telephony` | openwrt | Official packages, served at runtime by distfeeds |
| `argon` | jerrykuku/luci-theme-argon | Default theme (local patches in `patches/feeds/argon/`) |
| `app_airoha` | naoki66/luci-app-airoha | Airoha LuCI apps: NPU, fan, network mode, etc. |
| `pon_drivers` | naoki66/openwrt-pon-drivers | PON kernel drivers |
| `onu_config` | naoki66/OpenWrt_ONU_CONFIG | PON/ONU user space and LuCI |
| `helloworld` | fw876/helloworld (`dev` branch) | Optional proxy apps, published as extras |
| `pushbot` | naoki66/luci-app-pushbot | Optional push app, published as extras |

See [`feeds.conf.default`](feeds.conf.default) for the full definition. Local changes to feeds live in
[`patches/feeds/`](patches/feeds) and are applied by `scripts/apply-feed-patches.sh`.

## Upgrades and package restore

On the XG2010G, `sysupgrade` writes the list of installed packages to `/etc/backup/installed_packages.txt` and the
services that were disabled to `/etc/backup/disabled_services.txt` in the backup. After the upgrade reboots, the
`xg2010g-restore-packages` service in the new image runs in the background and:

1. Only handles packages that lived in the old image's overlay (packages the user installed); packages preinstalled
   in the old ROM are not carried into the minimal image.
2. Skips packages already present in the new image, then runs `apk update` and `apk add`.
3. Never gives up while the package feeds are unreachable (PON registration or PPPoE still in progress, upstream
   down) and does not wait for a reboot: it retries every 10 s for the first 5 minutes, then every 5 minutes.
4. After each install round, stops and disables again any service that was disabled before the upgrade but was
   re-enabled by a package's install script, so services keep their pre-upgrade state.
5. If the feeds work but some packages still fail (for example a package was removed), retries every 5 minutes for
   up to 6 rounds, then keeps the list until the next boot. Both lists are deleted once everything succeeds. The log
   is `/tmp/xg2010g-restore.log`, also available via `logread -e xg2010g-restore`.

`/etc/config/` and the config directories of common apps survive upgrades through
[`package/base-files/files/lib/upgrade/keep.d/xg2010g-configs`](package/base-files/files/lib/upgrade/keep.d/xg2010g-configs).
Only put configuration there — no app binaries or large rule sets — because sysupgrade builds the backup in `/tmp`
(RAM) before flashing.

The extras repository is published on this repository's `packages` branch, one directory per build ID, keeping
only the 3 most recent builds:

```text
https://raw.githubusercontent.com/<owner>/<repo>/packages/<build-id>/<feed>/packages.adb
```

Each build ID directory contains `helloworld/`, `pushbot/` and `kmods/` (every `kmod-*` for that kernel).
`/etc/apk/repositories.d/xg2010g.list` in the image is generated at build time by `scripts/set-extras-repo.sh` and
points at the same build ID. Indexes and modules are signed with that build's APK key, whose public key ships in
the image. CI publishes the extras automatically; a local build that does not publish them makes the restore
service log a failure and keep its list, without affecting boot. On the device, run `apk update` and then
`apk add <package>`; the LuCI software page lists these feeds too.

> [!NOTE]
> - The first flash from the original author's full image to this minimal image is a reinstall: the old image's
>   `sysupgrade` does not record a package list, so reinstall your apps once by hand. Later OTA upgrades within
>   this repository restore them automatically.
> - Never install `kmod-*` from an older firmware's feed; kernel modules must match the running kernel exactly.
> - A build ID's extras are deleted when the third newer build is published. Devices that have not been upgraded
>   for a while should move to a recent release before installing packages from the extras.

## Building

### GitHub Actions (recommended)

The [Build XG2010G Firmware](.github/workflows/build-firmware.yml) workflow is manual only
(Actions → Build XG2010G Firmware → Run workflow); pushes never start a build. A full build takes about 3.5 hours.

| Input | Meaning |
| --- | --- |
| `release_type` | `none`: upload Actions artifacts only; `release` / `prerelease`: also create a GitHub Release |
| `release_notes` | Release notes, optional |

A build:

1. Derives the build ID `<YYYYMMDD>-<8-char repo commit>-<8-char brightspeed commit>` (date in Asia/Shanghai).
2. Updates and installs feeds, selects feed providers and applies `patches/feeds/`.
3. Writes the extras feed URLs, applies the package policy, sets version info and runs the config checks
   (distfeeds, profile isolation, XG2010G-only).
4. Downloads sources and builds `world`; on failure it rebuilds the first failing package with `V=s` and prints an
   error summary.
5. Checks the image and manifest, then publishes the extras to the `packages` branch.
6. Uploads artifacts (kept for 30 days). With a release selected, it creates tag `<YYYYMMDD>-<commit>` and uploads
   **only the single `.itb` image**, with its SHA256 in the release notes. Publishing fails unless exactly one
   image was built.

### Local build

Requirements: x86_64 GNU/Linux (Debian 12+ / Ubuntu 22.04+ recommended) with at least 4 GB RAM; optional packages
are built as `=m` too, so leave plenty of disk space. Keep the checkout path short (for example `~/w`): long paths
push host Python install paths past OpenWrt's 124-character limit.

```bash
sudo apt update
sudo apt install build-essential clang gcc g++ binutils bzip2 gawk gettext git \
  libncurses-dev libssl-dev python3 python3-setuptools rsync unzip wget \
  xsltproc zlib1g-dev file which perl sed make

./scripts/feeds update -a
./scripts/feeds install -a
bash scripts/fix-stale-golang-host.sh
bash scripts/select-feed-providers.sh
bash scripts/apply-feed-patches.sh

# Optional: write the extras feed URLs (only useful if you also publish extras to a packages branch)
# bash scripts/set-extras-repo.sh <owner/repo> <build-id>

bash scripts/apply-xg2010g-package-policy.sh 2010.config
cp 2010.config .config
make defconfig
bash scripts/set-build-version.sh .config
bash scripts/check-xg2010g-only.sh

make download -j$(nproc)
make -j$(nproc) world 2>&1 | tee build.log
bash scripts/summarize-build-errors.sh build.log   # error summary on failure
```

> [!NOTE]
> `make defconfig` and `make menuconfig` only change `.config`, never `2010.config`. Rerun
> `bash scripts/set-build-version.sh .config` after either one, otherwise `CONFIG_VERSION_*`,
> `CONFIG_TARGET_HOSTNAME` and related fields fall back to defaults. Copy any config change you want to keep back
> into `2010.config` by hand.

`world` builds the `=m` optional packages into `bin/packages/` without installing them into the image. CI also
publishes `helloworld`, `pushbot` and the kernel modules to the `packages` branch and writes the extras feed URLs
into the image; a local build that does not need extras can skip publishing and the image still works.

### Output

Output lands in `bin/targets/airoha/an7581/`:

| File | Meaning |
| --- | --- |
| `immortalwrt-naoki66-<YYYYMMDD>-<commit>-airoha-an7581-gemtek_xg2010g-ubi-squashfs-sysupgrade.itb` | sysupgrade image |
| `*.manifest` | Packages in the image |
| `config.buildinfo` / `feeds.buildinfo` / `version.buildinfo` | Build config, feed revisions and version info |
| `sha256sums` | Checksums |

GitHub Releases publish only the `.itb` in the first row; everything else stays in the Actions artifacts.

File names contain only `date-repo-commit`; the full build ID (including the brightspeed commit) is written to
`CONFIG_VERSION_CODE` and shown on the LuCI status page and in `/etc/openwrt_release`.

## Syncing brightspeed updates

This repository no longer merges ImmortalWrt upstream directly; it follows snapshots of the brightspeed repository
([naoki66/ImmortalWrt-for-Gemtek-brightspeed](https://github.com/naoki66/ImmortalWrt-for-Gemtek-brightspeed)).
[`.brightspeed-upstream`](.brightspeed-upstream) records the last imported brightspeed commit.

Every upstream update goes through **issue → assignment → PR → close**:

1. [Watch Brightspeed Upstream](.github/workflows/watch-brightspeed.yml) compares upstream `master` with
   `.brightspeed-upstream` daily at 09:00 Asia/Shanghai. When there are new commits it opens an issue labelled
   `upstream-sync`, lists the commits and assigns it to the maintainer. If a sync issue is already open it updates
   that issue and adds a comment instead of opening another. It can also be run manually from Actions.
2. The maintainer syncs, checks and builds following the steps in the issue, then opens a PR whose description
   contains `Closes #<issue number>`.
3. Merging the PR closes the issue.

The `source` in `.brightspeed-upstream` currently points at the fork `netrivo/ImmortalWrt-for-Gemtek-brightspeed`;
run `gh repo sync netrivo/ImmortalWrt-for-Gemtek-brightspeed` first so the fork catches up with naoki66. To sync:

```bash
git switch main
git pull
bash scripts/sync-brightspeed.sh
```

The script runs a three-way merge with `git merge-tree --merge-base=<last snapshot>` and then reapplies the
XG2010G-only trim with `scripts/apply-xg2010g-trim.sh`. If conflicts fall only in device definitions, DTS files or
removed paths, it retries with `-X ours`, keeping the local trim while taking upstream XG2010G changes. Any other
conflict stops the script; resolve it as prompted and commit.

`2010.config` and `feeds.conf.default` always keep this repository's version. If upstream changed them, the script
saves the upstream diff to `/tmp/brightspeed-config-*.diff`; cherry-pick what you want by hand.

After syncing, run the [check scripts](#check-scripts) and trigger a build in Actions to confirm it compiles.

## Check scripts

| Script | Runs on | Purpose |
| --- | --- | --- |
| `scripts/check-xg2010g-only.sh` | Build host | Confirms only XG2010G device definitions, DTS and configs remain |
| `scripts/check-pon-link-watchdog.sh` | Build host | Regression tests for the PON link watchdog (`files/usr/sbin/pon-link-watchdog`), with device commands mocked |
| `scripts/check-distfeeds.sh` | Build host | Ensures runtime distfeeds list only officially published feeds |
| `scripts/check-gemtek-profile-isolation.sh` | Build host | Ensures `.config`, kernel config and manifest contain no other board's packages |
| `scripts/check-firmware-artifacts.sh` | Build host | Ensures the selected profile's sysupgrade image was produced |
| `scripts/check-xg2010g-network.sh` | Device | Verifies LAN, fw4 and DHCP after flashing |

Typical pre-commit checks:

```bash
bash scripts/check-xg2010g-only.sh
bash scripts/check-pon-link-watchdog.sh
```

## Repository layout

| Path | Contents |
| --- | --- |
| `2010.config` | XG2010G seed config (local policy file) |
| `feeds.conf.default` | Feed list (local policy file) |
| `.brightspeed-upstream` | Last synced brightspeed commit and date |
| `target/linux/airoha/` | AN7581 target: device definitions, DTS, kernel patches, base-files |
| `package/` | Package definitions, including the sysupgrade keep list and package restore service |
| `files/` | Files copied straight into the image (PON link watchdog, generated extras feed list) |
| `patches/feeds/` | Local patches for third-party feeds |
| `scripts/` | Build, package policy, trim, sync and check scripts |
| `docs/` | Technical notes and troubleshooting records (Chinese) |
| `.github/workflows/build-firmware.yml` | CI build and release |
| `.github/workflows/watch-brightspeed.yml` | Watches brightspeed upstream and opens/assigns sync issues |

## Technical notes

These documents are written in Chinese.

- [Airoha bridge flowtable offload](docs/airoha-bridge-flowtable-offload.md)
- [Airoha PPE PPPoE bridge offload](docs/airoha-ppe-pppoe-bridge-offload.md) and its [verification](docs/airoha-bridge-pppoe-offload-verification.md)
- [AN7581 CPU clock policy](docs/an7581-cpu-clock-policy.md)
- [PON RX stall recovery (2026-11-08)](docs/pon-rx-stall-recovery-20261108.md)
- [pppd TDB script child use-after-free](docs/pppd-tdb-script-child-use-after-free.md)
- [XG2010G voice debugging](docs/xg2010g-voice-debug.md)
- [XG2010G-only trim design](docs/superpowers/specs/2026-11-20-xg2010g-only-design.md) and [implementation plan](docs/superpowers/plans/2026-11-20-xg2010g-only-merge.md)

## Credits

- [immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt), [immortalwrt/luci](https://github.com/immortalwrt/luci), [immortalwrt/packages](https://github.com/immortalwrt/packages): upstream firmware, LuCI and packages
- [naoki66/ImmortalWrt-for-Gemtek-brightspeed](https://github.com/naoki66/ImmortalWrt-for-Gemtek-brightspeed): the original project this code base comes from
- [naoki66/uboot-an758x](https://github.com/naoki66/uboot-an758x) (from [pbs05/uboot-an758x](https://github.com/pbs05/uboot-an758x)): OpenWrt U-Boot / UBI boot used by the XG2010G
- [naoki66/openwrt-pon-drivers](https://github.com/naoki66/openwrt-pon-drivers) (from [pbs05/openwrt-pon-drivers](https://github.com/pbs05/openwrt-pon-drivers)): PON drivers
- [naoki66/OpenWrt_ONU_CONFIG](https://github.com/naoki66/OpenWrt_ONU_CONFIG) (from [pbs05/openwrt-pon-userspace](https://github.com/pbs05/openwrt-pon-userspace)): PON user space
- [naoki66/luci-app-airoha](https://github.com/naoki66/luci-app-airoha): Airoha-specific LuCI apps
- [jerrykuku/luci-theme-argon](https://github.com/jerrykuku/luci-theme-argon): Argon theme

## License

[GPL-2.0-only](COPYING), inherited from ImmortalWrt. Third-party license texts are in [`LICENSES/`](LICENSES).
