#!/usr/bin/env bash
set -euo pipefail

_base_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && cd .. && pwd)"
_build_file="${_base_dir}/build/src/out/Default/build.ninja"
_image="chromium-builder:trixie-slim"

if [ ! -f "$_build_file" ]; then
    echo "no resumable compilation found: $_build_file is missing" >&2
    exit 1
fi

if command -v podman >/dev/null 2>&1; then
    _runtime=podman
    _userns_args=(--userns=keep-id)
elif command -v docker >/dev/null 2>&1; then
    _runtime=docker
    _userns_args=()
else
    echo "neither podman nor docker is installed; install rootless Podman or Docker to build" >&2
    exit 1
fi

if ! "$_runtime" image inspect "$_image" >/dev/null 2>&1; then
    echo "builder image '$_image' is missing; run 'just clean && just build' for a fresh build" >&2
    exit 1
fi

_extra_env=()
for _env_name in ARCH SISO_REAPI_ADDRESS SISO_REAPI_INSTANCE; do
    if [ -n "${!_env_name:-}" ]; then
        _extra_env+=(-e "$_env_name")
    fi
done

while IFS='=' read -r _env_name _; do
    case "$_env_name" in
        SCCACHE_*) _extra_env+=(-e "$_env_name") ;;
    esac
done < <(env)

"$_runtime" run --rm -i \
    -u "$(id -u):$(id -g)" \
    "${_userns_args[@]}" \
    -v "${_base_dir}:/repo" \
    "${_extra_env[@]}" \
    "$_image" bash -c '. /repo/scripts/shared.sh; setup_environment; build'
