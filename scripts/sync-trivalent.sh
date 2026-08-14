#!/usr/bin/env bash
# sync-trivalent.sh - import and verify secureblue/Trivalent patches
#
# Modes:
#   (no options)           non-mutating upstream check against the manifest
#   --update               download new/changed pristine patches, update manifest
#   --verify-apply         offline zero-fuzz verification of both patch series
#   --verify-apply --keep-state
#                          stop at first failed patch, preserve preimages
#
# This script never commits, never force-applies, and never applies with fuzz.

set -euo pipefail

_root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"

_manifest_file="${_root_dir}/trivalent.manifest"
_shared_series="${_root_dir}/helium-chromium/patches/series"
_local_series="${_root_dir}/patches/series"
_shared_patches_dir="helium-chromium/patches"
_local_patches_dir="patches"
_src_dir="${_root_dir}/build/src"
_verify_snap_dir="${_root_dir}/build/.verify-snap"
_verify_series_dir="${_root_dir}/build/.verify-series"
_work_dir="${_root_dir}/build/.sync-trivalent"

_api_base="https://api.github.com/repos/secureblue/Trivalent"
_raw_base="https://raw.githubusercontent.com/secureblue/Trivalent"
_live_branch="live"
_manifest_snapshot_line='trivalent-snapshot'
_sha_regex='^[0-9a-f]{40}$'

_die() {
    printf 'error: %s\n' "$*" >&2
    exit 2
}

_usage() {
    cat >&2 <<'EOF'
usage: sync-trivalent.sh [--update] [--verify-apply [--keep-state]] [--snapshot <sha>]

  --update            download new/changed pristine patches and update the manifest
  --verify-apply      offline zero-fuzz verification of shared and local series
  --keep-state        with --verify-apply: stop at first failure, keep preimages
  --snapshot <sha>    pin the upstream snapshot; default is GitHub branch "live"
EOF
    exit 2
}

# _require_tools <mode> - verify mode: python3 + GNU patch (patches.py shells
# out to it, honoring PATCH_BIN); upstream modes: python3 + curl
_require_tools() {
    if ! command -v python3 >/dev/null 2>&1; then
        _die "python3 is required"
    fi
    if [ "${1:-}" = "verify" ]; then
        if [ -z "${PATCH_BIN:-}" ] && ! command -v patch >/dev/null 2>&1; then
            _die "patch is required for --verify-apply (or set PATCH_BIN)"
        fi
    elif ! command -v curl >/dev/null 2>&1; then
        _die "curl is required"
    fi
}

_auth_args=()

_sha_is_valid() {
    [[ "$1" =~ ${_sha_regex} ]]
}

# _resolve_snapshot <snapshot> - echo explicit snapshot, else live branch head
_resolve_snapshot() {
    local _snapshot="$1"
    if [ -n "${_snapshot}" ]; then
        printf '%s\n' "${_snapshot}"
        return 0
    fi
    local _json="${_work_dir}/live.json"
    local _live_sha
    mkdir -p "${_work_dir}"
    curl -fsSL --max-time 60 "${_auth_args[@]}" \
        "${_api_base}/commits/${_live_branch}" -o "${_json}" ||
        _die "failed to fetch live commit from ${_api_base}"
    _live_sha="$(
        python3 - "${_json}" <<'PYEOF'
import json, sys
try:
    data = json.load(open(sys.argv[1]))
except Exception as exc:
    sys.stderr.write(f'error: invalid JSON from GitHub API: {exc}\n')
    sys.exit(1)
sha = data.get('sha')
if not sha:
    sys.stderr.write('error: GitHub API response missing "sha"\n')
    sys.exit(1)
print(sha)
PYEOF
    )" || _die "failed to parse live commit response from GitHub"
    printf '%s\n' "${_live_sha}"
}

