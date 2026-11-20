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

## 构建

```bash
sudo apt update
sudo apt install build-essential clang gcc g++ binutils bzip2 gawk gettext git \
  libncurses-dev libssl-dev python3 python3-setuptools rsync unzip wget \
  xsltproc zlib1g-dev file which perl sed make
./scripts/feeds update -a
./scripts/feeds install -a
cp 2010.config .config
make defconfig
make -j$(nproc) world
```

产物在 `bin/targets/airoha/an7581/`。

## 同步 brightspeed 更新

`.brightspeed-upstream` 记录上次导入的 brightspeed commit。同步：

```bash
git switch main
git pull
bash scripts/sync-brightspeed.sh
```

脚本用 `git merge-tree --merge-base=<上次快照>` 做三点合并，然后执行
`scripts/apply-xg2010g-trim.sh` 重新应用 XG2010G-only 精简。出现冲突时脚本会停下，
按提示解决后再提交。

## 检查

```bash
bash scripts/check-xg2010g-only.sh
bash scripts/check-pon-link-watchdog.sh
```

刷机后可在设备上运行 `scripts/check-xg2010g-network.sh` 验证 LAN/fw4/DHCP。

## 许可证

继承 ImmortalWrt 的 GPL-2.0-only 许可证。
