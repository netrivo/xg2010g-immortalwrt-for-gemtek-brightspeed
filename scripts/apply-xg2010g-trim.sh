#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "$0")/.."

# 1. 上游可能重新加入这些路径，强制删除
rm -rf package/boot/uboot-airoha target/linux/airoha/an7583/base-files
rm -f package/boot/uboot-tools/uboot-envtools/files/airoha_an7583
rm -f 1710.config 040.config 040-tf.config config.seed
rm -f .github/workflows/sync-upstream.yml

# 2. an7581.mk 只保留 XG2010G 的 Device 定义和 TARGET_DEVICES
python3 - <<'PY'
from pathlib import Path
import re

p = Path("target/linux/airoha/image/an7581.mk")
lines = p.read_text().splitlines(keepends=True)
keep = {
    "Device/gemtek_xg2010g-common",
    "Device/gemtek_xg2010g-ubi-common",
    "Device/gemtek_xg2010g",
    "Device/gemtek_xg2010g-ubi",
}
keep_targets = {"gemtek_xg2010g", "gemtek_xg2010g-ubi"}
unknown = set()
out = []
i = 0
while i < len(lines):
    line = lines[i]
    match = re.match(r"^define (Device/\S+)", line)
    if match:
        if "xg2010g" in match.group(1) and match.group(1) not in keep:
            unknown.add(match.group(1))
        block = [line]
        i += 1
        while i < len(lines) and lines[i].strip() != "endef":
            block.append(lines[i])
            i += 1
        if i < len(lines):
            block.append(lines[i])
            i += 1
        if match.group(1) in keep:
            out.extend(block)
        continue
    if line.startswith("TARGET_DEVICES += "):
        target = line.split()[-1]
        if target in keep_targets:
            out.append(line)
        elif "xg2010g" in target:
            unknown.add(target)
        i += 1
        continue
    out.append(line)
    i += 1
if unknown:
    raise SystemExit(
        "unknown XG2010G device definitions, update the trim allow-list: "
        + ", ".join(sorted(unknown))
    )
p.write_text("".join(out))
PY

# 3. an7583 / en7523 子目标不构建设备
printf '%s\n' '# XG2010G-only 仓库保留 an7583 子目标结构，但不构建任何 an7583 设备。' \
	> target/linux/airoha/image/an7583.mk
printf '%s\n' '# XG2010G-only 仓库保留 en7523 子目标结构，但不构建任何 en7523 设备。' \
	> target/linux/airoha/image/en7523.mk

# 4. DTS 只保留共享 an7581.dtsi 和 XG2010G 设备树
find target/linux/airoha/dts -maxdepth 1 -type f \
	! -name 'an7581.dtsi' ! -name '*xg2010g*' -delete

# 5. 移除上游重新加入的 feeds 和配置项
if [ -f feeds.conf.default ]; then
	sed -i.bak -E '/^src-git .*(easytier|ac_agent)/d' feeds.conf.default
	rm -f feeds.conf.default.bak
fi
if [ -f 2010.config ]; then
	sed -i.bak '/^CONFIG_FEED_ac_agent=y$/d' 2010.config
	rm -f 2010.config.bak
fi

# 6. 默认镜像只保留 XG2010G/PON/系统必需包，可选第三方包由本地策略排除
if [ -f 2010.config ]; then
	bash scripts/apply-xg2010g-package-policy.sh 2010.config
fi

bash scripts/check-xg2010g-only.sh
