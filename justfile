build:
    ./scripts/docker-build.sh

arch:
    ./package/docker-package-arch.sh

appimage:
    ./package/docker-package.sh

deb:
    MAKE_DEB=1 ./package/docker-package.sh

clean:
    rm -rf build