# _fetch_tree <sha> <out_tsv> - blob paths + shas of the snapshot commit
_fetch_tree() {
    local _sha="$1" _out_tsv="$2"
    if ! _sha_is_valid "${_sha}"; then
        _die "invalid snapshot sha: ${_sha}"
    fi
    local _json="${_work_dir}/tree.json"
    mkdir -p "${_work_dir}"
    curl -fsSL --max-time 120 "${_auth_args[@]}" \
        "${_api_base}/git/trees/${_sha}?recursive=1" -o "${_json}" ||
        _die "failed to fetch git tree for ${_sha}"
    python3 - "${_json}" "${_out_tsv}" <<'PYEOF' || _die "failed to parse git tree response from GitHub"
import json, sys
try:
    data = json.load(open(sys.argv[1]))
except Exception as exc:
    sys.stderr.write(f'error: invalid JSON from GitHub API: {exc}\n')
    sys.exit(1)
if data.get('truncated'):
    sys.stderr.write('error: git tree response was truncated\n')
    sys.exit(1)
tree = data.get('tree')
if not isinstance(tree, list):
    sys.stderr.write('error: GitHub API response missing "tree"\n')
    sys.exit(1)
with open(sys.argv[2], 'w', encoding='UTF-8') as out:
    for entry in tree:
        if entry.get('type') == 'blob' and entry.get('path') and entry.get('sha'):
            out.write(f"{entry['path']}\t{entry['sha']}\n")
PYEOF
}

# _local_group_for <upstream-group> - echo local dir | "excluded" | "unknown"
_local_group_for() {
    case "$1" in
    patches/third_party/vanadium)
        printf '%s\n' 'patches/vanadium'
        ;;
    patches/trivalent)
        printf '%s\n' 'patches/trivalent'
        ;;
    patches/trivalent/security | patches/trivalent/privacy | \
        patches/trivalent/ui | patches/trivalent/translations | \
        patches/trivalent/linux | patches/trivalent/fixes)
        printf '%s\n' "$1"
        ;;
    patches/trivalent/branding | patches/third_party/fedora)
        printf '%s\n' 'excluded'
        ;;
    *)
        printf '%s\n' 'unknown'
        ;;
    esac
}

# _parse_manifest - fills _m_snapshot and parallel row arrays
_parse_manifest() {
    if [ ! -f "${_manifest_file}" ]; then
        _die "manifest not found: ${_manifest_file}"
    fi
    _m_snapshot=""
    _row_state=()
    _row_sha=()
    _row_up=()
    _row_local=()
    _row_line=()
    local _lineno=0 _snapshot_count=0 _seen_entries=false
    while IFS= read -r _line || [ -n "${_line}" ]; do
        _lineno=$((_lineno + 1))
        case "${_line}" in
        '' | '#'*)
            continue
            ;;
        esac
        if [[ "${_line}" == ${_manifest_snapshot_line}* ]]; then
            # exactly one snapshot header is required, in the header section
            # before any entry rows, with the form "trivalent-snapshot <sha>"
            _snapshot_count=$((_snapshot_count + 1))
            if [ "${_snapshot_count}" -gt 1 ]; then
                _die "manifest line ${_lineno}: duplicate '${_manifest_snapshot_line}' header"
            fi
            if [ "${_seen_entries}" = "true" ]; then
                _die "manifest line ${_lineno}: '${_manifest_snapshot_line}' header must precede entry rows"
            fi
            _m_snapshot="${_line#"${_manifest_snapshot_line} "}"
            if [ "${_m_snapshot}" = "${_line}" ] || ! _sha_is_valid "${_m_snapshot}"; then
                _die "manifest line ${_lineno}: malformed '${_manifest_snapshot_line} <sha>' header"
            fi
            continue
        fi
        _seen_entries=true
        local _up _sha _state _local_dir
        read -r _up _sha _state <<<"${_line}"
        if [[ -z "${_up}" || -z "${_sha}" || -z "${_state}" ]]; then
            _die "manifest line ${_lineno}: expected '<upstream-path> <upstream-blob-sha> <disposition>'"
        fi
        case "${_state}" in
        pristine | adapted | dropped) ;;
        *) _die "manifest line ${_lineno}: unknown disposition '${_state}'" ;;
        esac
        if ! _sha_is_valid "${_sha}"; then
            _die "manifest line ${_lineno}: invalid blob sha"
        fi
        # local path is derived from the upstream path via the group mapping;
        # excluded and unknown groups vendored nothing, so no local path exists
        _local_dir="$(_local_group_for "$(dirname "${_up}")")"
        case "${_local_dir}" in
        excluded | unknown) _row_local+=("") ;;
        *) _row_local+=("${_local_dir}/$(basename "${_up}")") ;;
        esac
        _row_state+=("${_state}")
        _row_sha+=("${_sha}")
        _row_up+=("${_up}")
        _row_line+=("${_lineno}")
    done <"${_manifest_file}"
    if [ "${_snapshot_count}" -eq 0 ]; then
        _die "manifest is missing the '${_manifest_snapshot_line} <sha>' header"
    fi
}

