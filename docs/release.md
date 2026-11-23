# 发布流程

本文写给维护者，说明如何发布一个 XG2010G 固件版本。版本号的含义见 README 的
[版本说明](../README.md#版本说明)。

## 发布是怎么触发的

发布由 tag 驱动，不需要手动上传任何文件：

1. 推送 `v*` tag。
2. [Build XG2010G Firmware](../.github/workflows/build-firmware.yml) 自动开始构建（没有缓存约 3.5 小时）。
3. 构建成功后：
   - extras 插件源发布到 `packages` 分支的 `<build-id>/` 目录，并永久保留；
   - 创建与 tag **同名**的 GitHub Release，只上传一个 sysupgrade `.itb`，正文包含 tag 说明、固件 SHA256
     和 GitHub 自动生成的变更列表；
   - tag 带 `-` 后缀（如 `-rc.1`）时发布为 Pre-release，否则为正式版（Latest）。

tag 名不符合 `v<主>.<次>.<修订>[-<后缀>]`，或者 tag 不在 `main` 上时，构建会在开始几秒内失败。

## 1. 发布前检查

- [ ] 要发布的改动都已合并到 `main`，`main` 上最新的 [Check](../.github/workflows/check.yml) 通过。
- [ ] 没有未处理的 `upstream-sync` issue；如果有，先决定是同步后再发布，还是先发布。
- [ ] [CHANGELOG.md](../CHANGELOG.md) 已记录这次要发布的改动。
- [ ] 改动较大（同步上游、内核、包策略、升级流程）时，先在 Actions 里手动运行一次测试构建，确认能编译通过。

## 2. 确定版本号

在上一个正式版的基础上：

| 这次发布包含 | 版本号 | 例子（上一版 `v1.4.2`） |
| --- | --- | --- |
| 不兼容的变化（分区布局、启动方式、不能保留配置升级） | 主版本 +1，其余归零 | `v2.0.0` |
| 新功能、上游同步、插件增减 | 次版本 +1，修订号归零 | `v1.5.0` |
| 只有修复 | 修订号 +1 | `v1.4.3` |

一般先发候选版 `-rc.1`；只修了很小问题的修订版可以直接发正式版。

**tag 一旦推送就不要移动或复用。** 发现问题就递增后缀（`-rc.1` → `-rc.2`），不要删掉 `-rc.1` 后再用同名 tag 重新发布：
已经下载过的用户和 extras 目录都会对不上。

## 3. 打 tag 并推送

使用附注 tag，tag 说明会成为 Release 正文的开头：

```bash
git switch main
git pull --ff-only
git tag -a v1.5.0-rc.1 -F - <<'EOF'
v1.5.0 候选版 1

主要变化：
- 同步 brightspeed 到 xxxxxxxx
- 修复 ……

升级注意：
- 可以保留配置直接升级，已安装插件会自动重装。
EOF
git push origin v1.5.0-rc.1
```

说明里建议写这三部分：主要变化、升级注意事项、已知问题。详细的提交列表不用手写，GitHub 会自动附上。

## 4. 等待构建

在 Actions 中查看对应的 Build XG2010G Firmware 运行：

```bash
gh run list -w build-firmware.yml -L 3
gh run watch <run-id>
```

构建完成后确认：

- [ ] Releases 页面出现了同名版本，类型正确（Pre-release / Latest）。
- [ ] 只有一个 `.itb`，文件名里的版本号就是 tag 名。
- [ ] `packages` 分支出现了新的 `<build-id>/` 目录，里面有 `helloworld/`、`pushbot/`、`kmods/`、`local/`。

构建失败时 Release 不会创建。修复后合并到 `main`，**用新的 tag 重新发布**（比如 `-rc.2`）。
失败的那个 tag 没有对应的 Release，可以删除：

```bash
git push origin :refs/tags/v1.5.0-rc.1
git tag -d v1.5.0-rc.1
```

## 5. 真机验收

用一台已经运行本仓库固件的 XG2010G，先装一两个可选插件（例如 `luci-app-lucky`、`luci-app-zerotier`），
再保留配置升级到新版本，然后检查：

- [ ] 能正常启动，LuCI 能登录，`cat /etc/openwrt_release` 中 `DISTRIB_RELEASE` 是新版本号。
- [ ] PON 光链路正常，能拨号或拿到地址，能上网。
- [ ] 局域网正常：在设备上运行 `scripts/check-xg2010g-network.sh`。
- [ ] 升级前装的插件已自动重装，原配置仍在（`logread -e xg2010g-restore`、`/tmp/xg2010g-restore.log`）。
- [ ] `apk update` 成功，能从 extras 源和官方源安装插件。
- [ ] 硬件加速生效：局域网设备测速时 `/sys/kernel/debug/ppe/bind` 的条目在增加。
- [ ] 固定电话能打进打出（如果使用语音）。

有问题就修复后发下一个候选版。

## 6. 发布正式版

候选版验收通过后，在**同一个提交**上打正式版 tag：

```bash
git tag -a v1.5.0 v1.5.0-rc.1^{} -m "v1.5.0

（复制候选版的说明，删去“候选版”字样，补充验收中发现并已修复的问题）"
git push origin v1.5.0
```

正式版会重新构建一次（有缓存时应该比第一次快）。构建内容和候选版来自同一份代码，但固件文件和 SHA256 会不同，
用户应下载正式版 Release 里的文件。

## 7. 发布后

- [ ] 在 CHANGELOG 中注明这次改动属于哪个版本（例如在日期标题后加上 `(v1.5.0)`）。
- [ ] 正式版发布后，可以删除同一版本的旧候选版 Release，避免用户下载到旧文件；tag 保留：
  ```bash
  gh release delete v1.5.0-rc.1 --yes
  ```
  候选版的 extras 目录会一直保留，已经装了候选版的设备仍能安装插件。

## 撤回有问题的正式版

已经发布的正式版发现严重问题时：

1. 在该 Release 的正文开头写明问题和影响范围，并建议用户不要升级；不要删除 tag。
2. 尽快修复，发布修订版（例如 `v1.5.1`），新版本会成为 Latest。
3. 问题会导致设备无法启动时，在 Release 正文写明恢复方法（U-Boot 恢复、刷回上一个版本）。

## 相关文件

| 文件 | 作用 |
| --- | --- |
| `.github/workflows/build-firmware.yml` | 构建、发布 extras、创建 Release |
| `scripts/check-release-tag.sh` | 确认 tag 仍指向构建所用的提交 |
| `scripts/set-build-version.sh` | 把版本号和 build ID 写入固件 |
| `scripts/set-extras-repo.sh` | 生成固件里指向本次 extras 的软件源地址 |
