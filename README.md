# ImmortalWrt for Gemtek XG2010G

[![Build](https://img.shields.io/github/actions/workflow/status/netrivo/xg2010g-immortalwrt-for-gemtek-brightspeed/build-firmware.yml?branch=main&label=Build)](https://github.com/netrivo/xg2010g-immortalwrt-for-gemtek-brightspeed/actions/workflows/build-firmware.yml)
[![Upstream](https://img.shields.io/badge/upstream-immortalwrt-blue)](https://github.com/immortalwrt/immortalwrt)
[![Kernel](https://img.shields.io/badge/kernel-6.18-red)](target/linux/generic/kernel-6.18)
[![SoC](https://img.shields.io/badge/SoC-Airoha%20AN7581-orange)](target/linux/airoha)
[![License](https://img.shields.io/badge/license-GPL--2.0-green)](COPYING)

基于 [ImmortalWrt](https://github.com/immortalwrt/immortalwrt) 的 Gemtek XG2010G（XG(S)-PON 网关）固件仓库。
代码来自 [naoki66/ImmortalWrt-for-Gemtek-brightspeed](https://github.com/naoki66/ImmortalWrt-for-Gemtek-brightspeed)，
并持续同步它的更新（当前同步到的 commit 记录在 [`.brightspeed-upstream`](.brightspeed-upstream)）。本仓库**只维护 XG2010G**，
XR1710G、Nokia XG-040G 等其他机型的设备定义、DTS 和配置均已精简。

- 内核：Linux 6.18（当前 `6.18.60`，见 [`target/linux/generic/kernel-6.18`](target/linux/generic/kernel-6.18)）
- 目标：`airoha/an7581`，aarch64 Cortex-A53，musl，包管理器 `apk`
- 重要的功能、稳定性和补丁变更记录在 [CHANGELOG.md](CHANGELOG.md)

> [!WARNING]
> 本固件只适用于 Gemtek XG2010G。不要刷到 XR1710G 或其他 AN7581 设备上；同一台 XG2010G 上，
> 原厂布局和 UBI 布局的镜像也不能混刷（见[启动与分区布局](#启动与分区布局)）。

## 目录

[快速开始](#快速开始) · [版本说明](#版本说明) · [硬件概览](#硬件概览) · [出厂默认设置](#出厂默认设置) ·
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

## 版本说明

每个 [Release](https://github.com/netrivo/xg2010g-immortalwrt-for-gemtek-brightspeed/releases) 对应一个同名 tag，
版本号格式为 `v<主版本>.<次版本>.<修订号>`，可以再带一个后缀。

### 版本号的含义

| 部分 | 什么时候增加 | 例子 |
| --- | --- | --- |
| 主版本 | 不兼容的变化：分区布局或启动方式改变、不能保留配置直接升级、需要手动操作才能升级 | `v1.4.2` → `v2.0.0` |
| 次版本 | 新功能，同步 brightspeed / ImmortalWrt 上游（含内核小版本），默认或可选插件的增减 | `v1.4.2` → `v1.5.0` |
| 修订号 | 只修复问题，不增加功能 | `v1.4.2` → `v1.4.3` |

### 后缀：正式版和预发布版

| 版本 | 类型 | Releases 页面显示 | 适合谁 |
| --- | --- | --- | --- |
| `v1.0.0` | 正式版 | **Latest** | 日常使用 |
| `v1.0.0-rc.1`、`v1.0.0-rc.2` | 发布候选版（Release Candidate）：功能已完成，正式发布前先试用 | Pre-release | 愿意帮忙测试的用户 |
| `v1.0.0-beta.1` | 测试版：功能可能还不完整 | Pre-release | 开发和测试 |

一个版本通常按 `-beta.N` → `-rc.N` → 正式版的顺序发布，后缀里的数字表示第几个测试版或候选版。
候选版确认没问题后，会在同一个提交上发布正式版。

> [!NOTE]
> Actions 手动构建出来的固件，版本号是 `<YYYYMMDD>-<commit>`（例如 `20261123-9f73da37`），只用于开发测试，
> 不是发布版本，也不会出现在 Releases 页面。

### 查看设备上的版本

- LuCI 状态页和页脚会显示固件版本。
- SSH 里执行 `cat /etc/openwrt_release`：`DISTRIB_RELEASE` 是版本号（如 `v1.0.0`）。
- `cat /etc/openwrt_version` 是完整的 build ID：`<YYYYMMDD>-<本仓库 commit>-<brightspeed commit>`，
  用来精确定位这份固件是从哪个代码构建的，报告问题时请附上。

### 每个版本改了什么

- Releases 页面每个版本的正文：发布说明、固件 SHA256，以及 GitHub 自动生成的“自上个版本以来的变更”。
- [CHANGELOG.md](CHANGELOG.md)：按日期记录的重要功能、修复和维护变更。

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
编译；`helloworld`、`pushbot` 两个 feed 和本仓库自带的 `lucky` 会发布到每次构建对应的 extras 仓库，
其余包从官方 ImmortalWrt distfeeds 安装。镜像安装器只安装 `=y` 包，所以 `=m` 不会增加
默认镜像体积。

### 默认自带的插件

| 插件 | 用途 |
| --- | --- |
| `luci-app-onu` | PON/ONU 设置 |
| `luci-app-pon-status` | PON 光链路状态 |
| `luci-app-clients` | 已连接的客户端 |
| `luci-app-airoha-npu` | NPU / PPE 硬件加速状态 |
| `luci-app-firewall` | 防火墙（默认已开启软件和硬件流量卸载、FullCone NAT） |
| `luci-app-package-manager` | 软件包管理，用来安装下面的可选插件 |
| `luci-app-ttyd` | 网页终端 |
| `luci-theme-argon` / `luci-theme-bootstrap` | 默认主题 / 备用主题 |

另外内置了语音（`asterisk`）、PON 守护进程（`airoha-ponctl`、`airoha-pond`）和常用诊断工具
（`iperf3`、`tcpdump`、`curl`）。镜像内的完整包清单以对应构建的 `*.manifest` 为准。

### 可选插件（不在镜像里，按需安装）

| 插件 | 用途 | 安装来源 |
| --- | --- | --- |
| `luci-app-openclash` | Clash 代理 | 官方源 |
| `luci-app-passwall` | 代理 | 官方源 |
| `luci-app-ssr-plus` | 代理 | extras（helloworld） |
| `luci-app-pbr` | 策略路由 | 官方源 |
| `luci-app-zerotier` | ZeroTier 虚拟组网 | 官方源 |
| `luci-app-lucky` | Lucky（端口转发、DDNS 等） | extras（本仓库） |
| `luci-app-ddns` / `luci-app-ddns-go` | 动态域名 | 官方源 |
| `luci-app-upnp` | UPnP 端口映射 | 官方源 |
| `luci-app-udpxy` / `luci-app-msd_lite` / `luci-app-rtp2httpd` | IPTV 组播转 HTTP | 官方源 |
| `luci-app-wol` / `luci-app-timewol` | 网络唤醒 / 定时唤醒 | 官方源 |
| `luci-app-arpbind` | IP/MAC 绑定 | 官方源 |
| `luci-app-autoreboot` | 定时重启 | 官方源 |
| `luci-app-watchcat` | 网络检测与自动恢复 | 官方源 |
| `luci-app-vlmcsd` | KMS 服务器 | 官方源 |
| `luci-app-pushbot` | 消息推送 | extras（pushbot） |

在 LuCI → 系统 → 软件包中搜索安装，或在 SSH 里执行 `apk update && apk add <插件名>`。
中文翻译包（`luci-i18n-<插件>-zh-cn`）通常会随插件自动安装。

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

目前**不支持自动在线升级**（设备不会自己检查和下载新版本）。升级方式是从 Releases 下载新的
`.itb`，在 LuCI → 系统 → 备份/升级中刷写，或上传到设备后执行 `sysupgrade -v <文件>`，
保留配置即可。升级后插件会自动恢复，过程如下。

XG2010G 的 `sysupgrade` 默认会把当前已安装包列表写入备份里的
`/etc/backup/installed_packages.txt`，把升级前被禁用的服务写入
`/etc/backup/disabled_services.txt`。升级重启后，新镜像里的
`xg2010g-restore-packages` 服务会在后台：

1. 只处理旧镜像中位于 overlay 的包（用户自己安装的插件）；旧镜像 ROM 里预装的包不会
   被带进最小镜像。
2. 跳过新镜像里已经存在的包，执行 `apk update` 和 `apk add`。
3. 软件源连不上（PON 注册、PPPoE 拨号还没完成，或上游断网）时不放弃，也不用等重启：
   前 5 分钟每 10 秒重试，之后每 5 分钟重试，直到连通。
4. 每装完一轮，把升级前被禁用、但被安装脚本重新启用的服务再停止并禁用，保持升级前的启停状态。
5. 源可用但个别包仍安装失败（例如包已下架）时，每 5 分钟再试，最多 6 轮；仍失败就保留列表，
   下次启动再试。全部成功后删除两个列表。日志在 `/tmp/xg2010g-restore.log`，也可以用
   `logread -e xg2010g-restore` 查看。

`/etc/config/` 和常见插件的配置目录通过
[`package/base-files/files/lib/upgrade/keep.d/xg2010g-configs`](package/base-files/files/lib/upgrade/keep.d/xg2010g-configs)
跨升级保留。这里只放配置，不要加入插件二进制或大型规则集，因为 sysupgrade 在刷写前用 `/tmp`（内存）生成备份。

extras 仓库发布在本仓库的 `packages` 分支，按 build ID 分目录。最近 3 次构建和所有
Release 构建会一直保留，更早的未发布构建会被清理：

```text
https://raw.githubusercontent.com/<owner>/<repo>/packages/<build-id>/<feed>/packages.adb
```

每个 build ID 目录下有 `helloworld/`、`pushbot/`、`kmods/`（本次内核对应的全部 `kmod-*`）
和 `local/`（本仓库 `package/` 下的可选包，目前是 lucky）。
镜像里的 `/etc/apk/repositories.d/xg2010g.list` 由 `scripts/set-extras-repo.sh` 在构建时生成，
指向同一 build ID。索引和模块使用该次构建的 APK 签名密钥，镜像内置对应公钥。CI 构建会
自动发布；本地构建如果不发布 extras，恢复服务会记录失败并保留列表，不影响系统启动。
设备上执行 `apk update` 后即可用 `apk add <包名>` 安装，LuCI 软件包页面也会显示这些源。

> [!NOTE]
> - 第一次从作者完整镜像刷到本仓库的最小镜像属于重装，旧镜像的 `sysupgrade` 不会生成包列表，
>   需要在刷机后手动安装一次插件；之后再用本仓库固件升级时会自动恢复。
> - 不要从旧固件的源安装 `kmod-*`，内核模块必须和当前内核完全匹配。
> - 只有直接使用 Actions 构件（未发布的构建）的设备，才会在之后 3 次新构建后失去对应的 extras；
>   正式 Release 的 extras 会一直保留。

## 构建

### GitHub Actions（推荐）

工作流 [Build XG2010G Firmware](.github/workflows/build-firmware.yml) 有两种触发方式：

| 触发方式 | 结果 |
| --- | --- |
| 推送 `v*` tag | 构建并发布**同名** GitHub Release。`v1.2.3` 为正式版，`v1.2.3-rc.1` 这类带后缀的为预发布版 |
| 手动运行（Actions → Build XG2010G Firmware → Run workflow） | 测试构建，只上传 Actions 构件，不发布 Release |

推送普通提交不会编译。没有缓存时完整构建约 3.5 小时；
CI 会缓存源码包（`dl/`）和 ccache 编译缓存（上限 3 GB，构建失败时也会保存），之后的构建会复用。
ccache 只在 CI 中开启，不改动 `2010.config`。

每次推送和 PR 会自动运行 [Check](.github/workflows/check.yml)（约 1 分钟）：脚本语法、XG2010G-only 裁剪、
distfeeds、PON 链路看门狗和升级插件恢复的测试。

发布一个版本：

```bash
git switch main && git pull
git tag -a v1.0.0 -m "本版本的更新说明"   # 附注 tag 的说明就是 Release 正文
git push origin v1.0.0
```

tag 必须是 `v<主>.<次>.<修订>` 或再加 `-<后缀>`（含义见[版本说明](#版本说明)），并且指向 `main` 上的提交，
否则构建开始几秒内就会失败。
Release 正文由 tag 说明、固件 SHA256 和 GitHub 自动生成的“自上个 tag 以来的变更”组成。

一次构建会：

1. 生成 build ID：`<YYYYMMDD>-<本仓库 commit 8 位>-<brightspeed commit 8 位>`（日期按 Asia/Shanghai）。
2. 更新并安装 feeds，选择 feed provider，应用 `patches/feeds/` 补丁。
3. 生成 extras 源地址，应用包策略，写入版本信息，执行配置检查（distfeeds、profile 隔离、XG2010G-only）。
4. 下载源码并编译 `world`；失败时自动用 `V=s` 重编第一个失败的包并输出错误摘要。
5. 检查镜像和 manifest，发布 extras 到 `packages` 分支。
6. 上传构件（固件、manifest、buildinfo、日志，保留 30 天）。tag 构建还会发布同名 Release，
   **只上传一个 `.itb` 固件**，并把它的 SHA256 写进 Release 说明；镜像数量不是恰好一个时发布会失败。
   tag 构建的 extras 会永久保留。

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
| `immortalwrt-naoki66-<版本>-airoha-an7581-gemtek_xg2010g-ubi-squashfs-sysupgrade.itb` | sysupgrade 固件；`<版本>` 在 tag 构建中是 tag 名（如 `v1.0.0`），手动构建中是 `<YYYYMMDD>-<commit>` |
| `*.manifest` | 镜像内的包清单 |
| `config.buildinfo` / `feeds.buildinfo` / `version.buildinfo` | 构建配置、feed 版本和版本信息 |
| `sha256sums` | 校验和 |

GitHub Release 只发布上表第一行的 `.itb`，其余文件只在 Actions 构件里。

文件名只包含版本；版本号写入设备的 `/etc/openwrt_release`（`DISTRIB_RELEASE`），完整的 build ID
（含 brightspeed commit）写入 `CONFIG_VERSION_CODE`，在设备的 `/etc/openwrt_version` 中查看。

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

`.brightspeed-upstream` 的 `source` 直接指向 naoki66 仓库，和监控的来源一致。同步：

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
| `scripts/check-restore-packages.sh` | 构建主机 | 升级后插件恢复脚本的测试（断网重试、禁用服务保持、失败保留列表），`apk` 等命令均为模拟 |
| `scripts/check-distfeeds.sh` | 构建主机 | 检查运行时 distfeeds 只包含官方发布的 feed |
| `scripts/check-gemtek-profile-isolation.sh` | 构建主机 | 检查 `.config`、内核配置和 manifest 没有混入其他机型的包 |
| `scripts/check-firmware-artifacts.sh` | 构建主机 | 检查所选 profile 的 sysupgrade 镜像确实生成 |
| `scripts/check-xg2010g-network.sh` | 设备 | 刷机后验证 LAN、fw4 和 DHCP |

常用的提交前检查：

```bash
bash scripts/check-xg2010g-only.sh
bash scripts/check-pon-link-watchdog.sh
bash scripts/check-restore-packages.sh
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
| `.github/workflows/check.yml` | 推送和 PR 时的快速检查 |

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
