# jobrowsa-linux

Linux builds, packaging, and development tooling for
Jobrowsa, a Chromium-based browser forked from the
helium-chromium project.

## Usage

`just` targets:

- `build` — build the browser binary inside a Debian container.
- `appimage` — package `tar.xz` and AppImage artifacts under `build/`.
- `deb` — package a `.deb` in addition to `tar.xz` and AppImage.
- `arch` — package an Arch Linux `.pkg.tar.zst` under `build/release/`.
- `clean` — remove the `build/` directory.

## Credits

### helium-chromium

This project is a fork of the helium-chromium project,
which provided the original cross-platform build system and patches. The
`helium-chromium/` submodule contains the shared Helium-authored transformation
layer, and its original attribution and licenses remain unchanged.

### ungoogled-chromium

This repo uses some stuff that originally came from
[ungoogled-chromium-portablelinux](https://github.com/ungoogled-software/ungoogled-chromium-portablelinux)
before it was fully remade and forked for the helium-chromium project.

### Vanadium

This repo applies privacy and security hardening patches from
[Vanadium](https://github.com/GrapheneOS/Vanadium), the privacy-hardened
Chromium-based browser by GrapheneOS. The vendored patch set lives in
`patches/vanadium/` and is tracked in `trivalent.manifest`.

### Trivalent

The Vanadium and Trivalent patch sets are synced from
[Trivalent](https://github.com/secureblue/Trivalent), the Chromium-based
browser maintained by the secureblue project. Vendored patches are tracked in
`trivalent.manifest`, with sync tooling in `scripts/sync-trivalent.sh`.

## License

All code, patches, modified portions of imported code or patches, and
any other content that is unique to this project and not imported from other
repositories is licensed under GPL-3.0. See [LICENSE](LICENSE).

Any content imported from other projects retains its original license (for
example, any original unmodified code imported from ungoogled-chromium remains
licensed under their [BSD 3-Clause license](LICENSE.ungoogled_chromium)).
