# Jobrowsa

I'm tired of elements and sciency names. This is my fork, Joe's fork, Joe's bowser, Jobrowsa.

A fork of Helium for Linux with:
- Trivalent's patches, including Vanadium
- Fingerprinting Improvements:
  - Timezone normalized to anonymity cohort representatives (e.g. `America/Toronto` reports as `America/New_York`); fixed offsets like UTC are left untouched
  - CPU count and device memory reported from coordinated capability-safe hardware profiles, so `navigator.hardwareConcurrency` and `navigator.deviceMemory` always describe a plausible machine
  - Max touch points limited to 5
  - Installed-font probing so Helium's font cohort policy reflects the fonts actually present on Linux
- Performance features from [Thorium](https://github.com/Alex313031/thorium):
  - x86-64 baseline SIMD raised to AVX (SSE3 through SSE4.2, AES-NI, PCLMUL) plus WebRTC AVX2
  - Aggressive ThinLTO optimizations and hot/cold text section splitting
  - 256-bit re-vectorization pass in the V8 WASM pipeline
  - Inline script precompiling for faster page loads
  - Stack variables zero-initialized
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

### Thorium

Performance features are adapted from
[Thorium](https://github.com/Alex313031/thorium), the performance-focused
Chromium fork. The x86-64 SIMD baseline patch derives from Thorium's
`build/config/compiler_opt.gni`, and the remaining knobs (ThinLTO
optimizations, text section splitting, WASM 256-bit re-vectorization, inline
script precompiling, zero-initialized stack variables) are enabled via
`flags.linux.gn`.

## License

All code, patches, modified portions of imported code or patches, and
any other content that is unique to this project and not imported from other
repositories is licensed under GPL-3.0. See [LICENSE](LICENSE).

Any content imported from other projects retains its original license (for
example, any original unmodified code imported from ungoogled-chromium remains
licensed under their [BSD 3-Clause license](LICENSE.ungoogled_chromium)).
