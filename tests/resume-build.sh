#!/usr/bin/env bash
set -euo pipefail

_root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
_tmp_dir="$(mktemp -d)"
trap 'rm -rf "$_tmp_dir"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_arg() {
    local _expected="$1"
    local _actual
    for _actual in "${_args[@]}"; do
        [ "$_actual" = "$_expected" ] && return 0
    done
    fail "missing argument: $_expected"
}

assert_arg_pair() {
    local _first="$1"
    local _second="$2"
    local _index
    for ((_index = 0; _index + 1 < ${#_args[@]}; _index++)); do
        if [ "${_args[$_index]}" = "$_first" ] &&
            [ "${_args[$((_index + 1))]}" = "$_second" ]; then
            return 0
        fi
    done
    fail "missing argument pair: $_first $_second"
}

_fixture="$_tmp_dir/repo"
mkdir -p "$_fixture/scripts" "$_fixture/build/src/out/Default" "$_tmp_dir/podman-bin"
cp "$_root_dir/scripts/resume-build.sh" "$_fixture/scripts/resume-build.sh"
touch "$_fixture/build/src/out/Default/build.ninja"

cat >"$_tmp_dir/podman-bin/podman" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = image ] && [ "${2:-}" = inspect ]; then
    exit "${FAKE_IMAGE_STATUS:-0}"
fi
printf '%s\0' "$@" >"$FAKE_ARGS_FILE"
exit "${FAKE_RUN_STATUS:-0}"
EOF
chmod +x "$_tmp_dir/podman-bin/podman"

_args_file="$_tmp_dir/podman-args"
PATH="$_tmp_dir/podman-bin:$PATH" \
    FAKE_ARGS_FILE="$_args_file" \
    ARCH=arm64 \
    SCCACHE_DIR=/repo/.sccache \
    SISO_REAPI_ADDRESS=127.0.0.1:5000 \
    SISO_REAPI_INSTANCE=main \
    "$_fixture/scripts/resume-build.sh"
mapfile -d '' -t _args <"$_args_file"

assert_arg --userns=keep-id
assert_arg_pair -u "$(id -u):$(id -g)"
assert_arg_pair -v "$_fixture:/repo"
assert_arg_pair -e ARCH
assert_arg_pair -e SCCACHE_DIR
assert_arg_pair -e SISO_REAPI_ADDRESS
assert_arg_pair -e SISO_REAPI_INSTANCE
assert_arg chromium-builder:trixie-slim
assert_arg '. /repo/scripts/shared.sh; setup_environment; build'

set +e
PATH="$_tmp_dir/podman-bin:$PATH" \
    FAKE_ARGS_FILE="$_args_file" \
    FAKE_RUN_STATUS=23 \
    "$_fixture/scripts/resume-build.sh" >/dev/null 2>&1
_status=$?
set -e
[ "$_status" -eq 23 ] || fail "expected container status 23, got $_status"

set +e
PATH="$_tmp_dir/podman-bin:$PATH" \
    FAKE_ARGS_FILE="$_args_file" \
    FAKE_IMAGE_STATUS=1 \
    "$_fixture/scripts/resume-build.sh" >"$_tmp_dir/image.out" 2>"$_tmp_dir/image.err"
_status=$?
set -e
[ "$_status" -ne 0 ] || fail "missing image unexpectedly succeeded"
case "$(<"$_tmp_dir/image.err")" in
    *"just clean && just build"*) ;;
    *) fail "missing-image recovery guidance not found" ;;
esac

rm "$_fixture/build/src/out/Default/build.ninja"
set +e
PATH="$_tmp_dir/podman-bin:$PATH" \
    FAKE_ARGS_FILE="$_args_file" \
    "$_fixture/scripts/resume-build.sh" >"$_tmp_dir/state.out" 2>"$_tmp_dir/state.err"
_status=$?
set -e
[ "$_status" -ne 0 ] || fail "missing build.ninja unexpectedly succeeded"

_docker_bin="$_tmp_dir/docker-bin"
mkdir -p "$_docker_bin"
for _command in bash dirname env id; do
    ln -s "$(command -v "$_command")" "$_docker_bin/$_command"
done
cp "$_tmp_dir/podman-bin/podman" "$_docker_bin/docker"
touch "$_fixture/build/src/out/Default/build.ninja"
PATH="$_docker_bin" FAKE_ARGS_FILE="$_args_file" "$_fixture/scripts/resume-build.sh"
mapfile -d '' -t _args <"$_args_file"
assert_arg_pair -u "$(id -u):$(id -g)"
assert_arg_pair -v "$_fixture:/repo"
for _arg in "${_args[@]}"; do
    case "$_arg" in
        --userns*) fail "Docker received Podman-only --userns" ;;
    esac
done

echo "resume-build tests passed"
