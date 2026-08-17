#!/usr/bin/env bash
set -euo pipefail

_current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
_root_dir="$(cd "${_current_dir}/.." && pwd)"
_git_submodule="helium-chromium"

_image="jobrowsa-trixie-slim:packager"

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
	echo "neither podman nor docker is installed; install rootless Podman or Docker to package" >&2
	exit 1
fi

_user_uidgid="$(id -u):$(id -g)"
_docker_image_args=()
_make_deb=${MAKE_DEB:-0}

if [ "$_user_uidgid" != "0:0" ]; then
	_docker_image_args+=(--build-arg "UID=$(id -u)")
	_docker_image_args+=(--build-arg "GID=$(id -g)")
fi

echo "building ${_runtime} image '${_image}'"
cd "${_root_dir}/docker" &&
	"${_runtime}" buildx build --load \
		-t "${_image}" \
		-f ./package.Dockerfile \
		"${_docker_image_args[@]}" .

[ -n "$(ls -A "${_root_dir}/${_git_submodule}" 2>/dev/null || true)" ] || git -C "${_root_dir}" submodule update --init --recursive

_gpg_docker_flags=()
if [[ -n "${GPG_PRIVATE_KEY:-}" && -n "${GPG_PASSPHRASE:-}" ]]; then
	_gpg_docker_flags=(-e GPG_PRIVATE_KEY -e GPG_PASSPHRASE -e SIGN_TARBALL=1)
fi

cd "${_root_dir}" && "${_runtime}" run --rm -i \
	-u "${_user_uidgid}" \
	"${_userns_args[@]}" \
	"${_gpg_docker_flags[@]}" \
	-e APPIMAGE_EXTRACT_AND_RUN=1 \
	-e HOME=/home/builder \
	-e GNUPGHOME=/home/builder/.gnupg \
	-e "MAKE_DEB=$_make_deb" \
	-v "${_root_dir}:/repo" \
	"${_image}" bash "/repo/scripts/package.sh" "$@"
