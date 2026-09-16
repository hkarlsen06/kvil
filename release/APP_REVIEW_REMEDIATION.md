# App Review remediation

**Current owner decisions (updated 16 September):** iCloud policy clarification is parked unless App Review raises it; two-iPhone testing is deferred because only one iPhone is available; mainland China is excluded; all build uploads and submission are owner-managed. The two Home accessibility checks and all four previously failing Settings/reminder clipping cases now pass. Six focused Settings UI flows passed on 16 September, with final dark-mode captures inspected. [Release decisions](RELEASE_DECISIONS.md).

15 September 2026. Follow-up to [the original audit](APP_REVIEW_AUDIT.md). The public privacy/support articles, App Store listing/reviewer text, ten storefront screenshots and purchase review image are updated and verified. The fictional reviewer backup ZIP is also attached and verified. The new app binary has not been uploaded, and no review submission was sent.

## Completed

- **Old build detached live:** removed app version 1.0.0 from the unsubmitted review draft, detached build `2446.23.21`, saved and reloaded. The version now shows **Prepare for Submission** and **Add Build**. The purchase remains in the draft; the old uploaded binary remains in the account. [Readback record](obsolete-build-detached.json).
- **Mac and Vision Pro distribution disabled:** both availability checkboxes were cleared, saved and checked again after a full App Store Connect reload. Territories were unchanged. [Platform readback](platform-availability-verified.json).
- **Content rights corrected live:** App Information now declares third-party content with the necessary rights, reflecting the licensed photograph. Saved and reloaded. [Readback record](content-rights-corrected.json).
- **Eleven dark screenshots delivered:** four iPhone screens and one Watch screen in each language, plus the English purchase review screen. All are unmodified native captures, visually inspected, with dimensions and SHA-256 verified. Apple reports all eleven `COMPLETE`; checksums, sizes, storefront order and the purchase image relationship match. [Screenshots and capture evidence](screenshots/README.md), [delivery evidence](appstore-materials-verified.json).
- **Phone privacy manifest fixed:** UserDefaults reason `CA92.1` is declared and verified inside the Release simulator app. The release verifier now checks this declaration in an exported app.
- **Backup/sync validation fixed:** duplicate schedule-version UUIDs are rejected before persistence or merging, preventing SwiftData from collapsing two versions. Regression coverage verifies rejection without replacing existing data, including reopening the store.
- **Restore respects sync choice:** importing a backup preserves the destination device's existing cloud-sync preference. Tests cover both incoming values against both destination values. The default remains enabled; the later transport migration is described below.
- **Layout improvements:** restored Home landscape space on the compact phone, separated the chart unit from its top axis value at largest text, and made the Watch canvas fill its viewport in both languages.
- **Reflection test repaired:** its scroll gesture had activated the wrong answer. It now verifies changed-day → meal times → feeling → save at largest text. Production reflection progression was already correct.
- **Release text saved live:** English/Norwegian descriptions, keywords and promotional text, plus review notes and the no-demo-account flag, match the requested fields exactly in saved App Store Connect readbacks. They describe current setup, Home actions/undo, days off, Health authorization and integrations. The [fictional reviewer fixture](reviewer-demo-README.md) is attached as `Kvil-reviewer-demo.zip` and named in the saved review notes. It enables review of older history without waiting weeks and grants no entitlement.

## Settings clipping resolved, 16 September

All six focused Settings UI flows passed (build `2450.12.39`, zero failures or skips). They cover all four previously failing clipping cases plus reminder/Live Activities persistence and weight/sync/navigation behavior. Settings now lays out its existing sections in a regular grouped scroll view, with wrapping reminder values and preservation of the user-visible section when Dynamic Type changes. Native audits have no issue filter or waiver. Final English/Norwegian dark captures were inspected; the largest reminder value remains fully visible and can be changed after the audit. Four pre-existing StoreKit test-setup actor-isolation warnings remain. A subsequent two-case check passed after restoring the accent-colored reminder values and red erase label (build `2450.12.45`); both resulting captures were inspected. Localization validation passed. [Current evidence](accessibility-remediation-verified.json).

## Earlier evening accessibility follow-up

Both Home audit cases now pass with no warnings (build `2449.20.22`). The horizontal time range is one native text element, preserving locale-aware time formatting, overnight labeling and the vertical large-text fallback. English/Norwegian captures were inspected. The final Settings/reminder run (build `2449.21.7`) executed four cases: zero passed, four failed with `Text clipped`, zero skipped and no warnings. All unsuccessful Settings production trials were reverted. A whole-Form identity refresh produced passing audit results but reset the viewport, so that candidate was rejected and reverted. [Follow-up evidence](accessibility-remediation-verified.json).

