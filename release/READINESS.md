# Kvil release readiness

**Current owner decisions (updated 16 September):** iCloud policy clarification is parked unless App Review raises it; two-iPhone testing is deferred because only one iPhone is available; mainland China is excluded; all build uploads and submission are owner-managed. The two Home accessibility checks and all four previously failing Settings/reminder clipping cases now pass. Six focused Settings UI flows passed on 16 September, with final dark-mode captures inspected. [Release decisions](RELEASE_DECISIONS.md).

## Current preparation status: 15 September 2026

**Accessibility follow-up, 16 September:** all four remaining Settings/reminder clipping cases now pass. The final six-flow run passed with zero failures or skips (build `2450.12.39`), covering bilingual/largest-text native audits and Settings control persistence/navigation. Root inspected the actual dark captures and verified the full reminder value and preserved section after font changes. No reports are suppressed. Four pre-existing StoreKit test-setup actor-isolation warnings remain. A subsequent two-case check passed after restoring the accent-colored reminder values and red erase label (build `2450.12.45`); both resulting captures were inspected. The two Home cases passed in the earlier run. [Current follow-up evidence](accessibility-remediation-verified.json).

The old build has been detached from the live draft, content rights corrected, and dark screenshots regenerated locally. The subsequent encrypted private CloudKit migration is integrated. Production schema and the earlier signed export **2449.6.4** are verified. Latest simulator validation passed 132 model tests (one opt-in live test skipped) and both setup flows. The morning checkpoint had six unresolved native accessibility audits: two Home contrast reports and four Settings/reminder clipping reports. No suppression or blanket waiver was added. The earlier unit suite passed all 129 tests; its two Settings UI passes and one targetless ordinary-Norwegian clipping report remain historical checkpoint results, with visually complete captures. Real two-device/APNs migration and recovery checks remain in [CloudKit deployment](CLOUDKIT_DEPLOYMENT.md). [Migration evidence](CLOUDKIT_MIGRATION.md). Encryption does not settle the [App Review policy question](ICLOUD_PRIVACY_FINDINGS.md).

The earlier local signed candidate is **1.0.0 (2449.6.4)**: `build/Kvil-FinalAudit.xcarchive` and `build/AppStore-FinalAudit/KvilApp.ipa`. Its SHA-256 is `82e4a9246d7789791ae0696a244002c4b7bdd3dbee8764087ee6136ecab9ade8`. All four distribution signatures/profiles and matching bundle versions/builds passed verification, including phone CloudKit Production, production APNs, migration KVS access, privacy manifests and absence of Debug resources and QA audit hooks from exported binaries. The binary has **not been uploaded**. Localization validation passed. [Earlier signed artifact](audit-candidate-verified.json).

The weekly setup preview now includes a schedule-sync toggle. It starts on for a fresh installation and can be switched off before saving setup; an existing preference is used when present. The selected preference and new schedule persist together before the new schedule is published. Existing-account restoration or legacy KVS migration may already occur before setup, so this choice does not guarantee that no earlier cloud access occurred. Both ordinary and largest-text setup tests passed after targeting the native switch. Assertions verify its default-on state, switching off and the saved-off choice.

The 05:56:53 UTC App Store Connect readback still reports `PREPARE_FOR_SUBMISSION`, no selected build and no review submission. [Saved Apple state](appstore-materials-verified.json).

The public privacy and support articles now describe encrypted schedule sync, including Home fasting adjustments. Both were published on 15 September and read back from the custom domain; 39 existing portfolio pages/assets remained unchanged. [Publication evidence](privacy-site-verified.json). The English/Norwegian descriptions, keywords, promotional text and review notes are saved in App Store Connect and match all requested fields exactly. Ten storefront screenshots and the separate purchase review image are uploaded, processed as `COMPLETE`, and checksum/dimension verified. The fictional `Kvil-reviewer-demo.zip` is attached and named in the final review notes. [App Store material evidence](appstore-materials-verified.json). The new app binary has not been uploaded. [App Review remediation](APP_REVIEW_REMEDIATION.md) is the current checklist.

A separate native CloudKit integration test passed on one physical iPhone, build `2449.4.42`, using two independent clients and fictional data in a dedicated QA zone. Encrypted round trips, real server conflicts, reset tombstones, cancellation before submission, zone recreation and cleanup passed. This is one physical test, separate from the 129 earlier unit tests. Two-phone convergence, Production/TestFlight runtime, actual background APNs, account/keychain changes and real legacy-KVS migration remain unverified. [Physical evidence](cloudkit-physical-verified.json).

