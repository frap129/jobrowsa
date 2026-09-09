## Project

Jobrowsa is a personal Chromium-based browser for x86_64 Linux. It is a fork of Helium that combines Helium's build system and selected usability features with a Trivalent-first security patch stack. The product, binary, and packaging are named `jobrowsa` (own patches live under `patches/jobrowsa/`; the helium-chromium layer keeps its historical naming).

`helium-chromium/` is Jobrowsa's own source-transformation layer, forked once from Helium and maintained by us; it is not an extant third-party project. Code never flows back upstream. Upstream Helium changes are still merged in, one direction, into this fork (same flow as this repository's own upstream). To keep those merges clean, minimize changes to upstream-tracked files: prefer adding new files (new patches, new utilities) over editing or restructuring existing ones.

The goal is a reproducible, locally buildable browser that preserves Chromium's security baseline and has no runtime dependency on Helium-controlled services.

## Non-negotiable constraints

- Target x86_64 Linux first and keep Chromium updates close to a weekly cadence.
- Do not regress Chromium's CFI, sandboxing, site isolation, allocator hardening, or security-sensitive bundled libraries without explicit rationale.
- No runtime request or dependency may target a Helium-controlled endpoint. Preserve component security updates through another trusted path.
- Trivalent patches are primary. Retain Helium patches only when compatible with the target architecture and service-independence boundary.
- Keep Helium's reproducible overlay model. Never maintain changes in generated `build/` or `build/src/` content.
- The `helium-chromium/` submodule is editable: apply cross-platform patches there where needed and keep Linux-only patches in this repository.

## Repository layout

- `justfile`: developer entry points; `just -l` lists them. `just build` is the canonical local build command.
- `helium-chromium/`: cross-platform source-transformation layer (git submodule) containing shared patches, utilities, resources, translations, flags, and the pinned Chromium version (`chromium_version.txt`).
- `patches/`: Linux-specific quilt patches applied after the shared series; ordering is defined by `patches/series` (ungoogled-chromium, then helium, then vanadium/trivalent, then `jobrowsa/` last). Own patches go under `patches/jobrowsa/` (`linux/` for platform/build changes, `core/` for product identity and UI strings).
- `flags.linux.gn`: Linux-specific GN arguments applied after shared Helium flags.
- `scripts/shared.sh`: shared source preparation and build operations; sourced by local and CI scripts.
- `scripts/build.sh`: canonical ordered preparation and compilation entry point (runs inside the container).
- `scripts/dev.sh`: mutable development-tree and quilt workflow; source it and use the `he` function.
- `scripts/docker-build.sh`, `package/docker-package.sh`, `package/docker-package-arch.sh`: containerized build and packaging launchers used locally and in CI.
- `scripts/package.sh` and `package/`: artifact assembly and Linux distribution metadata (`jobrowsa.desktop`, wrapper scripts, `mkdeb.sh`, `PKGBUILD`).
- `scripts/sync-trivalent.sh` and `trivalent.manifest`: Trivalent/Vanadium patch sync, verification, and provenance.
- `docker/`: `build.Dockerfile`, `package.Dockerfile`, `arch-package.Dockerfile` image definitions.
- `.github/`: CI build, cache, packaging, signing, and release orchestration.
- `docs/`: reproducibility inventory (`build-input-checklist.md`) and build validation records.

## Build and package (containers)

The host only needs `just` plus rootless Podman (preferred) or Docker; clone with `--recursive` so the submodule is present.

- `just build` runs `SCCACHE_DIR=/repo/.sccache ./scripts/docker-build.sh` (the host `.sccache/` dir is gitignored).
- `just package` produces tarball, AppImage, and `.deb` under `build/release/`; `just tarball | appimage | deb | arch` build a single artifact.
- `just clean` removes `build/`.

Container mechanics:

- `scripts/docker-build.sh` and `package/docker-package.sh` prefer rootless Podman and pass `--userns=keep-id` so bind-mount writes keep host ownership; Docker is the fallback. Do not assume Docker is the required runtime.
- Build image `chromium-builder:trixie-slim` (from `docker/build.Dockerfile`, base `debian:trixie-slim`); packaging image `jobrowsa-trixie-slim:packager` (from `docker/package.Dockerfile`).
- The repo is bind-mounted read-write at `/repo`; the container user is matched to the host via `UID`/`GID` build args.
- The container entrypoint is `scripts/build.sh` locally and `.github/scripts/build.sh` under CI; `_use_existing_image=1` reuses a previously built image.
- `ARCH` selects the target arch (CI matrix builds arm64 and x86_64); `SCCACHE_*` envs are forwarded and enable sccache; `SISO_REAPI_*` envs enable remote execution.
- GPG signing of artifacts happens only when `GPG_PRIVATE_KEY`/`GPG_PASSPHRASE` are set (plus `SIGN_TARBALL=1` for the tarball).

## Architecture and workflow