## Current setup change

The weekly setup preview now includes a schedule-sync toggle. It starts on for a fresh installation and can be switched off before saving setup; an existing preference is used when present. The selected preference and new schedule persist together before the new schedule is published. Existing-account restoration or legacy KVS migration may already occur before setup, so this choice does not guarantee that no earlier cloud access occurred. Both ordinary and largest-text setup tests passed after targeting the native switch. Assertions verify its default-on state, switching off and the saved-off choice.

## Morning simulator checkpoint (06:10 UTC)

At that checkpoint, the production source retained the setup sync choice, its explanatory copy and the single save of preference plus schedule; a 100-point Home landscape reserve at ordinary text sizes; and native `.titleAndIcon` styles on the Watch & widgets and Full History Settings rows. All experimental accessibility range, color and label workarounds were reverted.

| Run | Actual build | Result |
| --- | --- | --- |
| Model test bundle | `2449.5.45` | 132 passed; one opt-in live CloudKit test skipped. The separate physical run already passed. |
| Final setup and Home flows | `2449.5.56` | Ordinary and largest-text setup passed. Both Home tests failed their native contrast audits; the compact landscape geometry assertions passed. |
| Final Settings audits | `2449.6.0` | All four failed with `Text clipped`: CloudKit Settings in English, Norwegian and largest text, plus reminders at largest text. |

The setup tests use the actual native switch and assert default-on, switching off and the saved-off choice. Those assertions establish retained state. The largest-text retained-state screenshot shows adjacent Settings rows and is not visual evidence of the switch value.

At that checkpoint, six native audit reports remained unresolved. No issue filter, suppression or blanket waiver was added. The earlier physical contrast report caused by another app's notification banner is separate from these final simulator failures.

Evidence: [model run](../build/accessibility-final-validation.log), [model test tree](../build/accessibility-final-tests.json), [final setup/Home log](../build/accessibility-final-flows.log), and [final Settings log](../build/accessibility-final-settings.log). The final result bundles are `Kvil-test-1789451760-95014.xcresult` and `Kvil-test-1789452036-96563.xcresult`.

## Encrypted CloudKit implementation

After the fixes above, the user authorized replacing KVS schedule writes with native encrypted fields in the user's private CloudKit database. Local source now targets `iCloud.dev.hkarlsen06.kvil`, zone `Schedule`, record `ScheduleState/current`, encrypted Bytes field `payload`. It retains the full schedule, including Home fasting adjustments and retained plan versions, while reflections and weights stay outside the payload.

The service includes account-owner checks, conditional saves/conflict merging, protected migration state, legacy cleanup after an encrypted save, bounded retries, key-reset recovery, and remote-deletion pauses. Phone entitlements/background configuration and the release verifier cover CloudKit and silent push delivery. The earlier migration checkpoint passed **129 unit tests, including 27 cloud tests**, and two Settings UI checks. One ordinary-Norwegian native clipping audit failed with a `nil` target; the three captures were visually inspected without visible truncation. The failure remains recorded. [Final test evidence](cloudkit-test-results.json).

CloudKit Console confirmed the existing container, created the encrypted field in Development, removed all public grants on `ScheduleState`, and deployed the reviewed diff. Production fields and export preview confirm ENCRYPTED BYTES with no indexes or public grants; `Users` was preserved. [Schema readback](cloudkit-schema-readback.json).

The earlier local signed candidate is **1.0.0 (2449.6.4)**: `build/Kvil-FinalAudit.xcarchive` and `build/AppStore-FinalAudit/KvilApp.ipa`. Its SHA-256 is `82e4a9246d7789791ae0696a244002c4b7bdd3dbee8764087ee6136ecab9ade8`. All four distribution signatures/profiles and matching bundle versions/builds passed verification, including phone CloudKit Production, production APNs, migration KVS access, privacy manifests and absence of Debug resources and QA audit hooks from exported binaries. The binary has **not been uploaded**. Localization validation passed. Latest simulator validation passed 132 model tests (one opt-in live test skipped) and both setup flows. The morning checkpoint had six unresolved native accessibility audits: two Home contrast reports and four Settings/reminder clipping reports. No suppression or blanket waiver was added. [Earlier signed artifact](audit-candidate-verified.json). The earlier `2449.2.47` checkpoint remains preserved in [historical signed export evidence](cloudkit-archive-verified.json). [Accessibility evidence](accessibility-verified.json).