# _touched_files <patch-file> - tree-relative target paths a patch may modify
# Paths are taken from both the "--- a/" (old) and "+++ b/" (new) headers so
# that deleted files are captured for preimage restore. Standard unified diff
# headers carry a tab-delimited timestamp ("path<TAB>YYYY-MM-DD ..."), which
# is stripped; paths whose final component merely resembles a date are kept
# intact (no space-delimited truncation).
_touched_files() {
    python3 - "$1" <<'PYEOF'
import re, sys
patch_file = sys.argv[1]
seen = []
with open(patch_file, encoding='UTF-8', errors='replace') as f:
    for line in f:
        # -p1 semantics: drop exactly one leading component (a/, b/) from
        # the "---"/"+++" header path, quoted or not
        match = re.match(r'^(?:--- |\+\+\+ )(.*)$', line.strip())
        if not match:
            continue
        path = match.group(1).strip('"')
        if path.startswith('a/') or path.startswith('b/'):
            path = path[2:]
        path = path.split('\t', 1)[0]
        if path == '/dev/null' or path in seen:
            continue
        seen.append(path)
print('\n'.join(seen))
PYEOF
}

# _snapshot_preimages <entry> <patch-file> - copy touched files before applying
_snapshot_preimages() {
    local _entry="$1" _patch="$2"
    local _flat="${_entry//\//_}"
    local _snap="${_verify_snap_dir}/${_flat}"
    local _path _touched
    # detect extraction failure explicitly; a silent empty list would leave
    # nothing to restore from on a later failure
    _touched="$(_touched_files "${_patch}")" || _die "failed to read patch: ${_patch}"
    rm -rf "${_snap}"
    while IFS= read -r _path; do
        [ -n "${_path}" ] || continue
        if [ -f "${_src_dir}/${_path}" ]; then
            mkdir -p "${_snap}/$(dirname "${_path}")"
            cp -a --reflink=auto "${_src_dir}/${_path}" "${_snap}/${_path}"
        else
            mkdir -p "${_snap}/$(dirname "${_path}")"
            printf '%s\n' 'absent' >"${_snap}/${_path}.absent"
        fi
    done <<<"${_touched}"
    printf '%s\n' "${_snap}"
}

# _restore_entry <entry> <patch-file> <snap-dir> [keep-snap] - undo partial
# application; preimages are removed after restoring unless keep-snap is true
_restore_entry() {
    local _entry="$1" _patch="$2" _snap="$3" _keep_snap="${4:-false}"
    local _path _touched
    _touched="$(_touched_files "${_patch}")" || _die "failed to read patch: ${_patch}"
    while IFS= read -r _path; do
        [ -n "${_path}" ] || continue
        rm -f "${_src_dir}/${_path}.rej" "${_src_dir}/${_path}.orig"
        if [ -f "${_snap}/${_path}" ]; then
            cp -a --reflink=auto "${_snap}/${_path}" "${_src_dir}/${_path}"
        else
            rm -f "${_src_dir}/${_path}"
        fi
    done <<<"${_touched}"
    if [ "${_keep_snap}" != "true" ]; then
        rm -rf "${_snap}"
    fi
}

# _apply_entry <entry> <patch-abs> - single-entry series, zero fuzz; 0 on success
_apply_entry() {
    local _entry="$1" _patch_abs="$2"
    printf '%s\n' "${_patch_abs}" >"${_verify_series_dir}/series"
    if python3 "${_root_dir}/helium-chromium/utils/patches.py" apply --no-fuzz \
        "${_src_dir}" "${_verify_series_dir}" >"${_verify_series_dir}/apply.log" 2>&1; then
        return 0
    fi
    cat "${_verify_series_dir}/apply.log" >&2
    return 1
}

