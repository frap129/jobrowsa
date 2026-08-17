from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


class DistributionIdentityTest(unittest.TestCase):
    def assert_contains(self, relative: str, *values: str) -> None:
        text = read(relative)
        for value in values:
            self.assertIn(value, text, f"{relative} must contain {value!r}")

    def assert_not_contains(self, relative: str, *values: str) -> None:
        text = read(relative)
        for value in values:
            self.assertNotIn(value, text, f"{relative} must not contain {value!r}")

    def test_series_appends_jobrowsa_override_patches(self) -> None:
        series_lines = read("patches/series").splitlines()
        overrides = (
            "jobrowsa/linux/change-chromium-branding.patch",
            "jobrowsa/linux/rename-chrome-binary.patch",
            "jobrowsa/core/rename-product-branding.patch",
            "jobrowsa/core/rename-ui-strings.patch",
        )
        override_files = tuple(f"patches/{o}" for o in overrides)
        for entry in overrides:
            self.assertEqual(1, series_lines.count(entry), entry)
        # append-only: the Helium entries underneath stay applied
        for entry in (
            "helium/linux/change-chromium-branding.patch",
            "helium/linux/rename-chrome-binary.patch",
            "helium/linux/add-error-for-missing-desktop-file.patch",
        ):
            self.assertEqual(1, series_lines.count(entry), entry)
        self.assertLess(
            series_lines.index("helium/linux/rename-chrome-binary.patch"),
            series_lines.index(overrides[0]),
        )

        self.assert_contains(
            override_files[0],
            'GetVar("JOBROWSA_DESKTOP")',
            'return "jobrowsa.desktop";',
            'GetVar("JOBROWSA_CONFIG_HOME")',
            'data_dir_basename = "jobrowsa"',
            'PACKAGE="jobrowsa"',
            'MENUNAME="Jobrowsa"',
            'kBrowserDisplayName[] = "jobrowsa"',
            '#define PRODUCT_STRING "Jobrowsa"',
        )
        self.assert_contains(
            override_files[1],
            'output_name = "jobrowsa_crashpad_handler"',
            'Append("jobrowsa_crashpad_handler")',
            'u"jobrowsa"',
            '_chrome_output_name = "jobrowsa"',
            "$root_out_dir/jobrowsa",
        )
        self.assert_contains(
            override_files[2],
            "PRODUCT_FULLNAME=Jobrowsa",
            'product_info->product_name = "Jobrowsa";',
        )
        self.assert_contains(
            override_files[3],
            "Jobrowsa services have been updated",
            "Jobrowsa cannot be set",
        )
        for relative in override_files:
            # '-' lines legitimately carry the old Helium values being removed;
            # only added ('+') lines must not (re)introduce Helium endpoints
            added_lines = "\n".join(
                line for line in read(relative).splitlines() if line.startswith("+")
            )
            for banned in ("services.helium.imput.net", "helium.computer"):
                self.assertNotIn(banned, added_lines, f"{relative} adds {banned!r}")

    def test_package_contract_uses_jobrowsa_identity(self) -> None:
        required = (
            "package/jobrowsa.desktop",
            "package/jobrowsa-bin.spec",
            "package/jobrowsa-wrapper.sh",
            "package/jobrowsa-wrapper-appimage.sh",
        )
        removed = (
            "package/helium.desktop",
            "package/helium-bin.spec",
            "package/helium-wrapper.sh",
            "package/helium-wrapper-appimage.sh",
            "package/net.imput.helium.metainfo.xml",
        )
        for relative in required:
            self.assertTrue((ROOT / relative).is_file(), relative)
        for relative in removed:
            self.assertFalse((ROOT / relative).exists(), relative)

        self.assert_contains(
            "package/jobrowsa.desktop",
            "Name=Jobrowsa",
            "Exec=jobrowsa %U",
            "Icon=jobrowsa",
            "Exec=jobrowsa --incognito",
        )
        self.assert_contains(
            "package/jobrowsa-bin.spec",
            "Name:    jobrowsa-bin",
            "%define jobrowsa_base /opt/jobrowsa",
            "%{_bindir}/jobrowsa",
            "%{_datadir}/applications/jobrowsa.desktop",
            "/etc/apparmor.d/jobrowsa-bin",
        )
        self.assert_not_contains(
            "package/jobrowsa-bin.spec",
            "net.imput",
            "imputnet/helium",
            "helium.computer",
            "/helium",
        )
        self.assert_contains(
            "package/jobrowsa-wrapper.sh", 'exec "$HERE/jobrowsa" "$@"'
        )
        self.assert_contains(
            "package/jobrowsa-wrapper-appimage.sh",
            "jobrowsa-appimage",
            '"${HERE}"/opt/jobrowsa/jobrowsa "$@"',
        )
        self.assert_contains(
            "package/apparmor.cfg",
            'profile jobrowsa-bin "/opt/jobrowsa/jobrowsa"',
            "<local/jobrowsa-bin>",
        )
        self.assert_contains(
            "package/PKGBUILD",
            "pkgname=jobrowsa-bin",
            "JOBROWSA_VERSION",
            "usr/lib/jobrowsa",
            "usr/bin/jobrowsa",
            "ln -s jobrowsa ",
        )
        self.assert_not_contains(
            "package/PKGBUILD",
            "net.imput.helium",
            "usr/lib/helium",
            "usr/bin/helium",
            "s|profile helium-bin",
            "ln -s helium ",
            "\nhelium\n",
        )

    def test_repository_docs_do_not_claim_helium_distribution_services(self) -> None:
        self.assertFalse((ROOT / "pubkey.asc").exists())
        self.assert_contains(
            "README.md", "# jobrowsa-linux", "Jobrowsa", "scripts/docker-build.sh"
        )
        self.assert_not_contains(
            "README.md",
            "pkg.helium.computer",
            "imput/helium",
            "helium-bin",
            "helium.gpg",
            "Helium signing key",
            "Download the latest release",
        )

    def test_ci_uses_jobrowsa_artifact_contract(self) -> None:
        paths = (
            ".github/actions/build/action.yml",
            ".github/actions/package/action.yml",
            ".github/actions/release/action.yml",
            ".github/scripts/build.sh",
            ".github/workflows/build.yml",
            ".github/workflows/build-steps.yml",
            ".github/workflows/deb-repo.yml",
            ".github/bump-hook.sh",
        )
        for relative in paths:
            self.assert_not_contains(
                relative,
                "Build Helium",
                "Package Helium",
                "Label: Helium",
                "Description: Helium",
                "release/helium-",
                "build/release/helium-",
                "package/helium-bin.spec",
                "net.imput.helium.metainfo.xml",
            )
        self.assert_contains(".github/scripts/build.sh", "${_out_dir}/jobrowsa")
        self.assert_contains(
            ".github/actions/package/action.yml",
            "jobrowsa-${{ steps.version.outputs.version }}-${{ env.ARCH }}-AppImage",
            "jobrowsa-bin_${{ steps.version.outputs.version }}-1_*.deb",
        )
        self.assert_contains(
            ".github/actions/release/action.yml",
            "pattern: jobrowsa-*-AppImage",
            "release/jobrowsa-*.AppImage",
            "release/jobrowsa-bin_*.deb",
            "### jobrowsa-linux",
            "### helium-chromium",
        )
        self.assert_contains(".github/bump-hook.sh", "package/jobrowsa-bin.spec")
        self.assert_contains(
            ".github/ISSUE_TEMPLATE/bug-report.yml",
            "helium://settings/help",
        )

    def test_release_scripts_use_jobrowsa_identity(self) -> None:
        self.assert_contains(
            "scripts/package.sh",
            '_app_dir="$_release_dir/Jobrowsa.AppDir"',
            '_app_name="jobrowsa"',
            "jobrowsa_crashpad_handler",
            "package/jobrowsa.desktop",
            "package/jobrowsa-wrapper.sh",
            '"$_tarball_dir/jobrowsa-wrapper"',
            "ln -sf jobrowsa chrome",
            "opt/jobrowsa/",
            "package/jobrowsa-wrapper-appimage.sh",
            'APPIMAGETOOL_APP_NAME="Jobrowsa"',
        )
        self.assert_not_contains(
            "scripts/package.sh",
            "gh-releases-zsync|imputnet|helium-linux",
            "_update_info",
            "opt/helium",
        )
        self.assert_contains(
            "scripts/dev.sh",
            "./out/Default/jobrowsa",
            "$HOME/.config/jobrowsa.dev",
        )
        self.assert_contains(
            "package/docker-package.sh", '_image="jobrowsa-trixie-slim:packager"'
        )

    def test_name_substitution_replaces_chrome_with_jobrowsa(self) -> None:
        utils = read("helium-chromium/utils/name_substitution_utils.py")
        self.assertIn('r"Jobrowsa"', utils, "utils must map to Jobrowsa")
        self.assertIn('r"\\1helium://"', utils, "scheme mapping must stay helium://")
        self.assertNotIn(
            "r'Jobrowsa'",
            utils,
            "file uses double quotes (autoformatted), not single",
        )
        sanity = read("helium-chromium/utils/name_substitution.py")
        self.assertIn('" Jobrowsa  "', sanity)
        self.assertIn('("Google Chrome", "Jobrowsa")', sanity)
        self.assertIn(
            '("Chrome Google Chrome Chrome Chromium", "Jobrowsa Jobrowsa Jobrowsa Jobrowsa")',
            sanity,
        )
        self.assertIn('("Chrome", "Jobrowsa")', sanity)
        self.assertIn('("Chromium", "Jobrowsa")', sanity)


if __name__ == "__main__":
    unittest.main()
