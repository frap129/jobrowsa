#!/usr/bin/env bash
set -euo pipefail

_current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
_root_dir="$(cd "${_current_dir}/.." && pwd)"
_image="helium-arch-packager:latest"

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
_image_args=()
if [ "$_user_uidgid" != "0:0" ]; then
    _image_args+=(--build-arg "UID=$(id -u)")
    _image_args+=(--build-arg "GID=$(id -g)")
fi

_version=$(python3 "$_root_dir/helium-chromium/utils/helium_version.py" \
    --tree "$_root_dir/helium-chromium" \
    --platform-tree "$_root_dir" \
    --print)
_target_cpu=$(grep '^target_cpu' "$_root_dir/build/src/out/Default/args.gn" |
    tail -1 |
    cut -d'"' -f2)

case "$_target_cpu" in
    x64) _arch="x86_64" ;;
    arm64) _arch="aarch64" ;;
    *)
        echo "unsupported target CPU for Arch packaging: $_target_cpu" >&2
        exit 1
        ;;
esac

if [ "$_arch" != "$(uname -m)" ]; then
    echo "cannot package $_arch binaries on $(uname -m) with a native Arch container" >&2
    exit 1
fi

_build_output="$_root_dir/build/src/out/Default"
if [ ! -x "$_build_output/helium" ]; then
    echo "Helium build output not found: $_build_output/helium" >&2
    exit 1
fi

_release_dir="$_root_dir/build/release"
_package_dir="$_root_dir/build/arch-package"
rm -rf "$_package_dir"
mkdir -p "$_package_dir" "$_release_dir"
trap 'rm -rf "$_package_dir"' EXIT
cp "$_current_dir/PKGBUILD" "$_package_dir/"

echo "building ${_runtime} image '${_image}'"
"$_runtime" buildx build --load \
    -t "$_image" \
    -f "$_root_dir/docker/arch-package.Dockerfile" \
    "${_image_args[@]}" "$_root_dir/docker"

"$_runtime" run --rm -i \
    -u "$_user_uidgid" \
    "${_userns_args[@]}" \
    -e "HELIUM_VERSION=$_version" \
    -e HELIUM_BUILD_OUTPUT=/repo/build/src/out/Default \
    -e HELIUM_PACKAGE_FILES=/repo/package \
    -v "$_root_dir:/repo" \
    -w /repo/build/arch-package \
    "$_image" makepkg --clean --cleanbuild --force --nodeps

mv "$_package_dir"/*.pkg.tar.zst "$_release_dir/"
