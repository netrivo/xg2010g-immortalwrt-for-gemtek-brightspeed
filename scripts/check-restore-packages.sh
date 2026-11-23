#!/usr/bin/env bash
# Host-side tests for package/base-files/files/usr/sbin/xg2010g-restore-packages.
# The helper runs under a POSIX shell (dash by default, close to busybox ash)
# inside a temporary root; apk, logger and sleep are mocked, so no router is
# needed and no test sleeps for real.
set -Eeuo pipefail

cd "$(dirname "$0")/.."

helper=package/base-files/files/usr/sbin/xg2010g-restore-packages
test_sh=${TEST_SH:-$(command -v dash || command -v sh)}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
root=$work/root
bin=$work/bin
mkdir -p "$bin"

# Point every absolute path the helper uses into the temporary root.
sed -e "s#=/etc/backup#=$root/etc/backup#g" \
	-e "s#=/tmp/xg2010g#=$root/tmp/xg2010g#g" \
	-e "s#=/var/lock#=$root/var/lock#g" \
	-e "s#\"/lib/apk/packages#\"$root/lib/apk/packages#g" \
	-e "s#\"/etc/init.d#\"$root/etc/init.d#g" \
	"$helper" >"$work/restore.sh"
if grep -nE '"?/(etc|lib|var|tmp)/' "$work/restore.sh" | grep -v "$root" | grep -vE '^[0-9]+:#'; then
	echo "FAIL: helper uses an absolute path the test does not redirect" >&2
	exit 1
fi

# apk mock: `apk update` fails the first $UPD_FAIL times; `apk add <pkg>`
# fails for packages listed in $BAD, otherwise installs the package and an
# enabled init script named after it (like a post-install script would).
cat >"$bin/apk" <<EOF
#!/bin/sh
root=$root
if [ "\$1" = update ]; then
	n=\$(cat "\$root/update-count" 2>/dev/null || echo 0)
	n=\$((n + 1))
	echo "\$n" >"\$root/update-count"
	[ "\$n" -gt "\${UPD_FAIL:-0}" ]
	exit \$?
fi
pkg=\$3
case " \${BAD:-} " in *" \$pkg "*) exit 1 ;; esac
touch "\$root/lib/apk/packages/\$pkg.list"
cat >"\$root/etc/init.d/\$pkg" <<SVC
#!/bin/sh
case "\\\$1" in
enabled) [ -f "\$root/enabled.\$pkg" ] ;;
disable) rm -f "\$root/enabled.\$pkg" ;;
stop) echo "\$pkg" >>"\$root/stopped" ;;
esac
SVC
chmod +x "\$root/etc/init.d/\$pkg"
touch "\$root/enabled.\$pkg"
EOF
printf '#!/bin/sh\necho "$1" >>"%s/sleeps"\n' "$root" >"$bin/sleep"
printf '#!/bin/sh\nexit 0\n' >"$bin/logger"
chmod +x "$bin"/*

setup() {
	rm -rf "$root"
	mkdir -p "$root/etc/backup" "$root/lib/apk/packages" "$root/etc/init.d" "$root/tmp"
	printf 'base-files\trom\nluci-app-lucky\toverlay\nzerotier\toverlay\nmosdns\tunknown\nkmod-tun\trom\n' \
		>"$root/etc/backup/installed_packages.txt"
	printf 'zerotier\nfirewall\n\n' >"$root/etc/backup/disabled_services.txt"
}

run() { PATH="$bin:$PATH" "$test_sh" "$work/restore.sh"; }
count() { grep -cx "$1" "$root/sleeps" 2>/dev/null || true; }
fail() { echo "FAIL: $*" >&2; sed 's/^/  log: /' "$root/tmp/xg2010g-restore.log" >&2 2>/dev/null || true; exit 1; }
pass() { echo "PASS: $*"; }

# 1. Feeds unreachable for 35 attempts: fast retries, then slow retries, then
#    everything is restored without a reboot and the disabled service stays off.
setup
UPD_FAIL=35 run || fail "restore did not succeed after the network came back"
[[ $(count 10) == 29 && $(count 300) == 6 ]] || fail "unexpected retry delays: $(sort "$root/sleeps" | uniq -c | tr '\n' ' ')"
for pkg in luci-app-lucky zerotier mosdns; do
	[[ -f $root/lib/apk/packages/$pkg.list ]] || fail "$pkg was not restored"
done
[[ ! -e $root/lib/apk/packages/base-files.list && ! -e $root/lib/apk/packages/kmod-tun.list ]] \
	|| fail "rom packages must not be reinstalled"
[[ ! -e $root/enabled.zerotier ]] || fail "zerotier was disabled before the upgrade but is enabled"
grep -qx zerotier "$root/stopped" || fail "zerotier was not stopped"
[[ -e $root/enabled.luci-app-lucky && -e $root/enabled.mosdns ]] || fail "enabled services were disabled"
[[ -z $(ls "$root/etc/backup") ]] || fail "lists were not removed after success"
[[ ! -e $root/var/lock/xg2010g-restore.lock ]] || fail "lock was not released"
pass "keeps retrying without network, restores overlay packages, keeps disabled services off"

# 2. A package that never installs: bounded retries, list kept for next boot.
setup
if BAD=mosdns run; then fail "restore reported success although mosdns failed"; fi
[[ $(count 300) == 5 ]] || fail "expected 5 slow retries between 6 install rounds"
[[ -s $root/etc/backup/installed_packages.txt && -s $root/etc/backup/disabled_services.txt ]] \
	|| fail "lists must be kept for the next boot"
[[ ! -e $root/enabled.zerotier ]] || fail "disabled service re-enabled after a partial restore"
pass "gives up after bounded rounds and keeps the lists"

# 3. Nothing to restore.
setup
touch "$root/lib/apk/packages/"{luci-app-lucky,zerotier,mosdns}.list
run || fail "no-op restore failed"
[[ -z $(ls "$root/etc/backup") && ! -e $root/update-count ]] || fail "no-op restore touched the feeds or kept lists"
pass "no-op when every package is already present"

# 4. A second instance exits while the first holds the lock.
setup
mkdir -p "$root/var/lock/xg2010g-restore.lock"
run 2>/dev/null || fail "second instance returned an error"
[[ ! -e $root/update-count ]] || fail "second instance ran apk"
pass "second instance exits while the lock is held"

echo "check-restore-packages: ok"
