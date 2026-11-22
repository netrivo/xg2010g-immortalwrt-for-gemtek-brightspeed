#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "$0")/.."

policy=scripts/xg2010g-package-policy.txt
config=2010.config
check=0

if [[ ${1:-} == --check ]]; then
	check=1
	shift
fi
if (( $# > 0 )); then
	config=$1
fi

[[ -f "$policy" ]] || { echo "missing $policy" >&2; exit 1; }
[[ -f "$config" ]] || { echo "missing $config" >&2; exit 1; }

python3 - "$policy" "$config" "$check" <<'PY'
from pathlib import Path
import re
import sys

policy_path, config_path, check = sys.argv[1], sys.argv[2], sys.argv[3] == "1"

rules = []
for raw in Path(policy_path).read_text().splitlines():
    line = raw.strip()
    if not line or line.startswith("#"):
        continue
    if line.endswith("*"):
        rules.append((line[:-1], True))
    else:
        rules.append((line, False))


def blocked(name):
    for pattern, prefix in rules:
        if name.startswith(pattern) if prefix else name == pattern:
            return True
    return False


lines = Path(config_path).read_text().splitlines()
out = []
selected = []
seen = set()

for line in lines:
    m = re.match(r"^CONFIG_PACKAGE_(\S+)=[ym]$", line)
    if m and blocked(m.group(1)):
        name = m.group(1)
        selected.append(name)
        out.append(f"# CONFIG_PACKAGE_{name} is not set")
        seen.add(name)
        continue
    m = re.match(r"^# CONFIG_PACKAGE_(\S+) is not set$", line)
    if m and blocked(m.group(1)):
        seen.add(m.group(1))
    out.append(line)

if check:
    if selected:
        print(
            "blocked packages are selected in "
            + config_path
            + ": "
            + ", ".join(sorted(set(selected))),
            file=sys.stderr,
        )
        sys.exit(1)
    sys.exit(0)

# Make the exclusion explicit even when the symbol is absent, so a Kconfig
# default cannot silently turn it back on.
for pattern, prefix in rules:
    if not prefix and pattern not in seen:
        out.append(f"# CONFIG_PACKAGE_{pattern} is not set")

Path(config_path).write_text("\n".join(out) + "\n")
PY
