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


def keep_off(name):
    # These are boolean sub-options of a LuCI app, not standalone packages.
    # Setting them to =m is invalid (and would pull their selected packages
    # back into the image), so leave them off.
    return "_INCLUDE_" in name or name.endswith("_Nftables_Transparent_Proxy")


lines = Path(config_path).read_text().splitlines()
out = []
installed = []
seen = set()

for line in lines:
    m = re.match(r"^CONFIG_PACKAGE_(\S+)=([ym])$", line)
    if m and blocked(m.group(1)):
        name, state = m.group(1), m.group(2)
        seen.add(name)
        if check:
            if state == "y":
                installed.append(name)
            out.append(line)
        elif keep_off(name):
            out.append(f"# CONFIG_PACKAGE_{name} is not set")
        else:
            # Optional packages are compiled as modules so their .apk files
            # land in the per-build extras repository, but are never installed
            # into the default image (the image installer only installs =y).
            out.append(f"CONFIG_PACKAGE_{name}=m")
        continue

    m = re.match(r"^# CONFIG_PACKAGE_(\S+) is not set$", line)
    if m and blocked(m.group(1)):
        name = m.group(1)
        seen.add(name)
        if check or keep_off(name):
            out.append(line)
        else:
            out.append(f"CONFIG_PACKAGE_{name}=m")
        continue

    out.append(line)

if check:
    if installed:
        print(
            "blocked packages are installed into the image in "
            + config_path
            + ": "
            + ", ".join(sorted(set(installed))),
            file=sys.stderr,
        )
        sys.exit(1)
    sys.exit(0)

# Make the module selection explicit even when the symbol is absent, so a
# Kconfig default cannot silently turn it back into an image package.
for pattern, prefix in rules:
    if not prefix and pattern not in seen:
        out.append(f"CONFIG_PACKAGE_{pattern}=m")

Path(config_path).write_text("\n".join(out) + "\n")
PY
