# Build the container image used to build the browser
image:
    #!/usr/bin/env bash
    set -euo pipefail

    # select container runtime: prefer rootless Podman, fall back to Docker
    if command -v podman >/dev/null 2>&1; then
        runtime="podman"
    elif command -v docker >/dev/null 2>&1; then
        runtime="docker"
    else
        echo "neither podman nor docker is installed; install rootless Podman or Docker to build" >&2
        exit 1
    fi

    # match host user to avoid permission issues on bind mount
    image_args=()
    if [ "$(id -u):$(id -g)" != "0:0" ]; then
        image_args+=(--build-arg "UID=$(id -u)")
        image_args+=(--build-arg "GID=$(id -g)")
    fi

    echo "building ${runtime} image 'chromium-builder:trixie-slim'"
    cd docker
    exec "${runtime}" buildx build --load -t chromium-builder:trixie-slim "${image_args[@]}" -f ./build.Dockerfile .

# Build the browser binary inside a Debian container
build:
    podman image exists chromium-builder:trixie-slim 2>/dev/null || { command -v docker >/dev/null 2>&1 && docker image inspect chromium-builder:trixie-slim >/dev/null 2>&1; } || just image
    if [ -f build/src/out/Default/build.ninja ]; then SCCACHE_DIR=/repo/.sccache ./scripts/resume-build.sh; else SCCACHE_DIR=/repo/.sccache _use_existing_image=1 ./scripts/docker-build.sh; fi

# Package an Arch Linux .pkg.tar.zst under build/release/
arch:
    ./package/docker-package-arch.sh

# Package the release tarball and symbols under build/release/
tarball:
    ./package/docker-package.sh tarball

# Package an AppImage from the release tarball
appimage:
    ./package/docker-package.sh appimage

# Package a .deb from the release tarball
deb:
    ./package/docker-package.sh deb

# Package all release artifacts (tarball, AppImage, .deb)
package:
    ./package/docker-package.sh all

# Remove the build directory
clean:
    rm -rf build