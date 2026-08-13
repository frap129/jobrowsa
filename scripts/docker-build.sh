#!/usr/bin/env bash
set -euo pipefail

_base_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && cd .. && pwd)"
_image="chromium-builder:trixie-slim"

# select container runtime: prefer rootless Podman, fall back to Docker
if command -v podman >/dev/null 2>&1; then
    _runtime="podman"
    # keep-id maps the container user to the host user so bind-mount
    # writes keep host ownership; this flag is Podman-only
    _userns_args=(--userns=keep-id)
elif command -v docker >/dev/null 2>&1; then
    _runtime="docker"
    _userns_args=()
else
    echo "neither podman nor docker is installed; install rootless Podman or Docker to build" >&2
    exit 1
fi

# match host user to avoid permission issues on bind mount
_user_uidgid="$(id -u):$(id -g)"
_docker_image_args=()

if [ "$_user_uidgid" != "0:0" ]; then
    _docker_image_args+=(--build-arg "UID=$(id -u)")
    _docker_image_args+=(--build-arg "GID=$(id -g)")
fi

if [ -z "${_use_existing_image:-}" ]; then
    echo "building ${_runtime} image '${_image}'"
    cd "${_base_dir}/docker" &&
        "${_runtime}" buildx build --load \
            -t "${_image}" \
            -f ./build.Dockerfile \
            "${_docker_image_args[@]}" .
else
    echo "using existing ${_runtime} image '${_image}'"
fi

# choose entrypoint: CI or local
_entrypoint="/repo/scripts/build.sh"
if [ -n "${CI:-}" ]; then
    _entrypoint="/repo/.github/scripts/build.sh"
fi

# forward relevant envs when set
_extra_env=()
[ -n "${_prepare_only:-}" ] && _extra_env+=(-e "_prepare_only")
[ -n "${_gha_final:-}" ] && _extra_env+=(-e _gha_final)
[ -n "${_runner_environment:-}" ] && _extra_env+=(-e _runner_environment)
[ -n "${GITHUB_OUTPUT:-}" ] && _extra_env+=(-e GITHUB_OUTPUT)
[ -n "${ARCH:-}" ] && _extra_env+=(-e ARCH)

for sccache_env_name in $(env | grep ^SCCACHE_ | cut -d= -f1); do
    _extra_env+=(-e "$sccache_env_name")
done

for actions_env_name in $(env | grep ^ACTIONS_ | cut -d= -f1); do
    _extra_env+=(-e "$actions_env_name")
done

_build_start=$(date)
echo "${_runtime} build start at ${_build_start}"

_gha_mount=()

if [ -n "${GITHUB_OUTPUT:-}" ]; then
    _gha_mount=(-v "$GITHUB_OUTPUT:$GITHUB_OUTPUT")
fi

cd "${_base_dir}" && "${_runtime}" run --rm -i \
    -u "${_user_uidgid}" \
    "${_userns_args[@]}" \
    -v "${_base_dir}:/repo" \
    "${_gha_mount[@]}" \
    "${_extra_env[@]}" "${_image}" bash "${_entrypoint}" "$@"

_build_end=$(date)
echo -e "${_runtime} build start at ${_build_start}, end at ${_build_end}"
