# ImmortalWrt for Gemtek XG2010G

基于 [ImmortalWrt](https://github.com/immortalwrt/immortalwrt) 的 Gemtek XG2010G 固件仓库。
代码基线来自 `netrivo/ImmortalWrt-for-Gemtek-brightspeed` 的 2026-11-13 快照，
本仓库只维护 XG2010G，其他机型已精简。

## 硬件概览

| 项目 | 信息 |
| --- | --- |
| SoC | Airoha/Econet AN7581 / EN7581 |
| CPU | 4x Cortex-A53，ARM64 |
| 内存 | 1 GiB 或 2 GiB DDR4（U-Boot 传递实际大小） |
| 闪存 | Winbond W25N04K SPI-NAND，512 MiB |
| 10G 网口 x2 | RTL8261N，MDIO 地址 5 / 8 |
| 2.5G 网口 x1 | Airoha EN8811H，MDIO 地址 0xf |
| 1G 网口 x1 | 内置交换机 ePHY（LAN4） |
| PON | EN7572 BOSA，XGPON |
| 无线 / USB / eMMC | 无可用模块或物理接口 |

## 两种启动/分区布局

| profile | 启动链 | 分区 |
| --- | --- | --- |
| `gemtek_xg2010g` | 原厂 bootloader + chainloader U-Boot | `bootloader` / `uenv` / `dsd` / `chainloader@0x600000` / `system` UBI@0x700000 |
| `gemtek_xg2010g-ubi` | OpenWrt U-Boot | `bl2@0` / `ubi@0x20000`（fip、ubootenv、ubootenv2、factory、fit） |

两种布局不能混刷。刷机前备份 `bootloader`、`uenv`、`dsd`、`factory`/`art` 和校准数据，
并确认设备当前使用的 U-Boot 与所选 profile 匹配。

默认构建 `2010.config` 选择 `gemtek_xg2010g-ubi`。

## 默认包策略

默认镜像只保留 XG2010G/PON/系统管理和 Argon 主题；代理、推送、媒体、远程组网等可选包由
`scripts/xg2010g-package-policy.txt` 管理。这些可选包不会安装进镜像，而是以 `=m` 模块方式
编译，`.apk` 发布到每次构建对应的 extras 仓库，之后可以从 LuCI 软件包页面或命令行安装。
镜像安装器只安装 `=y` 包，所以 `=m` 不会增加默认镜像体积。

`2010.config` 和 `feeds.conf.default` 是本地策略文件：同步 brightspeed 时保留本仓库版本，
上游改动会输出 diff 供人工挑选，不会被自动合入。

- 当前 UI 使用 `luci-theme-argon`（jerrykuku 的 argon feed），`luci-theme-bootstrap` 作为备用主题。
- 可选插件的翻译包不会编进镜像或 extras；需要中文界面时从官方 LuCI 源安装对应
  `luci-i18n-*` 包即可。
- PON/ONU 工具（`luci-app-onu`、`luci-app-pon-status`、`luci-app-clients`、`luci-app-airoha-npu`）
  属于设备基础，保留。
- 要让某个可选包进入镜像：从 `scripts/xg2010g-package-policy.txt` 删除对应行，把
  `2010.config` 里的包设为 `y`，然后重新运行策略检查和构建。
- 只安装到设备、不进入镜像的包：保持策略文件中的行不变，构建后从 extras 仓库安装即可。

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
`package/base-files/files/lib/upgrade/keep.d/xg2010g-configs` 跨升级保留。这里只放配置，不要
加入插件二进制或大型规则集，因为 sysupgrade 在刷写前用 `/tmp`（内存）生成备份。

extras 仓库发布在仓库的 `packages` 分支，按 build ID 分目录，只保留最近 3 次构建：

```text
https://raw.githubusercontent.com/<owner>/<repo>/packages/<build-id>/<feed>/packages.adb
```

镜像里的 `/etc/apk/repositories.d/xg2010g.list` 由 `scripts/set-extras-repo.sh` 在构建时生成，
指向同一 build ID。索引和模块使用该次构建的 APK 签名密钥，镜像内置对应公钥。CI 构建会
自动发布；本地构建如果不发布 extras，恢复服务会记录失败并保留列表，不影响系统启动。
设备上执行 `apk update` 后即可用 `apk add <包名>` 安装，LuCI 软件包页面也会显示这些源。

第一次从作者完整镜像刷到本仓库的最小镜像属于重装，旧镜像的 `sysupgrade` 不会生成包列表，
需要在刷机后手动安装一次插件；从这之后的本仓库 OTA 会自动恢复。


## 构建

```bash
sudo apt update
sudo apt install build-essential clang gcc g++ binutils bzip2 gawk gettext git \
  libncurses-dev libssl-dev python3 python3-setuptools rsync unzip wget \
  xsltproc zlib1g-dev file which perl sed make
./scripts/feeds update -a
./scripts/feeds install -a
bash scripts/apply-xg2010g-package-policy.sh 2010.config
cp 2010.config .config
make defconfig
make -j$(nproc) world
```

`world` 会编译 `=m` 的可选包并生成 `bin/packages/`，但不会把它们装进镜像。CI 构建还会把
这些包发布到 `packages` 分支并生成镜像里的 extras 源地址；本地构建如果不需要 extras，
可以跳过发布，镜像仍可正常使用。

产物在 `bin/targets/airoha/an7581/`。

## 同步 brightspeed 更新

`.brightspeed-upstream` 记录上次导入的 brightspeed commit。同步：

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

## 检查

```bash
bash scripts/check-xg2010g-only.sh
bash scripts/check-pon-link-watchdog.sh
```

刷机后可在设备上运行 `scripts/check-xg2010g-network.sh` 验证 LAN/fw4/DHCP。

## 许可证

继承 ImmortalWrt 的 GPL-2.0-only 许可证。
