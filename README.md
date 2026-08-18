# Jobrowsa

I'm tired of elements and sciency names. This is my fork, Joe's fork, Joe's bowser, Jobrowsa.

A fork of Helium for Linux with:
- Trivalent's patches, including Vanadium
- Fingerprinting Improvements:
  - Timezone normalized to UTC
  - CPU count hardcoded to 8
  - Device memory clamped to 8GB
  - Max touch points limited to 5
- Extra hardening compiler flags based on recommendations by [OpenSSF](https://best.openssf.org/Compiler-Hardening-Guides/Compiler-Options-Hardening-Guide-for-C-and-C++.html)

## Building Jobrowsa
Dependencies:
- podman or docker
- just

Build:
1. Clone this repository using the `--recursive` flag to ensure the settings submodule also gets cloned
2. `cd` into the cloned repo
3. Run `just -l` to see build options

### just targets

`just` targets:

- `build` — build the browser binary inside a Debian container.
- `package` — package all release artifacts: tarball, AppImage, and `.deb`.
- `tarball` — package the release tarball and symbols under `build/release/`.
- `appimage` — package an AppImage from the release tarball.
- `deb` — package a `.deb` from the release tarball.
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
