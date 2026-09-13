# Kvil release candidate

Checked 13 September 2026. Version 1.0.0, archive build 2446.23.21, Xcode 27 RC (27A266a). The App Store version and Full History purchase are in one READY_FOR_REVIEW draft. This is a prepared release candidate, not a submitted or approved App Store release.

## Completed

- The native iPhone app, Watch companion, widgets, original landscape art, English/Norwegian localization, optional weight and Health integration, schedule-only iCloud integration, local-history recovery, and non-consumable purchase flow are implemented. Product and architecture decisions are in `MVP_PLAN.md`.
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

Archive and initial store-draft JSON files are historical checkpoints. Current network upload and website state are recorded in the newer `apple-upload-verified.json`, `apple-media-verified.json`, and `website-verified.json` files.
