#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "$0")/.."

policy=scripts/xg2010g-package-policy.txt
extras=scripts/xg2010g-extras-packages.txt
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
[[ -f "$extras" ]] || { echo "missing $extras" >&2; exit 1; }
[[ -f "$config" ]] || { echo "missing $config" >&2; exit 1; }

python3 - "$policy" "$extras" "$config" "$check" <<'PY'
from pathlib import Path
import re
import sys

policy_path, extras_path, config_path = sys.argv[1], sys.argv[2], sys.argv[3]
check = sys.argv[4] == "1"


def load(path):
    rules = []
    for raw in Path(path).read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.endswith("*"):
            rules.append((line[:-1], True))
        else:
            rules.append((line, False))
    return rules


def matches(rules, name):
    for pattern, prefix in rules:
        if name.startswith(pattern) if prefix else name == pattern:
            return True
    return False


# Packages kept out of the image.  Only the extras subset is compiled (=m);
# the rest is left unset and installed from the official distfeeds.
extra_rules = load(extras_path)
rules = load(policy_path) + extra_rules


def blocked(name):
    return matches(rules, name)


def module(name):
    return matches(extra_rules, name)


def state_line(name):
    if module(name):
        return f"CONFIG_PACKAGE_{name}=m"
    return f"# CONFIG_PACKAGE_{name} is not set"


def keep_off(name):
    # These are boolean sub-options of a LuCI app, not standalone packages.
    # Setting them to =m is invalid (and would pull their selected packages
    # back into the image), so leave them off.
    return "_INCLUDE_" in name or name.endswith("_Transparent_Proxy")


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
            if state == "y" and not keep_off(name):
                installed.append(name)
            out.append(line)
        elif keep_off(name):
            out.append(f"# CONFIG_PACKAGE_{name} is not set")
        else:
            # Extras are compiled as modules so their .apk files land in the
            # per-build extras repository, but are never installed into the
            # default image (the image installer only installs =y).
            out.append(state_line(name))
        continue

    m = re.match(r"^# CONFIG_PACKAGE_(\S+) is not set$", line)
    if m and blocked(m.group(1)):
        name = m.group(1)
        seen.add(name)
        if check or keep_off(name):
            out.append(line)
        else:
            out.append(state_line(name))
        continue

    out.append(line)

if check:
    if installed:
        print(
            "policy-blocked packages are enabled in "
            + config_path
            + ": "
            + ", ".join(sorted(set(installed))),
            file=sys.stderr,
        )
        sys.exit(1)
    sys.exit(0)

# Make the selection explicit even when the symbol is absent, so a Kconfig
# default cannot silently turn it back into an image package.
for pattern, prefix in rules:
    if not prefix and pattern not in seen:
        seen.add(pattern)
        out.append(state_line(pattern))

Path(config_path).write_text("\n".join(out) + "\n")
PY