# _apply_series_file <series-file> <patches-dir> - verify every entry
_apply_series_file() {
    local _series_file="$1" _patches_dir="$2"
    local _entry _patch_abs _snap
    # Parse the series into a temp file first so a missing/unreadable series
    # or parser failure is detected explicitly instead of being swallowed by
    # the while-read loop's EOF status.
    local _entries_file="${_verify_series_dir}/entries.list"
    if ! python3 - "${_series_file}" >"${_entries_file}" <<'PYEOF'; then
import sys
with open(sys.argv[1], encoding='UTF-8') as f:
    lines = f.read().splitlines()
lines = filter(len, lines)
lines = filter(lambda x: not x.startswith('#'), lines)
lines = map(lambda x: x.strip().split(' #')[0], lines)
print('\n'.join(lines))
PYEOF
        printf 'FAILED: %s (unreadable series file)\n' "${_series_file}" >&2
        _failures=$((_failures + 1))
        if [ "${_keep_state}" = "true" ]; then
            return 1
        fi
        return 0
    fi
    while IFS= read -r _entry; do
        [ -n "${_entry}" ] || continue
        _patch_abs="${_root_dir}/${_patches_dir}/${_entry}"
        if [ ! -f "${_patch_abs}" ]; then
            printf 'FAILED: %s (patch file missing)\n' "${_entry}" >&2
            _failures=$((_failures + 1))
            # --keep-state stops at the first failure; preimages of entries
            # processed so far are already preserved in .verify-snap
            if [ "${_keep_state}" = "true" ]; then
                return 1
            fi
            continue
        fi
        _snap="$(_snapshot_preimages "${_entry}" "${_patch_abs}")"
        if _apply_entry "${_entry}" "${_patch_abs}"; then
            if [ "${_keep_state}" != "true" ]; then
                rm -rf "${_snap}"
            fi
            continue
        fi
        printf 'FAILED: %s\n' "${_entry}" >&2
        _failures=$((_failures + 1))
        if [ "${_keep_state}" = "true" ]; then
            # keep-state: restore the failed patch's touched files to their
            # pre-patch state while keeping the preimage snapshot dir; earlier
            # successful applications stay applied (rebase workflow: tree
            # holds patches 1..N-1, snapshot holds pre-N state)
            _restore_entry "${_entry}" "${_patch_abs}" "${_snap}" true
            return 1
        fi
        _restore_entry "${_entry}" "${_patch_abs}" "${_snap}"
    done <"${_entries_file}"
}

_verify_apply() {
    _require_tools verify
    if [ ! -d "${_src_dir}" ]; then
        _die "--verify-apply requires ${_src_dir} (materialize the pristine tree first)"
    fi
    # Verification only makes sense on a pristine tree; the pipeline's
    # .patched.stamp marks a tree that already went through patch application.
    if [ -f "${_src_dir}/.patched.stamp" ]; then
        _die "--verify-apply requires a pristine tree: ${_src_dir}/.patched.stamp exists"
    fi
    rm -rf "${_verify_snap_dir}" "${_verify_series_dir}"
    mkdir -p "${_verify_series_dir}"

    _failures=0
    local _series_status=0
    # Shared series first, then local; this ordering is architectural.
    # The series walker returns nonzero only to signal a --keep-state stop;
    # application failures are recorded in _failures either way, so the
    # status is captured rather than masked.
    _apply_series_file "${_shared_series}" "${_shared_patches_dir}" || _series_status=$?
    if [ "${_keep_state}" = "true" ] && [ "${_failures}" -gt 0 ]; then
        printf 'manual attention required (%d patch(es) failed)\n' "${_failures}" >&2
        exit 1
    fi
    _apply_series_file "${_local_series}" "${_local_patches_dir}" || _series_status=$?

    if [ "${_failures}" -gt 0 ]; then
        printf 'manual attention required (%d patch(es) failed)\n' "${_failures}" >&2
        exit 1
    fi
    printf '%s\n' 'all patches applied with zero fuzz'
}