Mac and Vision Pro availability are now disabled and were read back after saving and reloading App Store Connect; territories were unchanged. [Platform evidence](platform-availability-verified.json). The owner confirmed Kvil is a personal hobby project, so the existing non-trader declaration was retained on that stated basis. This records the owner's facts without guaranteeing the legal classification. Mainland China is now excluded from the app and purchase; [readback](china-availability-verified.json) confirms all other territories are unchanged.

Compact Home geometry assertions now pass. Saved-off setup state is established by assertions; the largest-text retained-state capture shows adjacent Settings rows. Earlier physical notification-banner interference is separate from the final simulator failures. [Accessibility evidence](accessibility-verified.json).

## Historical readiness record: 13 September 2026

The sections below retain the original build, website, and validation evidence from that checkpoint. References there to current materials, KVS, or pending changes describe the 13 September state, not the new CloudKit candidate.

Updated 13 September 2026. The current working tree and live website include visual changes made after the last Apple upload. This is not a submitted or approved App Store release.

## Current visual revision

- The app's shared Landscape asset and all website landscape placements now use Kayvan Mazhar's licensed Rice Lake photograph. The old day/night landscape files are removed. Home, onboarding, the History empty state, Settings About, purchase artwork, and the medium Home Screen widget share the native asset. Both appearances use the same photograph with existing semantic fades.
- Three focused UI tests passed: release captures, open-window/Norwegian layouts, and Home accessibility. Home, onboarding, and purchase captures were visually inspected; Home and onboarding also passed visual inspection on the smaller phone in dark mode. Existing StoreKitTest deprecation and XCTest actor-isolation warnings remain. The medium widget's new image is compiled through the shared asset but was not recaptured in its system host.
- Seven iPhone screenshots and the purchase review capture are refreshed locally. The Watch screenshots are unchanged. `screenshots/manifest.json` records the current files; `photography-verified.json` records this revision's checks and live website deployment.
- The website is published from the complete portfolio export, including the updated phone image, social preview, bilingual project copy, and photographer credits. Content-hashed stylesheet and phone-image URLs refresh browser caches.
- The recent source changes are uncommitted. They are not included in archive build 2446.23.21 or its Apple screenshots. Before App Review, archive the final working tree, upload and attach the new build, replace the eight updated Apple images, and apply the current English/Norwegian listing and review-note payloads.
- The photo is third-party content used under the Unsplash License. `requests/content-rights.json` prepares `USES_THIRD_PARTY_CONTENT` for the next candidate. The older Apple checkpoint still records `DOES_NOT_USE_THIRD_PARTY_CONTENT`; update and read back that declaration with the new candidate. The source and license are documented in `../design/photography/README.md`.

## Apple checkpoint before the visual revision

Version 1.0.0, archive build 2446.23.21, Xcode 27 RC (27A266a). At the checkpoint, the App Store version and Full History purchase were in one READY_FOR_REVIEW draft. The records below describe that earlier build and upload, not the current working tree or screenshot manifest.