- Chromium is transformed through ordered overlays: fetch/prune, patch, domain and brand substitution, translation, versioning, resource replacement, GN generation, then compilation.
- The order in `scripts/build.sh` is architectural. Do not reorder stages without validating downstream assumptions.
- Build state is filesystem state in `build/`; stage stamps (`.downloaded.stamp`, `.patched.stamp`, name-subst backup tarball, etc.) prevent repeated destructive mutations.
- Source fetch defaults to downloading archives per `helium-chromium/downloads.ini`/`deps.ini`; `scripts/build.sh -c` clones instead (required for `--pgo`, which is x64-only).
- GN args are generated into `build/src/out/Default/args.gn` from `helium-chromium/flags.gn` + `flags.linux.gn` + arch lines. Never hand-edit the generated file.
- The version is composed from `helium-chromium/version.txt`, `helium-chromium/revision.txt`, and root `revision.txt` by `utils/helium_version.py`; Chromium is bumped via `helium-chromium/chromium_version.txt` and the submodule bump workflow.
- Keep cross-platform behavior in the separately maintained `helium-chromium/` project and Linux-only changes in this repository.
- Express maintained Chromium source changes as quilt patches rather than edits to the generated source tree.

## Development workflow

- `scripts/dev.sh` is sourced, not executed: `source scripts/dev.sh`, then `he <setup|build|run|sub|unsub|namesub|nameunsub|merge|unmerge|push|pop|pull|reset|translate>`.
- Dev builds are component builds (`is_official_build` is swapped to `is_component_build` in args.gn); `he run` launches `out/Default/jobrowsa` with the scratch profile `~/.config/jobrowsa.dev`.
- `he pull` stashes, fetches, and rebases both this repo and the submodule onto their `main` branches, then re-applies the quilt series; run `he unsub` first if substitutions are applied.
- `he reset` deletes the entire `build/src` tree asynchronously.

## Implementation conventions

- Keep changes focused and follow existing Chromium, Helium, and repository patterns.
- Put reusable build functions in `scripts/shared.sh`; keep entry points as short orchestration sequences.
- Use lowercase kebab-case for scripts and quilt patches, and snake_case for shell functions and internal variables.
- Prefix shell-script internal variables with `_`, reserve uppercase names for exported environment variables, and quote expansions unless deliberate word splitting is required.
- Standalone Bash scripts use `#!/usr/bin/env bash` and `set -euo pipefail`; POSIX wrappers use `#!/bin/sh` only when they avoid Bash syntax.
- Use four-space indentation in shell code and two-space structural indentation in GitHub Actions YAML.
- Explain constraints and non-obvious reasons in comments; do not narrate mechanics.
- Preserve target-file formatting and unrelated context in quilt patches. New patch files use lowercase kebab-case with a `.patch` suffix and must be listed in the appropriate `series` file.
- Preserve provenance and required license headers.
- Send shell warnings and validation errors to stderr. Do not mask build, patch, packaging, or test failures; use `|| true` only for explicitly best-effort cleanup.

## Validation

- Validate patch structure with `./helium-chromium/devutils/lint.py -t .` (CI enforces the same on every push and PR).
- When changing shell code, run syntax checks (`bash -n`) for each changed script.
- `scripts/sync-trivalent.sh` with no arguments is a non-mutating upstream drift check; `--update` fetches changed pristine patches and updates the manifest; `--verify-apply` does an offline zero-fuzz application check of both series and requires a pristine `build/src` (fails if `.patched.stamp` exists); `--keep-state` preserves the failure point for manual rebasing.
- Run the narrowest relevant tests or build checks for the changed surface, then broader checks when practical.
- Do not claim a browser build succeeded unless the containerized build pipeline completed successfully.

## Patch import policy (Trivalent/Vanadium)

- Vendored secureblue/Trivalent patches (Vanadium and Trivalent sets) live in this repository's `patches/` tree and apply after the shared Helium series; provenance is tracked in `trivalent.manifest` and sync tooling is `scripts/sync-trivalent.sh`.
- Never modify an existing patch from the Helium, ungoogled, inox, iridium, brave, bromite, debian, or upstream-fixes sets. Resolve conflicts by dropping or replacing a patch, or by adding a new patch under `patches/jobrowsa/`. Vendored patches that no longer apply are replaced in place and re-marked `adapted` in `trivalent.manifest`.
- The build pipeline (`scripts/shared.sh`, `scripts/build.sh`, `scripts/docker-build.sh`, `scripts/dev.sh`, `scripts/package.sh`, `helium-chromium/utils/patches.py`) is unchanged. Additions under `scripts/` are allowed.
- GN args are exempt from the no-modification rule: `helium-chromium/flags.gn` and `flags.linux.gn` are editable and trivially mergable.

## Agent skills

### Issue tracker

Issues live in a local Beads (Dolt) database managed by the `bd` CLI; sync via Dolt over the git remote. See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical triage-role labels are used verbatim, paired with Beads status so waiting issues stay out of `bd ready`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.
