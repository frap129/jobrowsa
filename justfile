# Build the browser binary inside a Debian container
build:
    ./scripts/docker-build.sh

# Package an Arch Linux .pkg.tar.zst under build/release/
arch:
    ./package/docker-package-arch.sh

# Package tar.xz and AppImage artifacts under build/
appimage:
    ./package/docker-package.sh

# Package a .deb in addition to tar.xz and AppImage
deb:
    MAKE_DEB=1 ./package/docker-package.sh

# Remove the build directory
clean:
    rm -rf build