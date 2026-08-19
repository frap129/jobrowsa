# Build the browser binary inside a Debian container
build:
    SCCACHE_DIR=/repo/.sccache ./scripts/docker-build.sh

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