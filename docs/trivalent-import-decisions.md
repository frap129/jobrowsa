# Trivalent Import Decisions

Dispositions for the Trivalent/Vanadium patch import (spec
`.opencode/plans/02-trivalent-patch-import.md`, decisions D1-D6, as amended by
the 2026-08-13 mergability directive).

## Snapshot

- Upstream: https://github.com/secureblue/Trivalent, branch `live`
- Pinned commit: cdcf6f1a1eafa6cd18fffacc635f846f212d5f08 (fetched 2026-08-13)
- Chromium pin: 151.0.7922.137
- Upstream licenses: Apache-2.0 and GPL-2.0 notices carried inside the patch
  files; upstream `LICENSE*` files are not vendored (the patch-tree lint
  requires every file under `patches/` to be a series entry).

## Policy deviations from the spec

- D3/D4 amended by maintainer directive (2026-08-13): the existing Helium,
  ungoogled, inox, iridium, brave, bromite, debian, and upstream-fixes patches
  are never modified. Vanadium/Trivalent patches are vendored into this
  repository's `patches/` tree and apply after the shared Helium series.
  Vendored patches that do not apply cleanly are replaced with adapted
  versions (manifest disposition `adapted`) or dropped; new bridging behavior
  is expressed as new patches under `patches/helium/linux/`.
- Build pipeline unchanged (`scripts/shared.sh`, `scripts/build.sh`,
  `scripts/docker-build.sh`, `helium-chromium/utils/patches.py`).
- GN args exempt from the no-modification rule: `helium-chromium/flags.gn`
  and `flags.linux.gn` are editable (trivially mergable).

## Patch dispositions

