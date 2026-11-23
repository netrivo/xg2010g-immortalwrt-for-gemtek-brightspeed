# ImmortalWrt for Gemtek XG2010G

**简体中文** · [English →](README.en.md)

[![Build](https://img.shields.io/github/actions/workflow/status/netrivo/xg2010g-immortalwrt-for-gemtek-brightspeed/build-firmware.yml?branch=main&label=Build)](https://github.com/netrivo/xg2010g-immortalwrt-for-gemtek-brightspeed/actions/workflows/build-firmware.yml)
[![Upstream](https://img.shields.io/badge/upstream-immortalwrt-blue)](https://github.com/immortalwrt/immortalwrt)
[![Kernel](https://img.shields.io/badge/kernel-6.18-red)](target/linux/generic/kernel-6.18)
[![SoC](https://img.shields.io/badge/SoC-Airoha%20AN7581-orange)](target/linux/airoha)
[![License](https://img.shields.io/badge/license-GPL--2.0-green)](COPYING)

基于 [ImmortalWrt](https://github.com/immortalwrt/immortalwrt) 的 Gemtek XG2010G（XG(S)-PON 网关）固件仓库。
代码基线来自 `netrivo/ImmortalWrt-for-Gemtek-brightspeed` 的 2026-11-13 快照
（commit 记录在 [`.brightspeed-upstream`](.brightspeed-upstream)），本仓库**只维护 XG2010G**，
XR1710G、Nokia XG-040G 等其他机型的设备定义、DTS 和配置均已精简。

- 内核：Linux 6.18（当前 `6.18.60`，见 [`target/linux/generic/kernel-6.18`](target/linux/generic/kernel-6.18)）
- 目标：`airoha/an7581`，aarch64 Cortex-A53，musl，包管理器 `apk`
- 重要的功能、稳定性和补丁变更记录在 [CHANGELOG.md](CHANGELOG.md)

> [!WARNING]
> 本固件只适用于 Gemtek XG2010G。不要刷到 XR1710G 或其他 AN7581 设备上；同一台 XG2010G 上，
> 原厂布局和 UBI 布局的镜像也不能混刷（见[启动与分区布局](#启动与分区布局)）。

## 目录

[快速开始](#快速开始) · [硬件概览](#硬件概览) · [出厂默认设置](#出厂默认设置) ·
[启动与分区布局](#启动与分区布局) · [默认包策略](#默认包策略) · [升级和插件恢复](#升级和插件恢复) ·
[构建](#构建) · [同步 brightspeed 更新](#同步-brightspeed-更新) · [检查脚本](#检查脚本) ·
[仓库结构](#仓库结构) · [技术文档](#技术文档) · [致谢](#致谢) · [许可证](#许可证)

## 快速开始

**1. 下载并校验固件。** 在 [Releases](https://github.com/netrivo/xg2010g-immortalwrt-for-gemtek-brightspeed/releases)
下载 `*-gemtek_xg2010g-ubi-squashfs-sysupgrade.itb`。每个 Release 只包含这一个固件文件，
SHA256 写在 Release 说明里，下载后核对：

```bash
sha256sum immortalwrt-*-gemtek_xg2010g-ubi-squashfs-sysupgrade.itb
```

包清单（`*.manifest`）和 `*.buildinfo` 在对应构建的 Actions 构件里（保留 30 天）。

**2. 刷机。**

- 已经运行本仓库固件：LuCI → 系统 → 备份/升级 → 刷写固件，勾选“保留配置”即可。
  用户自己装的插件会在重启后自动重装（见[升级和插件恢复](#升级和插件恢复)）。
- 第一次刷入，或从原厂固件/其他第三方固件切换：先读[启动与分区布局](#启动与分区布局)，
  通过串口确认当前 U-Boot 和分区布局，并备份原厂分区。

**3. 首次登录后立刻修改密码。** 默认 `root` 无密码，管理地址 `http://192.168.1.1`。
建议同时检查防火墙和 SSH 设置，然后在 PON 状态、NPU 页面确认光链路和硬件加速状态。

## 硬件概览

| 项目 | 信息 |
| --- | --- |
| SoC | Airoha/Econet AN7581 / EN7581 |
| CPU | 4x Cortex-A53，ARM64 |
| 内存 | 1 GiB 或 2 GiB DDR4（U-Boot 传递实际大小，同一镜像通用） |
| 闪存 | Winbond W25N04K SPI-NAND，512 MiB |
| 10G 网口 x2 | RTL8261N，MDIO 地址 5 / 8 |
| 2.5G 网口 x1 | Airoha EN8811H，MDIO 地址 0xf |
| 1G 网口 x1 | 内置交换机 ePHY |
| PON | EN7572 BOSA，XGPON |
| 语音 | AN7581 PCM/SPI（`kmod-airoha-en7581-pcm-spi`），调试记录见 [docs/xg2010g-voice-debug.md](docs/xg2010g-voice-debug.md) |
| 无线 / USB / eMMC | 无可用模块或物理接口 |

设备树：[`an7581-gemtek-xg2010g-ubi.dts`](target/linux/airoha/dts/an7581-gemtek-xg2010g-ubi.dts)（UBI 布局）、
[`an7581-xg2010g.dts`](target/linux/airoha/dts/an7581-xg2010g.dts)（原厂布局）。
设备定义在 [`target/linux/airoha/image/an7581.mk`](target/linux/airoha/image/an7581.mk)。

## 出厂默认设置

| 项目 | 默认值 |
| --- | --- |
| 管理地址 | `http://192.168.1.1` 或 `http://immortalwrt.lan` |
| 用户名 / 密码 | `root` / 无密码 |
| 主机名 | `XG2010G` |
| LAN | `lan1 lan2 lan3 lan4`（面板顺序：两个 10G、2.5G、1G） |
| WAN | `pon0` |
| 主题 | `luci-theme-argon`，备用 `luci-theme-bootstrap` |
| 无线 | 无 |

端口映射见 [`02_network`](target/linux/airoha/an7581/base-files/etc/board.d/02_network)。
首次刷机后可以在设备上运行 `scripts/check-xg2010g-network.sh` 验证 LAN、fw4 和 DHCP。

## 启动与分区布局

| profile | 启动链 | 分区 |
| --- | --- | --- |
| `gemtek_xg2010g` | 原厂 bootloader + chainloader U-Boot | `bootloader` / `uenv` / `dsd` / `chainloader@0x600000` / `system` UBI@0x700000 |
| `gemtek_xg2010g-ubi` | OpenWrt U-Boot（[naoki66/uboot-an758x](https://github.com/naoki66/uboot-an758x) 的 `xg2010g` / `xg2010g-2g` 目标） | `bl2@0` / `ubi@0x20000`（fip、ubootenv、ubootenv2、factory、fit） |

默认构建 `2010.config` 只选择 `gemtek_xg2010g-ubi`，CI 和 Release 也只产出这一种镜像。
它的 `SUPPORTED_DEVICES` 同时接受 `gemtek,xg2010g-ubi`、`gemtek,xg2010g` 以及旧的 `-2g` 变体，
所以 1 GiB 和 2 GiB 机器都使用同一个镜像。

> [!WARNING]
> - 两种布局不能混刷。UBI 布局镜像带有 `DEVICE_COMPAT_VERSION 2.0`，**不要从旧的 `0x00600000`
>   布局强制升级**。
> - 首次刷机前通过串口确认当前 U-Boot 与所选 profile 匹配，并完整备份 NAND，至少备份
>   `bootloader`、`uenv`、`dsd`、`factory`/`art` 和校准数据。
> - 升级时只写 `ubi` 中的 `fit` 卷；`bl2`、`fip`、`ubootenv`、`ubootenv2`、`factory` 和
>   `reserved_bmt` 必须保留。
> - `fit` 是动态卷，sysupgrade 和 U-Boot 会按新镜像大小重建；镜像上限由 `IMAGE_SIZE`
>   控制（当前 128 MiB）。

## 默认包策略

默认镜像只保留 XG2010G/PON/系统管理和 Argon 主题；代理、推送、媒体、远程组网等可选包由
[`scripts/xg2010g-package-policy.txt`](scripts/xg2010g-package-policy.txt) 管理。这些可选包不会安装进镜像，而是以 `=m` 模块方式
编译；`helloworld`、`pushbot` 两个 feed 的 `.apk` 会发布到每次构建对应的 extras 仓库，
其余包从官方 ImmortalWrt distfeeds 安装。镜像安装器只安装 `=y` 包，所以 `=m` 不会增加
默认镜像体积。

`2010.config` 和 `feeds.conf.default` 是本地策略文件：同步 brightspeed 时保留本仓库版本，
上游改动会输出 diff 供人工挑选，不会被自动合入。

- 当前 UI 使用 `luci-theme-argon`（jerrykuku 的 argon feed），`luci-theme-bootstrap` 作为备用主题。
- 可选插件的简体中文翻译包（`luci-i18n-*-zh-cn`）随插件以 `=m` 编译，不进入镜像；
  属于 `helloworld`/`pushbot` 的翻译包随 extras 发布，其余从官方 LuCI 源安装。
- PON/ONU 工具（`luci-app-onu`、`luci-app-pon-status`、`luci-app-clients`、`luci-app-airoha-npu`）
  属于设备基础，保留。
- 要让某个可选包进入镜像：从 `scripts/xg2010g-package-policy.txt` 删除对应行，把
  `2010.config` 里的包设为 `y`，然后重新运行策略检查和构建。
- 只安装到设备、不进入镜像的包：保持策略文件中的行不变，构建后从 extras 仓库安装即可。

### feed 一览

| feed | 来源 | 用途 |
| --- | --- | --- |
| `packages` / `luci` | immortalwrt | 官方包和 LuCI，运行时由 distfeeds 提供 |
| `routing` / `telephony` | openwrt | 官方包，运行时由 distfeeds 提供 |
| `argon` | jerrykuku/luci-theme-argon | 默认主题（本地补丁在 `patches/feeds/argon/`） |
| `app_airoha` | naoki66/luci-app-airoha | NPU、风扇、网络模式等 Airoha LuCI 应用 |
| `pon_drivers` | naoki66/openwrt-pon-drivers | PON 内核驱动 |
| `onu_config` | naoki66/OpenWrt_ONU_CONFIG | PON/ONU 用户态和 LuCI |
| `helloworld` | fw876/helloworld（`dev` 分支） | 可选代理插件，随 extras 发布 |
| `pushbot` | naoki66/luci-app-pushbot | 可选推送插件，随 extras 发布 |

完整定义见 [`feeds.conf.default`](feeds.conf.default)；对 feed 的本地修改放在 [`patches/feeds/`](patches/feeds)，
由 `scripts/apply-feed-patches.sh` 应用。

## 升级和插件恢复

XG2010G 的 `sysupgrade` 默认会把当前已安装包列表写入备份里的
`/etc/backup/installed_packages.txt`。升级重启后，新镜像里的
`xg2010g-restore-packages` 服务会：

1. 只处理旧镜像中位于 overlay 的包（用户自己安装的插件）；旧镜像 ROM 里预装的包不会
   被带进最小镜像。
2. 跳过新镜像里已经存在的包，等待网络后执行 `apk update` 和 `apk add`。
3. 失败时保留列表，下次启动继续重试；全部成功后删除列表。日志在
   `/tmp/xg2010g-restore.log`，也可以用 `logread -e xg2010g-restore` 查看。

`/etc/config/` 和常见插件的配置目录通过
[`package/base-files/files/lib/upgrade/keep.d/xg2010g-configs`](package/base-files/files/lib/upgrade/keep.d/xg2010g-configs)
跨升级保留。这里只放配置，不要加入插件二进制或大型规则集，因为 sysupgrade 在刷写前用 `/tmp`（内存）生成备份。

extras 仓库发布在本仓库的 `packages` 分支，按 build ID 分目录，只保留最近 3 次构建：

```text
https://raw.githubusercontent.com/<owner>/<repo>/packages/<build-id>/<feed>/packages.adb
```

每个 build ID 目录下有 `helloworld/`、`pushbot/` 和 `kmods/`（本次内核对应的全部 `kmod-*`）。
镜像里的 `/etc/apk/repositories.d/xg2010g.list` 由 `scripts/set-extras-repo.sh` 在构建时生成，
指向同一 build ID。索引和模块使用该次构建的 APK 签名密钥，镜像内置对应公钥。CI 构建会
自动发布；本地构建如果不发布 extras，恢复服务会记录失败并保留列表，不影响系统启动。
设备上执行 `apk update` 后即可用 `apk add <包名>` 安装，LuCI 软件包页面也会显示这些源。

> [!NOTE]
> - 第一次从作者完整镜像刷到本仓库的最小镜像属于重装，旧镜像的 `sysupgrade` 不会生成包列表，
>   需要在刷机后手动安装一次插件；从这之后的本仓库 OTA 会自动恢复。
> - 不要从旧固件的源安装 `kmod-*`，内核模块必须和当前内核完全匹配。
> - 一个 build ID 的 extras 在之后第 3 次新构建发布时会被删除。长期不升级的设备如果需要
>   安装 extras 里的包，请先升级到较新的 Release。

## 构建

### GitHub Actions（推荐）

工作流 [Build XG2010G Firmware](.github/workflows/build-firmware.yml) 只能手动触发
（Actions → Build XG2010G Firmware → Run workflow），推送代码不会自动编译。完整构建约 3.5 小时。

| 输入 | 说明 |
| --- | --- |
| `release_type` | `none`：只上传 Actions 构件；`release` / `prerelease`：同时创建 GitHub Release |
| `release_notes` | Release 说明，可留空 |

一次构建会：

1. 生成 build ID：`<YYYYMMDD>-<本仓库 commit 8 位>-<brightspeed commit 8 位>`（日期按 Asia/Shanghai）。
2. 更新并安装 feeds，选择 feed provider，应用 `patches/feeds/` 补丁。
3. 生成 extras 源地址，应用包策略，写入版本信息，执行配置检查（distfeeds、profile 隔离、XG2010G-only）。
4. 下载源码并编译 `world`；失败时自动用 `V=s` 重编第一个失败的包并输出错误摘要。
5. 检查镜像和 manifest，发布 extras 到 `packages` 分支。
6. 上传构件（固件、manifest、buildinfo、日志，保留 30 天）；如果选择了 Release，则创建 tag
   `<YYYYMMDD>-<commit>`，**只上传一个 `.itb` 固件**，并把它的 SHA256 写进 Release 说明。
   镜像数量不是恰好一个时发布会失败。

### 本地构建

环境：x86_64 GNU/Linux（推荐 Debian 12+/Ubuntu 22.04+），至少 4 GB 内存；可选包也会以 `=m` 编译，磁盘空间请多预留。
仓库路径尽量短（例如 `~/w`），过长的路径会让 host Python 安装路径超过 OpenWrt 的 124 字符限制。

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

# 可选：生成 extras 源地址（只有在你也会把 extras 发布到 packages 分支时才有意义）
# bash scripts/set-extras-repo.sh <owner/repo> <build-id>

bash scripts/apply-xg2010g-package-policy.sh 2010.config
cp 2010.config .config
make defconfig
bash scripts/set-build-version.sh .config
bash scripts/check-xg2010g-only.sh

make download -j$(nproc)
make -j$(nproc) world 2>&1 | tee build.log
bash scripts/summarize-build-errors.sh build.log   # 失败时输出错误摘要
```

> [!NOTE]
> `make defconfig` 和 `make menuconfig` 只改 `.config`，不会改写 `2010.config`。执行它们之后要重新运行
> `bash scripts/set-build-version.sh .config`，否则 `CONFIG_VERSION_*`、`CONFIG_TARGET_HOSTNAME`
> 等版本信息会被默认值覆盖。要把配置改动保留下来，需要手动同步到 `2010.config`。

`world` 会编译 `=m` 的可选包并生成 `bin/packages/`，但不会把它们装进镜像。CI 构建还会把
`helloworld`、`pushbot` 和内核模块发布到 `packages` 分支并生成镜像里的 extras 源地址；
本地构建如果不需要 extras，可以跳过发布，镜像仍可正常使用。

### 产物

产物在 `bin/targets/airoha/an7581/`：

| 文件 | 说明 |
| --- | --- |
| `immortalwrt-naoki66-<YYYYMMDD>-<commit>-airoha-an7581-gemtek_xg2010g-ubi-squashfs-sysupgrade.itb` | sysupgrade 固件 |
| `*.manifest` | 镜像内的包清单 |
| `config.buildinfo` / `feeds.buildinfo` / `version.buildinfo` | 构建配置、feed 版本和版本信息 |
| `sha256sums` | 校验和 |

GitHub Release 只发布上表第一行的 `.itb`，其余文件只在 Actions 构件里。

文件名只包含 `日期-本仓库 commit`；完整的 build ID（含 brightspeed commit）写入 `CONFIG_VERSION_CODE`，
可在 LuCI 状态页和 `/etc/openwrt_release` 中查看。

## 同步 brightspeed 更新

本仓库不再直接合并 ImmortalWrt 上游，而是跟随 brightspeed 仓库
（[naoki66/ImmortalWrt-for-Gemtek-brightspeed](https://github.com/naoki66/ImmortalWrt-for-Gemtek-brightspeed)）的快照。
[`.brightspeed-upstream`](.brightspeed-upstream) 记录上次导入的 brightspeed commit。

每次上游更新都按 **issue → 指派 → PR → 关闭** 处理：

1. [Watch Brightspeed Upstream](.github/workflows/watch-brightspeed.yml) 每天 09:00（北京时间）比较上游 `master`
   和 `.brightspeed-upstream`，有新提交时创建一个带 `upstream-sync` 标签的 issue，列出新提交并指派给维护者；
   已有未关闭的同步 issue 时只更新它并追加评论，不会重复创建。也可以在 Actions 里手动运行。
2. 维护者按 issue 里的步骤同步、检查、编译，然后提 PR，在描述里写 `Closes #<issue 编号>`。
3. PR 合并后 issue 自动关闭。

`.brightspeed-upstream` 的 `source` 目前指向 fork `netrivo/ImmortalWrt-for-Gemtek-brightspeed`，
同步前先执行 `gh repo sync netrivo/ImmortalWrt-for-Gemtek-brightspeed` 让 fork 追上 naoki66。同步：

```bash
git switch main
git pull
bash scripts/sync-brightspeed.sh
```

脚本用 `git merge-tree --merge-base=<上次快照>` 做三点合并，然后执行
`scripts/apply-xg2010g-trim.sh` 重新应用 XG2010G-only 精简。如果冲突只落在设备定义、
DTS 或已删除路径内，脚本会用 `-X ours` 自动重试：保留本地裁剪，同时接受上游对
XG2010G 的修改。其他冲突仍会停下，按提示解决后再提交。

`2010.config` 和 `feeds.conf.default` 始终保留本仓库版本。如果上游改动了这两个文件，
脚本会把上游差异保存到 `/tmp/brightspeed-config-*.diff`，需要采纳时手动 cherry-pick。

同步完成后先运行[检查脚本](#检查脚本)，再在 Actions 中手动触发一次构建确认能编译通过。

## 检查脚本

| 脚本 | 运行位置 | 作用 |
| --- | --- | --- |
| `scripts/check-xg2010g-only.sh` | 构建主机 | 确认代码树里只剩 XG2010G 的设备定义、DTS 和配置 |
| `scripts/check-pon-link-watchdog.sh` | 构建主机 | PON 链路看门狗（`files/usr/sbin/pon-link-watchdog`）的回归测试，设备命令均为模拟 |
| `scripts/check-distfeeds.sh` | 构建主机 | 检查运行时 distfeeds 只包含官方发布的 feed |
| `scripts/check-gemtek-profile-isolation.sh` | 构建主机 | 检查 `.config`、内核配置和 manifest 没有混入其他机型的包 |
| `scripts/check-firmware-artifacts.sh` | 构建主机 | 检查所选 profile 的 sysupgrade 镜像确实生成 |
| `scripts/check-xg2010g-network.sh` | 设备 | 刷机后验证 LAN、fw4 和 DHCP |

常用的提交前检查：

```bash
bash scripts/check-xg2010g-only.sh
bash scripts/check-pon-link-watchdog.sh
```

## 仓库结构

| 路径 | 内容 |
| --- | --- |
| `2010.config` | XG2010G 种子配置（本地策略文件） |
| `feeds.conf.default` | feed 列表（本地策略文件） |
| `.brightspeed-upstream` | 上次同步的 brightspeed commit 和日期 |
| `target/linux/airoha/` | AN7581 target：设备定义、DTS、内核补丁、base-files |
| `package/` | 包定义，含 sysupgrade 配置保留列表和插件恢复服务 |
| `files/` | 直接打进镜像的文件（PON 链路看门狗、构建时生成的 extras 源地址） |
| `patches/feeds/` | 对第三方 feed 的本地补丁 |
| `scripts/` | 构建、包策略、裁剪、同步和检查脚本 |
| `docs/` | 技术文档和排障记录 |
| `.github/workflows/build-firmware.yml` | CI 构建与发布 |
| `.github/workflows/watch-brightspeed.yml` | 监控 brightspeed 上游，自动创建并指派同步 issue |

## 技术文档

- [Airoha 桥接 flowtable 卸载](docs/airoha-bridge-flowtable-offload.md)
- [Airoha PPE PPPoE 桥接卸载](docs/airoha-ppe-pppoe-bridge-offload.md) 及其[验证记录](docs/airoha-bridge-pppoe-offload-verification.md)
- [AN7581 CPU 频率策略](docs/an7581-cpu-clock-policy.md)
- [PON RX 停滞恢复（2026-11-08）](docs/pon-rx-stall-recovery-20261108.md)
- [pppd TDB 脚本子进程 use-after-free](docs/pppd-tdb-script-child-use-after-free.md)
- [XG2010G 语音调试](docs/xg2010g-voice-debug.md)
- [XG2010G-only 精简设计](docs/superpowers/specs/2026-11-20-xg2010g-only-design.md) 和[实施计划](docs/superpowers/plans/2026-11-20-xg2010g-only-merge.md)

## 致谢

- [immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt)、[immortalwrt/luci](https://github.com/immortalwrt/luci)、[immortalwrt/packages](https://github.com/immortalwrt/packages)：上游固件、LuCI 和软件包
- [naoki66/ImmortalWrt-for-Gemtek-brightspeed](https://github.com/naoki66/ImmortalWrt-for-Gemtek-brightspeed)：本仓库代码基线的原始项目
- [naoki66/uboot-an758x](https://github.com/naoki66/uboot-an758x)（源自 [pbs05/uboot-an758x](https://github.com/pbs05/uboot-an758x)）：XG2010G 使用的 OpenWrt U-Boot / UBI 启动方案
- [naoki66/openwrt-pon-drivers](https://github.com/naoki66/openwrt-pon-drivers)（源自 [pbs05/openwrt-pon-drivers](https://github.com/pbs05/openwrt-pon-drivers)）：PON 驱动
- [naoki66/OpenWrt_ONU_CONFIG](https://github.com/naoki66/OpenWrt_ONU_CONFIG)（源自 [pbs05/openwrt-pon-userspace](https://github.com/pbs05/openwrt-pon-userspace)）：PON 用户态
- [naoki66/luci-app-airoha](https://github.com/naoki66/luci-app-airoha)：Airoha 专用 LuCI 应用
- [jerrykuku/luci-theme-argon](https://github.com/jerrykuku/luci-theme-argon)：Argon 主题

## 许可证

继承 ImmortalWrt 的 [GPL-2.0-only](COPYING) 许可证，第三方组件的许可证见 [`LICENSES/`](LICENSES)。
