#!/usr/bin/env bash
set -euo pipefail

_root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
_tmp_dir="$(mktemp -d)"
trap 'rm -rf "$_tmp_dir"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

cp "$_root_dir/justfile" "$_tmp_dir/justfile"
mkdir -p "$_tmp_dir/scripts"

cat >"$_tmp_dir/scripts/docker-build.sh" <<'EOF'
#!/usr/bin/env bash
printf 'full:%s\n' "${SCCACHE_DIR:-}" >"$MARKER"
EOF

cat >"$_tmp_dir/scripts/resume-build.sh" <<'EOF'
#!/usr/bin/env bash
printf 'resume:%s\n' "${SCCACHE_DIR:-}" >"$MARKER"
EOF

chmod +x "$_tmp_dir/scripts/docker-build.sh" "$_tmp_dir/scripts/resume-build.sh"
_marker="$_tmp_dir/marker"

(cd "$_tmp_dir" && MARKER="$_marker" just build >/dev/null)
[ "$(<"$_marker")" = 'full:/repo/.sccache' ] || fail "missing state did not select full build"

mkdir -p "$_tmp_dir/build/src/out/Default"
touch "$_tmp_dir/build/src/out/Default/build.ninja"
(cd "$_tmp_dir" && MARKER="$_marker" just build >/dev/null)
[ "$(<"$_marker")" = 'resume:/repo/.sccache' ] || fail "existing state did not select resume"

echo "just build dispatch tests passed"