A separate native CloudKit integration test passed on one physical iPhone 17 Pro, build `2449.4.42`. Two independent client instances exercised a dedicated fictional QA zone: encrypted save/fetch, subscription creation, real stale-write conflicts and merged edits, reset tombstones, cancellation before submission, zone deletion/recreation, and cleanup. Only the QA zone/subscription were removed. This is **one physical test**, separate from the 129 earlier unit tests. It does not verify two physical phones, Production/TestFlight records, background APNs, account/keychain changes, or migration of a real legacy KVS record. [Physical evidence](cloudkit-physical-verified.json).

The public privacy/support articles were published on 15 September and verified against the prepared copy on both the custom domain and deployment URL. The complete export preserved the existing portfolio; 39 other pages/assets passed before-and-after checks. [Publication evidence](privacy-site-verified.json). Both listing updates and reviewer notes are saved in App Store Connect with exact requested-field equality; all eleven screenshot assets are uploaded and processed. [App Store material evidence](appstore-materials-verified.json). Real two-device migration/convergence, APNs delivery, and offline/account/key-reset behavior remain outstanding. [Migration report](CLOUDKIT_MIGRATION.md), [runtime checks](CLOUDKIT_DEPLOYMENT.md).

## Validation before the CloudKit migration

The combined latest results for the focused runs contain **102 unit tests passed**, four selected UI tests passed and three selected UI tests failed. This is an aggregation across the initial run and its corrective rerun, not a claim that the full UI suite passed. The separate final bilingual screenshot test passed.

Release simulator build **1.0.0 (2449.2.6) passed**. All four embedded bundles have matching versions/builds and privacy manifests. The phone contains its required UserDefaults reason. No checked Debug scenario markers or StoreKit catalog files occur in these Release bundles. Xcode emitted only signed-binary stripping warnings. This is not a signed App Store archive or physical-device validation.

Evidence:

- `build/app-review-ui-fixes.log` and `build/app-review-ui-fixes-recheck.log`
- `build/app-review-audit/remediation-test-results.json`
- `build/app-review-dark-screenshots-final.log` (iPhone build `2449.2.4`)
- `build/app-review-remediation-release-build.log`
- `build/app-review-audit/remediation-release-bundles.json`
- `build/app-review-audit/ui-fixes-summary.md`

Localization validation, plist/JSON/Python syntax checks, screenshot hashes/dimensions and `git diff --check` passed. No translations were generated.

## Follow-up items and owner decisions

| Audit finding | Current status |
| --- | --- |
| iCloud health-information boundary | Parked by the owner unless App Review raises it. Keep encrypted private CloudKit sync. The prior findings remain background evidence; no pre-review consultation is required. |
| CloudKit delivery | Production schema and the earlier signed export `2449.6.4` are verified. One physical QA test passed encrypted operations and conflict/reset behavior using two clients on one phone. Two-phone convergence, Production/TestFlight runtime, background APNs, offline edits, account/key-reset behavior and real legacy-KVS migration remain unverified. [Physical evidence](cloudkit-physical-verified.json). |
| CloudKit Settings accessibility | Resolved on 16 September: all four previously failing cases pass in the full Settings screen. Bilingual and largest-text captures were inspected, with no report suppression. |
| Native accessibility reports | The two earlier Home cases and six current Settings flows pass. Rejected Form-identity and visibly truncated picker trials remain historical evidence only. [Current evidence](accessibility-remediation-verified.json). |
| Sync disclosure/default | Both final setup flows passed default-on, switch-off and saved-off assertions. Preference and schedule persist together; existing-account restore or legacy migration may already occur before setup. Backup import preserves destination consent. This does not resolve the separate health-information policy question. |
| Extreme custom intervals | Owner authorized a six-hour minimum eating window. Picker and save validation now enforce it for new/changed plans; older saved, imported and synced plans remain readable. [Details](RELEASE_DECISIONS.md#custom-interval-limit). |
| Owner status and China availability | The owner confirmed Kvil is a personal hobby project. The existing non-trader declaration was retained on that stated basis; this records the owner's facts without guaranteeing the legal classification. Mainland China is excluded from the app and purchase; all other territories are unchanged. [Readback](china-availability-verified.json). |
| Final delivery and hardware | The live listings, review notes and all eleven screenshots are updated and verified. Upload/select the new app binary and verify real iCloud, Watch, Health authorization, notifications and StoreKit sandbox/TestFlight behavior. The first purchase must be submitted with the app version. |

The initial privacy-manifest and duplicate-ID defects are fixed. Accessibility is the active engineering follow-up. The owner has parked the iCloud interpretation issue, accepted the one-iPhone testing constraint and retained responsibility for build uploads and submission. Unperformed checks remain unverified.
