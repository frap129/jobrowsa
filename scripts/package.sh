#!/usr/bin/env bash
set -euo pipefail

_stage="${1:-all}"
if [ "$#" -gt 0 ]; then shift; fi
_extra_args=("$@")

case "$_stage" in
tarball | appimage | deb | all) ;;
*)
	echo "usage: $0 <tarball|appimage|deb|all> [appimagetool args...]" >&2
	exit 1
	;;
esac

_current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
_root_dir="$(cd "$_current_dir/.." && pwd)"
_build_dir="$_root_dir/build"
_release_dir="$_build_dir/release"
_app_dir="$_release_dir/Jobrowsa.AppDir"

_app_name="jobrowsa"
_version=$(python3 "$_root_dir/helium-chromium/utils/helium_version.py" \
	--tree "$_root_dir/helium-chromium" \
	--platform-tree "$_root_dir" \
	--print)

_arch=$(cat "$_build_dir/src/out/Default/args.gn" |
	grep ^target_cpu |
	tail -1 |
	sed 's/.*=//' |
	cut -d'"' -f2)

if [ "$_arch" = "x64" ]; then
	_arch="x86_64"
fi

_release_name="$_app_name-$_version-$_arch"
_tarball_name="${_release_name}_linux"
_tarball_dir="$_release_dir/$_tarball_name"
_tarball_path="$_release_dir/$_tarball_name.tar.xz"

_files="jobrowsa
chrome_100_percent.pak
chrome_200_percent.pak
jobrowsa_crashpad_handler
chromedriver
icudtl.dat
libEGL.so
libGLESv2.so
libqt5_shim.so
libqt6_shim.so
libvulkan.so.1
locales/
product_logo_256.png
resources.pak
v8_context_snapshot.bin"

_stage_tarball() {
	echo "copying release files and creating $_tarball_name.tar.xz"

	rm -rf "$_tarball_dir"
	mkdir -p "$_tarball_dir"

	for file in $_files; do
		cp -r "$_build_dir/src/out/Default/$file" "$_tarball_dir" &
	done

	cp "$_root_dir/package/jobrowsa.desktop" "$_tarball_dir"
	cp "$_root_dir/package/apparmor.cfg" "$_tarball_dir"
	cp "$_root_dir/package/jobrowsa-wrapper.sh" "$_tarball_dir/jobrowsa-wrapper"

	wait
	(cd "$_tarball_dir" && ln -sf jobrowsa chrome)

	_syms_zip="$_release_dir/${_release_name}_symbols.zip"
	rm -f "$_syms_zip"
	find "$_tarball_dir" -type f -exec file {} + |
		awk -F: '/ELF/ {print $1}' |
		sed "s|^$_tarball_dir/||" |
		(cd "$_build_dir/src/out/Default" && zip -q "$_syms_zip" -@)

	if command -v eu-strip >/dev/null 2>&1; then
		_strip_cmd=(eu-strip)
	else
		_strip_cmd=(strip --strip-unneeded)
	fi

	find "$_tarball_dir" -type f -exec file {} + |
		awk -F: '/ELF/ {print $1}' |
		xargs "${_strip_cmd[@]}"

	_size="$(du -sk "$_tarball_dir" | cut -f1)"

	pushd "$_release_dir"
	tar vcf - "$_tarball_name" |
		pv -s"${_size}k" |
		xz -e9 >"$_tarball_path"
	popd

	rm -rf "$_tarball_dir"

	if [ -n "${SIGN_TARBALL:-}" ]; then
		gpg --batch --pinentry-mode loopback \
			--detach-sign --passphrase "$GPG_PASSPHRASE" \
			--output "$_tarball_path.asc" "$_tarball_path"
	fi
}

_stage_appimage() {
	# create AppImage from the release tarball
	rm -rf "$_app_dir"
	mkdir -p "$_app_dir/opt/jobrowsa/" "$_app_dir/usr/share/icons/hicolor/256x256/apps/"
	tar -xf "$_tarball_path" --strip-components=1 -C "$_app_dir/opt/jobrowsa/"
	cp "$_root_dir/package/jobrowsa.desktop" "$_app_dir"

	cp "$_root_dir/package/jobrowsa-wrapper-appimage.sh" "$_app_dir/AppRun"

	for out in "$_app_dir/jobrowsa.png" "${_app_dir}/usr/share/icons/hicolor/256x256/apps/jobrowsa.png"; do
		cp "${_app_dir}/opt/jobrowsa/product_logo_256.png" "$out"
	done

	export APPIMAGETOOL_APP_NAME="Jobrowsa"
	export VERSION="$_version"

	# check whether CI GPG secrets are available
	if [[ -n "${GPG_PRIVATE_KEY:-}" && -n "${GPG_PASSPHRASE:-}" ]]; then
		echo "$GPG_PRIVATE_KEY" | gpg --batch --import --passphrase "$GPG_PASSPHRASE"
		export APPIMAGETOOL_SIGN_PASSPHRASE="$GPG_PASSPHRASE"
	fi

	pushd "$_release_dir"
	appimagetool \
		"$_app_dir" \
		"$_release_name.AppImage" "${_extra_args[@]}"
	popd

	rm -rf "$_app_dir"
}

_stage_deb() {
	"$_root_dir/package/mkdeb.sh" "$_tarball_path"
}

case "$_stage" in
tarball | all) _stage_tarball ;;
esac
case "$_stage" in
appimage | all) _stage_appimage ;;
esac
case "$_stage" in
deb | all) _stage_deb ;;
esac