| Upstream path | Disposition | Reason |
|---|---|---|
| patches/third_party/vanadium/0067-disable-navigation-error-correction-by-default.patch | dropped | change already applied by shared inox-patchset/modify-default-prefs.patch (kAlternateErrorPagesEnabled=false) |
| patches/third_party/vanadium/0069-disable-network-prediction-by-default.patch | dropped | change already applied by shared inox-patchset/modify-default-prefs.patch (NetworkPredictionOptions::kDefault=kDisabled) |
| patches/third_party/vanadium/0071-disable-hyperlink-auditing-by-default.patch | dropped | change already applied by shared inox-patchset/modify-default-prefs.patch (kEnableHyperlinkAuditing=false) |
| patches/third_party/vanadium/0072-disable-showing-popular-sites-by-default.patch | pristine | vendored unmodified from pinned snapshot |
| patches/third_party/vanadium/0073-disable-article-suggestions-feature-by-default.patch | pristine | vendored unmodified from pinned snapshot |
| patches/third_party/vanadium/0074-disable-content-feed-suggestions-by-default.patch | pristine | vendored unmodified from pinned snapshot |
| patches/third_party/vanadium/0075-disable-sensors-access-by-default.patch | pristine | vendored unmodified from pinned snapshot |
| patches/third_party/vanadium/0077-disable-third-party-cookies-by-default.patch | dropped | change already applied by shared inox-patchset/modify-default-prefs.patch (kCookieControlsMode=kBlockThirdParty) |
| patches/third_party/vanadium/0078-disable-background-sync-by-default.patch | pristine | vendored unmodified from pinned snapshot |
| patches/third_party/vanadium/0079-disable-payment-support-by-default.patch | dropped | change already applied by shared inox-patchset/modify-default-prefs.patch (kCanMakePaymentEnabled=false) |
| patches/third_party/vanadium/0080-disable-media-router-media-remoting-by-default.patch | pristine | vendored unmodified from pinned snapshot |
| patches/third_party/vanadium/0081-disable-media-router-by-default.patch | pristine | vendored unmodified from pinned snapshot |
| patches/third_party/vanadium/0083-disable-browser-sign-in-feature-by-default.patch | dropped | sign-in prefs registrations removed entirely by shared ungoogled-chromium/remove-unused-preferences-fields.patch; sign-in disabled without registration |
| patches/third_party/vanadium/0084-disable-safe-browsing-reporting-opt-in-by-default.patch | dropped | target file pruned by build pipeline (helium-chromium/pruning.list); safe browsing is removed from this build |
| patches/third_party/vanadium/0085-disable-unused-safe-browsing-option-by-default.patch | dropped | target file pruned by build pipeline (helium-chromium/pruning.list); safe browsing is removed from this build |
| patches/third_party/vanadium/0086-disable-media-DRM-preprovisioning-by-default.patch | pristine | vendored unmodified from pinned snapshot |
| patches/third_party/vanadium/0087-disable-autofill-server-communication-by-default.patch | pristine | vendored unmodified from pinned snapshot |
| patches/third_party/vanadium/0088-disable-component-updater-pings-by-default.patch | pristine | vendored unmodified from pinned snapshot |
| patches/third_party/vanadium/0090-disable-trivial-subdomain-hiding.patch | pristine | vendored unmodified from pinned snapshot |
| patches/third_party/vanadium/0093-disable-GaiaAuthFetcher-code-due-to-upstream-bug.patch | dropped | GaiaAuthFetcher::CreateAndStartGaiaFetcher body already removed by shared ungoogled-chromium/disable-gaia.patch (same intent, stronger) |
| patches/third_party/vanadium/0095-Disable-newer-privacy-sandbox-features-by-default.patch | adapted | kBrowsingTopics hunk in services/network/public/cpp/features.cc removed (already disabled by shared helium/core/disable-ad-topics-and-etc.patch); remaining hunks rebased onto Chromium 151 context |
| patches/third_party/vanadium/0099-mark-non-secure-origins-as-dangerous.patch | pristine | vendored unmodified from pinned snapshot |
| patches/third_party/vanadium/0101-stub-out-the-battery-status-API.patch | pristine | vendored unmodified from pinned snapshot |
| patches/third_party/vanadium/0104-disable-trials-of-privacy-aware-analytics-advertisin.patch | pristine | vendored unmodified from pinned snapshot |
| patches/third_party/vanadium/0106-disable-appending-variations-header.patch | dropped | change already applied by shared ungoogled-chromium/disable-google-host-detection.patch (variations header removed) |
| patches/third_party/vanadium/0107-Disable-detailed-language-settings-by-default.patch | pristine | vendored unmodified from pinned snapshot |
| patches/third_party/vanadium/0108-disable-fetching-optimization-guides-by-default.patch | pristine | vendored unmodified from pinned snapshot |
| patches/third_party/vanadium/0110-disable-fetching-optimization-hints-by-default.patch | pristine | vendored unmodified from pinned snapshot |
| patches/third_party/vanadium/0111-disable-more-optimization-guides-features-by-default.patch | pristine | vendored unmodified from pinned snapshot |
| patches/third_party/vanadium/0117-require-HTTPS-for-component-updates.patch | pristine | vendored unmodified from pinned snapshot |
| patches/third_party/vanadium/0120-enable-split-cache-by-default.patch | pristine | vendored unmodified from pinned snapshot |
| patches/third_party/vanadium/0121-enable-partitioning-connections-by-default.patch | pristine | vendored unmodified from pinned snapshot |
| patches/third_party/vanadium/0122-enable-dubious-Do-Not-Track-feature-by-default.patch | adapted | rebased onto Chromium 151 context (hunk offset due to helium/core/network/global-privacy-control-pref.patch additions) |
| patches/third_party/vanadium/0124-Enable-strict-origin-isolation-by-default.patch | pristine | vendored unmodified from pinned snapshot |
| patches/third_party/vanadium/0125-Enable-reduce-accept-language-header-by-default.patch | dropped | change already applied by shared helium/core/reduce-accept-language-headers.patch (kReduceAcceptLanguage enabled) |
| patches/third_party/vanadium/0126-use-Google-Chrome-branding-for-client-hints.patch | dropped | Google Chrome UA brand already hardcoded by shared helium/core/spoof-chrome-ua-brand.patch (anchor lines removed) |
| patches/third_party/vanadium/0160-Derive-high-entropy-client-hints-with-reduced-user-a.patch | pristine | vendored unmodified from pinned snapshot |
| patches/third_party/vanadium/0165-Use-local-list-of-supported-languages-for-Language-s.patch | pristine | vendored unmodified from pinned snapshot |
| patches/third_party/vanadium/0201-enable-subresource-filter-on-all-sites.patch | pristine | vendored unmodified from pinned snapshot |
| patches/third_party/vanadium/0228-Support-restriction-of-dynamic-code.patch | pristine | vendored unmodified from pinned snapshot |
| patches/third_party/vanadium/0229-Restriction-of-dynamic-code-execution-via-seccomp-bp.patch | pristine | vendored unmodified from pinned snapshot |
| patches/third_party/vanadium/0233-Enable-HSTS-upgrades-for-top-level-navigation-only-b.patch | pristine | vendored unmodified from pinned snapshot |
| patches/third_party/vanadium/0243-Further-disable-password-leak-detection-checks.patch | dropped | leak detection already disabled (CanStartLeakCheck stubbed to return false) by shared ungoogled-chromium/remove-unused-preferences-fields.patch |
| patches/third_party/vanadium/0244-enable-certificate-transparency-feature-by-default-f.patch | dropped | CT already enabled by default via shared ungoogled-chromium/enable-certificate-transparency-and-add-flag.patch (#if true) |
| patches/third_party/vanadium/0245-enable-more-Local-Network-Access-coverage-checks-by-.patch | pristine | vendored unmodified from pinned snapshot |
| patches/third_party/vanadium/0250-Enable-origin-keyed-process-isolation-by-default.patch | pristine | vendored unmodified from pinned snapshot |
| patches/third_party/vanadium/modified-block-playing-protected-media-by-default.patch | adapted | rebased onto Chromium 151 context (registration moved; upstream added ContentSettingsInfo::INHERIT_IF_LESS_PERMISSIVE line) |
| patches/third_party/vanadium/modified-disable-seed-based-field-trials.patch | adapted | rebased onto Chromium 151 (include-context drift in variations_field_trial_creator.cc and synthetic_trial_registry.cc; BUILD.gn hunks re-anchored inside target scopes) |
| patches/trivalent/add-dark-mode-toolbar-toggle.patch | adapted | ListActions hunk re-anchored onto Chromium 151 context (kActionNewIncognitoWindow added and category groups re-sorted upstream); remaining hunks applied with line offsets |
| patches/trivalent/add-feature-to-toggle-middlemouse-copypaste.patch | adapted | views_features cc/h hunks re-anchored: kAllowWindowCaptureExclusionInRemoteSessions now leads the alphabetized feature list, so kMiddleClickCopyPaste moved to its alphabetical position |
| patches/trivalent/add-hide-profile-icon-feature.patch | adapted | toolbar_view.cc hunk re-anchored onto Chromium 151 context: show-avatar-button command-line switch block now precedes SetVisible, so the feature check moved to just before SetVisible to preserve its last-word semantics |
| patches/trivalent/add-incognito-prefs.patch | pristine | vendored unmodified from pinned snapshot |
| patches/trivalent/dark-mode-skip-images-by-default.patch | pristine | vendored unmodified from pinned snapshot |
| patches/trivalent/disable-background-mode-by-default.patch | dropped | change already applied by shared inox-patchset/modify-default-prefs.patch (kBackgroundModeEnabled=false); patch is reversed and cannot apply |
| patches/trivalent/disable-disk-cache.patch | pristine | vendored unmodified from pinned snapshot |
| patches/trivalent/disable-infobar-for-builds-without-api-key.patch | dropped | change already applied by shared debian/disable-google-api-warning.patch (same Google API key infobar removal) |
| patches/trivalent/disable-secondary-browser-features-by-default.patch | adapted | kTabHoverCardImages hunk rebased onto Chromium 151 single-line form (IS_MAC block removed upstream); history_clusters/core/features.cc hunk removed as already applied by shared helium/core/disable-history-clusters.patch |
| patches/trivalent/disable-variations.patch | adapted | IsFetchingEnabled hunk dropped (already applied by shared bromite/disable-fetching-field-trials.patch); policy-restriction hunks retained with regenerated offsets |
| patches/trivalent/dns-providers.patch | adapted | shared helium/core/network/dns-providers.patch already applies the CleanBrowsing/Cloudflare/DNS4EU/OpenDNS/NextDNS changes (with minor textual deviations); retained deltas: ControlD provider entries added and Google/Quad9Secure display_globally set to false |
| patches/trivalent/enable-parallel-downloading-by-default.patch | dropped | change already applied by shared helium/core/enable-parallel-downloading.patch (platform block collapsed, kParallelDownloading enabled) |
| patches/trivalent/enable-vertical-tabs-exposure.patch | dropped | change already applied by shared helium/ui/layout/core.patch (kVerticalTabs enabled by default) |
| patches/trivalent/expose-flags.patch | adapted | hunk re-anchored onto Chromium 151/Helium kFeatureEntries structure (entries now precede the include-based flag headers); middle-click-autoscroll entry dropped (Helium already exposes the identical flag name via blink::features::kHeliumMiddleClickAutoscroll in helium_flag_entries.h, and upstream's blink::features::kMiddleClickAutoscroll does not exist in this tree); audio-service-sandbox entry uses features::kAudioServiceSandbox (content_features.h declares it in the global features namespace) |
| patches/trivalent/force-disable-safe-browsing.patch | adapted | safe_browsing_prefs.cc hunk dropped: target file pruned by build pipeline (helium-chromium/pruning.list); download warning suppression hunk retained |
| patches/trivalent/force-third-party-ntp.patch | adapted | NewTabURLDetails::ForProfile in Chromium 151 no longer branches on the default search provider, so the hunk became a constant swap (kChromeUINewTabPageURL -> kChromeUINewTabPageThirdPartyURL) preserving the forced-third-party-NTP intent |
| patches/trivalent/hide-ui-popup-text.patch | pristine | vendored unmodified from pinned snapshot |
| patches/trivalent/increase-style-filter-limits.patch | pristine | vendored unmodified from pinned snapshot |
| patches/trivalent/privacy/add-cross-origin-referrer-clearing-feature.patch | adapted | feature cc/h hunks re-anchored past Helium features (kHeliumSplitClientHello etc. now lead net/base/features); url_request_job.cc hunk applied unchanged; MaybeTruncateReferrer hunk moved from upstream's early-return branch to the tail of the function (Chromium 151 sanitizes via referrer_sanitizer), with url/origin.h include added; resulting behavior identical: cross-origin referrers are cleared (kDisableCrossOriginReferrers) or trimmed to origin (kCapReferrerToOriginOnCrossOrigin) |
| patches/trivalent/privacy/clear-windowname-property-across-contexts.patch | pristine | vendored unmodified from pinned snapshot |
| patches/trivalent/privacy/disable-ai-features-and-components-by-default.patch | adapted | kStarterPackExpansion hunk dropped (Chromium 151 already defines it DISABLED); contextual_search_service.cc hunk re-anchored (kDriveConsentState context line changed upstream) |
| patches/trivalent/privacy/disable-gcm.patch | dropped | change already applied by shared ungoogled-chromium/disable-gcm.patch (EnsureStarted body stubbed to GCM_DISABLED, stronger than Trivalent's early return) |
| patches/trivalent/privacy/disable-lens.patch | pristine | vendored unmodified from pinned snapshot |
| patches/trivalent/privacy/disable-metrics-reporting.patch | pristine | vendored unmodified from pinned snapshot |
| patches/trivalent/privacy/disable-promotions-by-default.patch | pristine | vendored unmodified from pinned snapshot |
| patches/trivalent/privacy/disable-protected-content.patch | pristine | vendored unmodified from pinned snapshot |
| patches/trivalent/privacy/disable-search-suggest-by-default.patch | adapted | hunk offset regenerated (kIncognitoLaunch/kIncognitoStartup prefs added above by shared patches) |
| patches/trivalent/privacy/disable-sync-by-default.patch | pristine | vendored unmodified from pinned snapshot |
| patches/trivalent/search-config-improvments.patch | adapted | google entry modernization hunk dropped (shared tree already carries a minimal google entry as break_stuff_google); googleweb engine hunk re-anchored after that entry; regional_settings.json hunks applied unchanged |
| patches/trivalent/search-selection.patch | adapted | regional_capabilities_service.cc hunk dropped (shared helium/core/search/force-eu-search-features.patch already stubs CountryIdToProgram to Program::kWaffle, which supersedes commenting out kTaiyaki); remaining hunks applied with offsets |
| patches/trivalent/security/add-feature-to-disable-pdf-javascript.patch | pristine | vendored unmodified from pinned snapshot |
| patches/trivalent/security/add-feature-to-show-puny-code.patch | pristine | vendored unmodified from pinned snapshot |
| patches/trivalent/security/adjust-jit-controls.patch | pristine | vendored unmodified from pinned snapshot |
| patches/trivalent/security/block-external-extensions.patch | pristine | vendored unmodified from pinned snapshot |
| patches/trivalent/security/default-disable-3d-apis.patch | adapted | hunk offset regenerated (Helium prefs above kDisable3DAPIs registration shift context beyond patch's offset tolerance) |
| patches/trivalent/security/disable-autofill-by-default.patch | adapted | kAutofillProfileEnabled/kAutofillCreditCardEnabled hunks dropped (already disabled by shared patches); kAutofillPaymentCvcStorage/kAutofillPaymentCardBenefits hunks retained with regenerated offsets |
| patches/trivalent/security/disable-extensions-by-default.patch | pristine | vendored unmodified from pinned snapshot |
| patches/trivalent/security/disable-gssapi-to-enable-network-service-sandbox.patch | pristine | vendored unmodified from pinned snapshot |
| patches/trivalent/security/disable-password-manager-prompt-by-default.patch | adapted | kCredentialsEnableService/kCredentialsEnableAutosignin hunks dropped (already disabled by shared patches); kPasswordLeakDetectionEnabled default hunk retained with regenerated offset |
| patches/trivalent/security/disable-printing-by-default.patch | pristine | vendored unmodified from pinned snapshot |
| patches/trivalent/security/disable-remote-access-by-default.patch | pristine | vendored unmodified from pinned snapshot |
| patches/trivalent/security/disable-various-content-settings-by-default.patch | pristine | vendored unmodified from pinned snapshot |
| patches/trivalent/security/enable-partitionalloc-advanced-checks.patch | pristine | vendored unmodified from pinned snapshot |
| patches/trivalent/security/enable-strict-extension-verification.patch | pristine | vendored unmodified from pinned snapshot |
| patches/trivalent/security/extension-access-hardening.patch | pristine | vendored unmodified from pinned snapshot |
| patches/trivalent/security/isolate-sandboxed-iframes-by-document.patch | pristine | vendored unmodified from pinned snapshot |
| patches/trivalent/security/network-service-sandbox-config.patch | pristine | vendored unmodified from pinned snapshot |
| patches/trivalent/security/strict-popup-blocking.patch | pristine | vendored unmodified from pinned snapshot |
| patches/trivalent/set-browser-defaults.patch | adapted | translate/text-log/hide-web-store-icon changes already applied by shared patches; retained deltas: WebRTC IP handling to DisableNonProxiedUdp, shared clipboard/click-to-call/user feedback disabled, HTTPS-only mode enabled; download_prefs.cc hunk applied with offset |
| patches/trivalent/set-default-secure-dns-mode-automatic.patch | pristine | vendored unmodified from pinned snapshot |
| patches/trivalent/show-full-urls-by-default.patch | pristine | vendored unmodified from pinned snapshot |
| patches/trivalent/translations/en-GB.patch | pristine | vendored unmodified from pinned snapshot |
| patches/trivalent/ui/add-license-info.patch | adapted | about_page.html.ts restructured in Chromium 151 (aboutProductTitle removed; aboutProductCopyright/aboutProductLicense in separate info-sections), so the attribution blocks were re-anchored inside the copyright info-section |
| patches/trivalent/ui/add-new-prefs.patch | adapted | prefs_util.cc allowlist block re-anchored past Helium entries; appearance_page.html dark-mode toggle re-anchored after the Helium zen-mode blocks (upstream anchor, a theme dropdown, was restructured) |
| patches/trivalent/ui/adjust-prefs-text.patch | adapted | settings_menu.html hunk re-anchored (menu next-item changed from autofill to appearance); incognito_tab.html subtitle removal hunk trimmed to the remaining span (learn-more link already removed by a shared patch); settings_main.html hunk dropped (searchNoResultsHelp removal already applied by shared helium/settings/remove-results-help-link.patch) |
| patches/trivalent/ui/adjust-security-and-privacy-page.patch | adapted | safe browsing section/advanced-title/passwords-leak/advanced-protection hunks already absent (shared helium/settings/network-and-security-page.patch and ungoogled-chromium/remove-uneeded-ui.patch); retained: page title to privacyPageTitle, Hardening section appended after manage-certificates, dropdown import/property/declaration re-anchored in security_page.ts (do_not_track_toggle import added upstream), registerHelpBubble hunk dropped (already absent) |
| patches/trivalent/ui/hide-privacy-intrusive-prefs.patch | adapted | people_page.html and reset_profile_dialog.html.ts sections dropped (sync/google-account/profile rows and sendSettings checkbox default already removed by shared inox/helim patches); settings_ui.cc AI-features hunk dropped (AI section already forced hidden); privacy guide/ad-privacy/glic hunks retained with regenerated offsets |
| patches/trivalent/ui/hide-useless-prefs.patch | adapted | translate_page.html section dropped (already wrapped in <if expr="False"> by a shared patch); privacy_page_index.html section dropped (safety hub already removed by shared patches); v8/live_translate/your_saved_info sections applied unchanged |
| patches/trivalent/ui/register-new-strings.patch | adapted | websiteDarkMode entry re-anchored past Helium appearance entries (appearanceBehaviorPageTitle/behaviorPageTitle added above by shared patches); remaining hunks regenerated with current offsets |
| patches/trivalent/linux/build-hardening.patch | pristine | vendored unmodified from pinned snapshot |
| patches/trivalent/linux/classic-theme-by-default.patch | pristine | vendored unmodified from pinned snapshot |
| patches/trivalent/linux/configure-gpu-features.patch | adapted | all hunks regenerated onto current tree line numbers (shared-series drift put them 40-66 lines off, beyond GNU patch's offset search); kGpuPersistentCache hunk trailing context re-anchored onto kGpuPersistentCacheMetadata (added in Chromium 151); change semantics identical (kGpuPersistentCache always disabled, kDefaultEnableGpuRasterization enabled on Linux, kGpuShaderDiskCache disabled, VAAPI encode enabled where supported, kVaapiOnNvidiaGPUs enabled) |
| patches/trivalent/linux/disable-global-shortcuts-portal.patch | pristine | vendored unmodified from pinned snapshot |
| patches/trivalent/linux/fix-singleton-hostname.patch | pristine | vendored unmodified from pinned snapshot |
| patches/trivalent/linux/linux-gpu-sandbox.patch | pristine | vendored unmodified from pinned snapshot |
| patches/trivalent/fixes/151-fix-dep-definition.patch | dropped | Semantically identical change already applied by shared upstream-fixes/fix-non-git-gclient.patch (same crbug.com/329080012 fix, Change-Id Iea4484f8af4cf9ef25e25ea1df2c616fbe46ed5c). |
| patches/trivalent/fixes/remove-sysroot-dependency.patch | dropped | Workaround for Trivalent's no-sysroot Fedora build (disables libcxx modules, relinks bundled libffi as ffi instead of ffi_pic); we build with use_sysroot=true and phase-01 validated the Chromium defaults |
| patches/trivalent/fixes/use-cwd-for-gclient-path.patch | dropped | Fixes gclient primary-solution detection for Copr/rpmbuild cwds; our flows run gclient from within build/src and phase-01's siso/gclient steps passed |

## Dropped patches

| Patch | Reason |
|---|---|
| patches/third_party/vanadium/0067-disable-navigation-error-correction-by-default.patch | change already applied by shared inox-patchset/modify-default-prefs.patch (kAlternateErrorPagesEnabled=false) |
| patches/third_party/vanadium/0069-disable-network-prediction-by-default.patch | change already applied by shared inox-patchset/modify-default-prefs.patch (NetworkPredictionOptions::kDefault=kDisabled) |
| patches/third_party/vanadium/0071-disable-hyperlink-auditing-by-default.patch | change already applied by shared inox-patchset/modify-default-prefs.patch (kEnableHyperlinkAuditing=false) |
| patches/third_party/vanadium/0077-disable-third-party-cookies-by-default.patch | change already applied by shared inox-patchset/modify-default-prefs.patch (kCookieControlsMode=kBlockThirdParty) |
| patches/third_party/vanadium/0079-disable-payment-support-by-default.patch | change already applied by shared inox-patchset/modify-default-prefs.patch (kCanMakePaymentEnabled=false) |
| patches/third_party/vanadium/0083-disable-browser-sign-in-feature-by-default.patch | sign-in prefs registrations removed entirely by shared ungoogled-chromium/remove-unused-preferences-fields.patch; sign-in disabled without registration |
| patches/third_party/vanadium/0084-disable-safe-browsing-reporting-opt-in-by-default.patch | target file pruned by build pipeline (helium-chromium/pruning.list); safe browsing is removed from this build |
| patches/third_party/vanadium/0085-disable-unused-safe-browsing-option-by-default.patch | target file pruned by build pipeline (helium-chromium/pruning.list); safe browsing is removed from this build |
| patches/third_party/vanadium/0093-disable-GaiaAuthFetcher-code-due-to-upstream-bug.patch | GaiaAuthFetcher::CreateAndStartGaiaFetcher body already removed by shared ungoogled-chromium/disable-gaia.patch (same intent, stronger) |
| patches/third_party/vanadium/0106-disable-appending-variations-header.patch | change already applied by shared ungoogled-chromium/disable-google-host-detection.patch (variations header removed) |
| patches/third_party/vanadium/0125-Enable-reduce-accept-language-header-by-default.patch | change already applied by shared helium/core/reduce-accept-language-headers.patch (kReduceAcceptLanguage enabled) |
| patches/third_party/vanadium/0126-use-Google-Chrome-branding-for-client-hints.patch | Google Chrome UA brand already hardcoded by shared helium/core/spoof-chrome-ua-brand.patch (anchor lines removed) |
| patches/third_party/vanadium/0243-Further-disable-password-leak-detection-checks.patch | leak detection already disabled (CanStartLeakCheck stubbed to return false) by shared ungoogled-chromium/remove-unused-preferences-fields.patch |
| patches/third_party/vanadium/0244-enable-certificate-transparency-feature-by-default-f.patch | CT already enabled by default via shared ungoogled-chromium/enable-certificate-transparency-and-add-flag.patch (#if true) |
| patches/trivalent/disable-background-mode-by-default.patch | change already applied by shared inox-patchset/modify-default-prefs.patch (kBackgroundModeEnabled=false); patch is reversed and cannot apply |
| patches/trivalent/disable-infobar-for-builds-without-api-key.patch | change already applied by shared debian/disable-google-api-warning.patch (same Google API key infobar removal) |
| patches/trivalent/enable-parallel-downloading-by-default.patch | change already applied by shared helium/core/enable-parallel-downloading.patch (platform block collapsed, kParallelDownloading enabled) |
| patches/trivalent/enable-vertical-tabs-exposure.patch | change already applied by shared helium/ui/layout/core.patch (kVerticalTabs enabled by default) |
| patches/trivalent/privacy/disable-gcm.patch | change already applied by shared ungoogled-chromium/disable-gcm.patch (EnsureStarted body stubbed to GCM_DISABLED, stronger than Trivalent's early return) |
| patches/trivalent/fixes/remove-sysroot-dependency.patch | Workaround for Trivalent's no-sysroot Fedora build (disables libcxx modules, relinks bundled libffi as ffi instead of ffi_pic); we build with use_sysroot=true and phase-01 validated the Chromium defaults |
| patches/trivalent/fixes/151-fix-dep-definition.patch | Semantically identical change already applied by shared upstream-fixes/fix-non-git-gclient.patch (same crbug.com/329080012 fix, Change-Id Iea4484f8af4cf9ef25e25ea1df2c616fbe46ed5c). |
| patches/trivalent/fixes/use-cwd-for-gclient-path.patch | Fixes gclient primary-solution detection for Copr/rpmbuild cwds; our flows run gclient from within build/src and phase-01's siso/gclient steps passed |


## GN arguments

### Adopted

| Arg | Value | File | Rationale |
|---|---|---|---|

### Skipped

| Arg | Reason |
|---|---|

### Already present

| Arg | Value |
|---|---|

## Validation

(Recorded in Task 7.)
