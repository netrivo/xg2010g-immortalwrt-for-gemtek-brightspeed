#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "$0")/.."

die() { echo "sync-brightspeed: $*" >&2; exit 1; }

[[ -f .brightspeed-upstream ]] || die "missing .brightspeed-upstream"
base=$(sed -n 's/^commit=//p' .brightspeed-upstream)
source_url=$(sed -n 's/^source=//p' .brightspeed-upstream)
[[ -n "$base" && -n "$source_url" ]] || die "invalid .brightspeed-upstream"

[[ -z "$(git status --porcelain)" ]] || die "worktree has uncommitted or untracked changes"

git fetch --no-tags "$source_url" master
git cat-file -e "$base^{commit}" 2>/dev/null || die "base commit $base is missing from the fetched history"
new=$(git rev-parse FETCH_HEAD)
if [[ "$new" == "$base" ]]; then
	echo "already up to date: $new"
	exit 0
fi
old_head=$(git rev-parse HEAD)

echo "merging brightspeed ${base:0:8} -> ${new:0:8}"
out=$(mktemp)
trap 'rm -f "$out"' EXIT
. scripts/xg2010g-unused-paths.sh

# Paths scripts/apply-xg2010g-trim.sh deletes.  Upstream edits to them always
# conflict (modify/delete) and are irrelevant to XG2010G.
is_trimmed_path() {
	local path=$1 unused
	case "$path" in
	1710.config|040.config|040-tf.config|config.seed|\
	.github/workflows/sync-upstream.yml|\
	target/linux/airoha/an7583/base-files/*|\
	package/boot/uboot-airoha/*|\
	package/boot/uboot-tools/uboot-envtools/files/airoha_an7583)
		return 0
		;;
	target/linux/airoha/dts/*)
		case "${path##*/}" in
		an7581.dtsi|*xg2010g*) return 1 ;;
		*) return 0 ;;
		esac
		;;
	esac
	for unused in "${xg2010g_unused_paths[@]}"; do
		[[ "$path" == "$unused" || "$path" == "$unused"/* ]] && return 0
	done
	return 1
}

# Files the trim rewrites, or local policy files restored after the merge.
is_trim_owned_path() {
	case "$1" in
	target/linux/airoha/image/an7581.mk|\
	target/linux/airoha/image/an7583.mk|\
	target/linux/airoha/image/en7523.mk|\
	2010.config|\
	feeds.conf.default)
		return 0
		;;
	esac
	is_trimmed_path "$1"
}

if ! git merge-tree --write-tree --name-only --no-messages --merge-base="$base" HEAD "$new" >"$out"; then
	echo "merge conflicts, checking whether they are trim-only:" >&2
	safe=1
	while IFS= read -r path; do
		is_trim_owned_path "$path" && continue
		echo "  manual conflict: $path" >&2
		safe=0
	done < <(tail -n +2 "$out")
	if (( safe == 0 )); then
		echo "resolve the conflicts above manually, then rerun" >&2
		exit 1
	fi
	echo "all conflicts are inside trimmed device files; retrying with -X ours" >&2
	if ! git merge-tree --write-tree --name-only --no-messages --merge-base="$base" \
		-X ours HEAD "$new" >"$out"; then
		# -X ours settles content conflicts but not modify/delete ones.  Those
		# are acceptable only for paths the trim deletes right after the merge.
		while IFS= read -r path; do
			is_trimmed_path "$path" && continue
			echo "automatic trim resolution failed: $path" >&2
			exit 1
		done < <(tail -n +2 "$out")
		echo "remaining conflicts are in paths the trim deletes" >&2
	fi
fi
tree=$(head -n 1 "$out")

branch="sync/brightspeed-$(date +%Y%m%d-%H%M%S)"
git switch -c "$branch"
git read-tree -u --reset "$tree"

# The package selection and feed list are local policy.  Keep our versions even
# when upstream changed them, and save the upstream delta for manual review so
# an intentional device-related change can still be cherry-picked.
if ! git diff --quiet "$base" "$new" -- 2010.config feeds.conf.default; then
	diff_file="${TMPDIR:-/tmp}/brightspeed-config-$(date +%Y%m%d-%H%M%S).diff"
	git diff "$base" "$new" -- 2010.config feeds.conf.default >"$diff_file" || true
	echo "upstream changed 2010.config/feeds.conf.default; keeping local policy"
	echo "review upstream diff: $diff_file"
fi
git checkout "$old_head" -- 2010.config feeds.conf.default

if ! bash scripts/apply-xg2010g-trim.sh; then
	echo "trim/check failed on $branch" >&2
	echo "fix the tree, rerun scripts/apply-xg2010g-trim.sh, then commit manually" >&2
	exit 1
fi

cat > .brightspeed-upstream <<CONF
commit=$new
date=$(TZ=Asia/Shanghai date +%Y-%m-%d)
source=$source_url
CONF

git add -A
git commit -m "sync: brightspeed $(git rev-parse --short=8 "$new")"
echo "sync committed on $branch; review and push manually"