# _download_blob <commit-sha> <upstream-path> <local-path>
# Raw downloads resolve against the snapshot commit; the blob SHA recorded in
# the manifest is used only for upstream change detection.
_download_blob() {
    local _sha="$1" _up="$2" _local="$3"
    mkdir -p "$(dirname "${_local}")"
    curl -fsSL --max-time 120 \
        "${_raw_base}/${_sha}/${_up}" -o "${_local}.part" ||
        _die "failed to download ${_up} at ${_sha}"
    mv "${_local}.part" "${_local}"
}

# _series_has_entry <entry> - 0 if the entry is already listed in the local
# series (blank/comment lines and inline comments are ignored)
_series_has_entry() {
    local _entry="$1" _line _stripped
    [ -f "${_local_series}" ] || return 1
    while IFS= read -r _line; do
        case "${_line}" in
        '' | '#'*) continue ;;
        esac
        _stripped="${_line%% *}"
        if [ "${_stripped}" = "${_entry}" ]; then
            return 0
        fi
    done <"${_local_series}"
    return 1
}

# _insert_series_entry <entry> - lexicographic within contiguous group, else
# append. Idempotent: an already-listed entry is left untouched (an
# interrupted --update may have inserted the series entry before the manifest
# write completed). Returns 1 when duplicate entries already exist.
_insert_series_entry() {
    local _entry="$1"
    local _prefix="${_entry%/*}"
    if [ ! -f "${_local_series}" ]; then
        printf '%s\n' "${_entry}" >"${_local_series}"
        return 0
    fi
    local _lines=() _i=0 _start=-1 _end=-1 _entry_line _count=0
    mapfile -t _lines <"${_local_series}"
    # count existing occurrences first; one match is the idempotent no-op,
    # more than one is a pre-existing inconsistency reported by the caller
    for ((_i = 0; _i < ${#_lines[@]}; _i++)); do
        _entry_line="${_lines[_i]}"
        case "${_entry_line}" in
        '' | '#'*) continue ;;
        esac
        _entry_line="${_entry_line%% *}"
        if [ "${_entry_line}" = "${_entry}" ]; then
            _count=$((_count + 1))
        fi
    done
    if [ "${_count}" -gt 1 ]; then
        return 1
    fi
    if [ "${_count}" -eq 1 ]; then
        return 0
    fi
    # locate the contiguous run of entries sharing the group prefix
    for ((_i = 0; _i < ${#_lines[@]}; _i++)); do
        _entry_line="${_lines[_i]}"
        case "${_entry_line}" in
        '' | '#'*)
            continue
            ;;
        esac
        _entry_line="${_entry_line%% *}"
        if [[ "${_entry_line}" == "${_prefix}"/* ]]; then
            if [ "${_start}" -lt 0 ]; then
                _start="${_i}"
            fi
            _end="${_i}"
        elif [ "${_end}" -ge 0 ]; then
            break
        fi
    done
    if [ "${_start}" -lt 0 ]; then
        printf '%s\n' "${_entry}" >>"${_local_series}"
        return 0
    fi
    # insert lexicographically inside the contiguous group
    for ((_i = _start; _i <= _end; _i++)); do
        _entry_line="${_lines[_i]}"
        case "${_entry_line}" in
        '' | '#'*) continue ;;
        esac
        _entry_line="${_entry_line%% *}"
        if [[ "${_entry}" < "${_entry_line}" ]]; then
            _lines=("${_lines[@]:0:_i}" "${_entry}" "${_lines[@]:_i}")
            printf '%s\n' "${_lines[@]}" >"${_local_series}"
            return 0
        fi
    done
    _lines=("${_lines[@]:0:_end+1}" "${_entry}" "${_lines[@]:_end+1}")
    printf '%s\n' "${_lines[@]}" >"${_local_series}"
}

# _rewrite_manifest - apply pending updates/additions to the manifest file
_rewrite_manifest() {
    local _lines=() _i _updated=() _up _sha _state
    mapfile -t _lines <"${_manifest_file}"
    for _i in "${!_rows_updated[@]}"; do
        local _line_idx="${_row_line_idx[_i]}" _new_sha="${_rows_updated[_i]}"
        # row line indices are 1-based; array is 0-based
        local _arr_idx=$((_line_idx - 1))
        local _old="${_lines[_arr_idx]}"
        read -r _up _sha _state <<<"${_old}"
        _lines[_arr_idx]="${_up} ${_new_sha} ${_state}"
    done
    for _i in "${!_new_rows[@]}"; do
        _lines+=("${_new_rows[_i]}")
    done
    if [ -n "${_new_snapshot}" ]; then
        for _i in "${!_lines[@]}"; do
            if [[ "${_lines[_i]}" == ${_manifest_snapshot_line}* ]]; then
                _lines[_i]="${_manifest_snapshot_line} ${_new_snapshot}"
                break
            fi
        done
    fi
    printf '%s\n' "${_lines[@]}" >"${_manifest_file}"
}

_check_upstream() {
    _require_tools
    _parse_manifest
    local _snapshot _tree_tsv
    _snapshot="$(_resolve_snapshot "${_snapshot_arg}")"
    _tree_tsv="${_work_dir}/tree.tsv"
    _fetch_tree "${_snapshot}" "${_tree_tsv}"

    local _attention=false
    # upstream patch map: path -> sha for *.patch under patches/
    local -A _up_map=()
    local _path _sha
    while IFS=$'\t' read -r _path _sha; do
        case "${_path}" in
        patches/*/*.patch) _up_map["${_path}"]="${_sha}" ;;
        esac
    done <"${_tree_tsv}"

    local -A _known_up=()
    local _i _state _up _local _rec_sha _row_unclean
    # local series entries, for consistency checks below
    local -A _series_entries=()
    local _series_line
    if [ -f "${_local_series}" ]; then
        while IFS= read -r _series_line; do
            case "${_series_line}" in
            '' | '#'*) continue ;;
            esac
            _series_entries["${_series_line%% *}"]=1
        done <"${_local_series}"
    fi
    # manifest row checks
    for _i in "${!_row_state[@]}"; do
        _state="${_row_state[_i]}"
        _up="${_row_up[_i]}"
        _local="${_row_local[_i]}"
        _rec_sha="${_row_sha[_i]}"
        _known_up["${_up}"]=1
        _row_unclean=false
        if [ "${_state}" != "dropped" ] && [ -n "${_local}" ] &&
            [ ! -f "${_root_dir}/${_local}" ]; then
            printf 'missing: %s (recorded as %s in manifest, not on disk)\n' \
                "${_local}" "${_state}" >&2
            _attention=true
            _row_unclean=true
        fi
        if [ "${_state}" != "dropped" ] && [ -n "${_local}" ] &&
            [[ ! -v _series_entries["${_local#patches/}"] ]]; then
            printf 'attention: %s (vendored but not listed in patches/series)\n' \
                "${_local}" >&2
            _attention=true
            _row_unclean=true
        fi
        if [[ ! -v _up_map["${_up}"] ]]; then
            printf 'deleted: %s (removed upstream)\n' "${_up}" >&2
            if [ "${_state}" != "dropped" ]; then
                _attention=true
            fi
            continue
        fi
        if [ "${_up_map["${_up}"]}" != "${_rec_sha}" ]; then
            if [ "${_state}" = "pristine" ] && [ -n "${_local}" ]; then
                if [ "${_update}" = "true" ]; then
                    _download_blob "${_snapshot}" "${_up}" "${_root_dir}/${_local}"
                    _rows_updated+=("${_up_map["${_up}"]}")
                    _row_line_idx+=("${_row_line[_i]}")
                    printf 'updated: %s (upstream blob %s)\n' "${_local}" "${_up_map["${_up}"]}"
                else
                    printf 'stale: %s (upstream blob changed)\n' "${_local}" >&2
                    _attention=true
                fi
            else
                printf 'attention: %s (upstream blob changed; %s patches are never auto-updated)\n' \
                    "${_local:-${_up}}" "${_state}" >&2
                _attention=true
            fi
        elif [ "${_row_unclean}" != "true" ]; then
            if [ "${_state}" = "dropped" ]; then
                printf 'dropped-unchanged: %s\n' "${_up}"
            else
                printf 'unchanged: %s\n' "${_local:-${_up}}"
            fi
        fi
    done

    # new patches and unknown groups
    local -A _groups_reported=()
    local _group _local_dir _up
    for _up in "${!_up_map[@]}"; do
        if [[ -v _known_up["${_up}"] ]]; then
            continue
        fi
        _group="$(dirname "${_up}")"
        _local_dir="$(_local_group_for "${_group}")"
        if [ "${_local_dir}" = "excluded" ]; then
            continue
        fi
        if [ "${_local_dir}" = "unknown" ]; then
            if [[ ! -v _groups_reported["${_group}"] ]]; then
                printf 'new-group: %s (unknown patch group requires attention)\n' "${_group}" >&2
                _groups_reported["${_group}"]=1
                _attention=true
            fi
            continue
        fi
        if [ "${_update}" = "true" ]; then
            _series_entry="${_local_dir#patches/}/$(basename "${_up}")"
            _local_path="${_local_dir}/$(basename "${_up}")"
            # Suspicious inconsistent states that this tool's add flow never
            # produces (download precedes series insertion, manifest is
            # written last): a vendored file without a series entry or row
            # may be hand-managed, and a series entry without a vendored file
            # references nothing. Do not silently adopt or overwrite them.
            if [ -f "${_root_dir}/${_local_path}" ] && ! _series_has_entry "${_series_entry}"; then
                printf 'attention: %s (vendored file without series entry or manifest row)\n' \
                    "${_local_path}" >&2
                _attention=true
                continue
            fi
            if [ ! -f "${_root_dir}/${_local_path}" ] && _series_has_entry "${_series_entry}"; then
                printf 'attention: %s (series entry without vendored file)\n' \
                    "${_series_entry}" >&2
                _attention=true
                continue
            fi
            _download_blob "${_snapshot}" "${_up}" "${_root_dir}/${_local_path}"
            # idempotent: an interrupted --update may already have the entry;
            # a return of 1 means pre-existing duplicate entries
            if _insert_series_entry "${_series_entry}"; then
                :
            else
                printf 'attention: %s (duplicate series entries present)\n' "${_series_entry}" >&2
                _attention=true
            fi
            _new_rows+=("${_up} ${_up_map["${_up}"]} pristine")
            printf 'added: %s\n' "${_up}"
        else
            printf 'new: %s\n' "${_up}"
            _attention=true
        fi
    done

    if [ "${_update}" = "true" ] && { [ ${#_rows_updated[@]} -gt 0 ] || [ ${#_new_rows[@]} -gt 0 ]; }; then
        _new_snapshot="${_snapshot}"
        if [ "${_new_snapshot}" != "${_m_snapshot}" ]; then
            printf 'snapshot: updated %s -> %s\n' "${_m_snapshot}" "${_new_snapshot}"
        else
            _new_snapshot=""
        fi
        _rewrite_manifest
    elif [ "${_m_snapshot}" != "${_snapshot}" ]; then
        printf 'snapshot: manifest %s, upstream %s\n' "${_m_snapshot}" "${_snapshot}"
    fi

    if [ "${_attention}" = "true" ]; then
        printf '%s\n' 'manual attention required' >&2
        exit 1
    fi
}

_update=false
_verify=false
_keep_state=false
_snapshot_arg=""
_new_rows=()
_rows_updated=()
_row_line_idx=()

while [ $# -gt 0 ]; do
    case "$1" in
    --update)
        _update=true
        shift
        ;;
    --verify-apply)
        _verify=true
        shift
        ;;
    --keep-state)
        _keep_state=true
        shift
        ;;
    --snapshot)
        if [ $# -lt 2 ]; then
            _usage
        fi
        _snapshot_arg="$2"
        shift 2
        ;;
    -h | --help)
        _usage
        ;;
    *)
        _usage
        ;;
    esac
done

if [ "${_update}" = "true" ] && [ "${_verify}" = "true" ]; then
    _die "--update and --verify-apply are mutually exclusive"
fi
if [ "${_keep_state}" = "true" ] && [ "${_verify}" != "true" ]; then
    _die "--keep-state requires --verify-apply"
fi
if [ -n "${_snapshot_arg}" ] && ! _sha_is_valid "${_snapshot_arg}"; then
    _die "invalid --snapshot sha: ${_snapshot_arg}"
fi
if [ -n "${GITHUB_TOKEN:-}" ]; then
    _auth_args=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

if [ "${_verify}" = "true" ]; then
    _verify_apply
else
    _check_upstream
fi
