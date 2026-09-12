# Kvil release candidate

Checked 13 September 2026. Version 1.0.0, archive build 2446.23.21, Xcode 27 RC (27A266a). This is a prepared release candidate, not a submitted or approved App Store release.

## Completed

- The native iPhone app, Watch companion, widgets, original landscape art, English/Norwegian localization, optional weight and Health integration, schedule-only iCloud integration, local-history recovery, and non-consumable purchase flow are implemented. Product and architecture decisions are in `MVP_PLAN.md`.
- The complete Xcode 27 RC run passed 36 tests. The small iPhone run passed 35, then the remaining reflection flow passed after correcting an offscreen tap in the test. The final bilingual screenshot/purchase flows and the accessibility audit after localization cleanup passed separately. All 191 English/Norwegian strings validate. `test-results.json` retains the exact result references and distinguishes the failed run from its successful focused rerun.
- Schedule boundary/DST/overnight calculations, invalid imports, transactional persistence, cloud merges and resets, Health retry/deletion reconciliation, StoreKit pending approval/refund/restoration, optional weight, and accessibility layouts have focused coverage. StoreKit and Health reconciliation tests use controlled local fixtures, not a live purchase or the user's Health data.
- The small and large iPhone layouts and a 42-mm Watch layout were visually inspected. Small and medium Home Screen widgets rendered through Xcode's system widget host with a persisted sample schedule. The Watch timer continued from its local sample snapshot after restart without a paired phone. This does not prove WatchConnectivity delivery.
- The release archive exported successfully to `build/AppStore/KvilApp.ipa`. `archive-verified.json` records its SHA-256 and all four verified distribution signatures/profiles, matching versions, OS 27 minimums, English/Norwegian resources, privacy manifests, and absence of local StoreKit/debug resources. Run `python3 scripts/verify-release.py` to repeat this check without uploading.
- The latest development-signed Release build installed on the developer iPhone; an earlier RC build launched successfully. Installation, launch, and actual Health/Watch behavior are separate checks. The latest remote launch was refused because the phone is locked; no unlock was attempted.
- App Store Connect contains the English/Norwegian draft copy, Health & Fitness category, adult age rating, free app price, and a US $3.99 non-consumable purchase with localized descriptions. Availability is configured in 175 territories. Version release is manual.
- The user's App Review contact is saved, with sign-in disabled and review notes saved/read back. The phone number is intentionally absent from the repository. `review-detail-verified.json` records presence only.
- Native screenshots are prepared under `screenshots/`, including both Watch localizations and the purchase review image. Their dimensions and hashes are recorded in `screenshots/manifest.json`.
- Static support/privacy pages are prepared under `site/dist/`, with no analytics, external fonts, scripts, forms, or dependencies. Local routes and assets respond successfully. The App Privacy questionnaire has a saved “Data Not Collected” draft.

## Remaining before App Review

| Check | Current state and next action |
| --- | --- |
| Public support and privacy pages | Prepared locally; publish to a public HTTPS host and save/read back both URLs in App Store Connect. |
| Apple build and media upload | IPA and screenshots are prepared. Upload, wait for processing, attach the build, attach the purchase review image, and associate the first purchase with version 1.0.0. No upload has occurred. |
| Live StoreKit product | Local StoreKit tests pass. Check product loading, purchase, and restore from the processed TestFlight build using Apple's sandbox. |
| Lock Screen widgets and Watch complications | Implemented and compiled; actual accessory-host layouts remain unverified. Device Hub repeatedly timed out through computer controls, including after reopening it. Add each supported family through the system UI when Device Hub responds or on hardware. |
| Device transport | Verify a schedule edit reaches the paired Watch and a second signed-in iPhone; then check the Watch timer with the phone unavailable. Simulator fixture persistence does not prove this. |
| Health and reminders on hardware | Verify permission denial, optional body-weight read/write with an intentional test entry, and opening/closing notification delivery. Mock reconciliation and simulator UI tests do not replace these checks. |
| App Privacy and final listing | Publish the reviewed privacy answers, verify all listing fields and screenshots, then run App Store validation on the processed build. No App Review submission or public release has occurred. |

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