- The native iPhone app, Watch companion, widgets, original landscape art, English/Norwegian localization, optional weight and Health integration, schedule-only iCloud integration, local-history recovery, and non-consumable purchase flow were implemented. Product and architecture decisions are in `MVP_PLAN.md`.
- The complete Xcode 27 RC run passed 36 tests. The small iPhone run passed 35, then the remaining reflection flow passed after correcting an offscreen tap in the test. The final bilingual screenshot/purchase flows and the accessibility audit after localization cleanup passed separately. All 191 English/Norwegian strings validate. `test-results.json` retains the exact result references and distinguishes the failed run from its successful focused rerun.
- Schedule boundary/DST/overnight calculations, invalid imports, transactional persistence, cloud merges and resets, Health retry/deletion reconciliation, StoreKit pending approval/refund/restoration, optional weight, and accessibility layouts have focused coverage. StoreKit and Health reconciliation tests use controlled local fixtures, not a live purchase or the user's Health data.
- The small and large iPhone layouts and a 42-mm Watch layout were visually inspected. Small and medium Home Screen widgets rendered through Xcode's system widget host with a persisted sample schedule. The Watch timer continued from its local sample snapshot after restart without a paired phone. This does not prove WatchConnectivity delivery.
- The release archive exported successfully to `build/AppStore/KvilApp.ipa`. `archive-verified.json` records its SHA-256 and all four verified distribution signatures/profiles, matching versions, OS 27 minimums, English/Norwegian resources, privacy manifests, and absence of local StoreKit/debug resources. Run `python3 scripts/verify-release.py` to repeat this check without uploading.
- The latest development-signed Release build installed on the developer iPhone; an earlier RC build launched successfully. Installation, launch, and actual Health/Watch behavior are separate checks. The latest remote launch was refused because the phone is locked; no unlock was attempted.
- App Store Connect contains the English/Norwegian draft copy, Health & Fitness category, adult age rating, free app price, and a US $3.99 non-consumable purchase with localized descriptions. Availability is configured in 175 territories. Version release is manual.
- The user's App Review contact is saved, with sign-in disabled and review notes saved/read back. The phone number is intentionally absent from the repository. `review-detail-verified.json` records presence only.
- All ten native screenshots are uploaded and processed as COMPLETE, with matching Apple checksums: seven iPhone screenshots, two Watch screenshots, and the purchase review image. `apple-media-verified.json` records delivery proof. Full History is included in the version’s review draft.
- Kvil is live at https://hkarlsen06.dev/kvil/ with separate support and privacy pages. Both English and Norwegian portfolio listings include Kvil. Production build and TypeScript checks pass; desktop and small-phone layouts were visually inspected. Live routes/assets and the preserved Tidex artwork were verified in `website-verified.json`. The authored pages contain no scripts; the existing host adds Cloudflare email protection.
- Apple accepted build 2446.23.21, finished processing it as VALID, and reports READY_FOR_BETA_TESTING for internal TestFlight. The build is attached to version 1.0.0. English/Norwegian beta metadata is saved. `apple-upload-verified.json` verifies the build and both locales’ marketing, support, and privacy URLs. No testers were invited.
- Source and release materials are pushed to the private GitHub repository https://github.com/hkarlsen06/kvil. Website changes are committed and pushed separately to hkarlsen06/hkarlsen06.dev.
- Content rights is saved as DOES_NOT_USE_THIRD_PARTY_CONTENT. App Information confirms Kvil is not a regulated medical device in any country or region.
- The user accepted Apple’s privacy declaration and published “Data Not Collected”. App Store Connect publication was verified on 13 September 2026.
- Apple’s listing validation passes. Draft `a4c0f5cf-b652-42b2-b2d1-adb9a35dc0a1` contains iOS 1.0.0 (2446.23.21) and Kvil Full History, both READY_FOR_REVIEW. The UI displays “Items Ready to Submit (2)”; the API reports a null submittedDate. `apple-review-draft-verified.json` records the readback.

## Remaining before App Review

| Check | Current state and next action |
| --- | --- |
| Current visual revision | Create and validate a new archive, replace the previous Apple build and eight images, and update the listing, review notes, and third-party content declaration. The local screenshot manifest and metadata now describe the new photograph. |
| Live StoreKit product | Local StoreKit tests pass. Check product loading, purchase, and restore from the processed TestFlight build using Apple's sandbox. |
| Lock Screen widgets and Watch complications | Implemented and compiled; actual accessory-host layouts remain unverified. Device Hub repeatedly timed out through computer controls, including after reopening it. Add each supported family through the system UI when Device Hub responds or on hardware. |
| Device transport | Verify a schedule edit reaches the paired Watch and a second signed-in iPhone; then check the Watch timer with the phone unavailable. Simulator fixture persistence does not prove this. |
| Health and reminders on hardware | Verify permission denial, optional body-weight read/write with an intentional test entry, and opening/closing notification delivery. Mock reconciliation and simulator UI tests do not replace these checks. |

Only planned schedule preferences sync through iCloud. Reflection and weight records are excluded. Apple has not issued an app-specific determination about whether these planned times fall under its health-data iCloud restriction; review notes describe the payload explicitly.

## Device check sequence

1. Open Kvil, set a weekly window, and change only today. Check the phone and both Home Screen widget sizes.
2. Add the circular, rectangular, and inline Lock Screen widgets. Check countdown and open-window presentation, including long Norwegian text. Tap each to open Kvil.
3. Open the Watch app and add circular/rectangular complications. Change today's schedule on the phone, wait for delivery, then separate the devices and confirm the Watch keeps the received schedule.
4. Enable opening/closing reminders and check the displayed queue horizon. Check denied notification permission separately.
5. With the owner's consent, enable Health reads and optional writes. Use an intentional test measurement; verify its value and one-time identity in Health, then remove it through the app. Do not use or export unrelated Health records for QA.
6. On a second iPhone signed into the same iCloud account, enable schedule sync, test a change and a reset, and confirm reflection/weight records do not follow that channel.
7. In TestFlight, purchase and restore Full History. Confirm older reflections unlock and that core features remain free.

The protected local database is excluded from automatic backup; Settings provides free export/import. Verify a backup round trip before using real history as the only copy.

Archive, Apple upload, store-draft, and Apple media JSON files are historical checkpoints for build 2446.23.21 and its earlier screenshots. The current website and local photo revision are recorded in `photography-verified.json`; no new Apple upload is claimed by that file.
