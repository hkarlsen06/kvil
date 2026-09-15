# App Review remediation

15 September 2026. Follow-up to [the original audit](APP_REVIEW_AUDIT.md). Changes are uncommitted. No new build, screenshots, listing text or reviewer fixture was uploaded, and no review submission was sent.

## Completed

- **Old build detached live:** removed app version 1.0.0 from the unsubmitted review draft, detached build `2446.23.21`, saved and reloaded. The version now shows **Prepare for Submission** and **Add Build**. The purchase remains in the draft; the old uploaded binary remains in the account. [Readback record](obsolete-build-detached.json).
- **Content rights corrected live:** App Information now declares third-party content with the necessary rights, reflecting the licensed photograph. Saved and reloaded. [Readback record](content-rights-corrected.json).
- **Eleven dark screenshots regenerated:** four iPhone screens and one Watch screen in each language, plus the English purchase review screen. All are unmodified native captures, visually inspected, with dimensions and SHA-256 verified. [Screenshots and capture evidence](screenshots/README.md).
- **Phone privacy manifest fixed:** UserDefaults reason `CA92.1` is declared and verified inside the Release simulator app. The release verifier now checks this declaration in an exported app.
- **Backup/sync validation fixed:** duplicate schedule-version UUIDs are rejected before persistence or merging, preventing SwiftData from collapsing two versions. Regression coverage verifies rejection without replacing existing data, including reopening the store.
- **Restore respects sync choice:** importing a backup preserves the destination device's existing cloud-sync preference. Tests cover both incoming values against both destination values. The default remains enabled; the later transport migration is described below.
- **Layout improvements:** restored Home landscape space on the compact phone, separated the chart unit from its top axis value at largest text, and made the Watch canvas fill its viewport in both languages.
- **Reflection test repaired:** its scroll gesture had activated the wrong answer. It now verifies changed-day → meal times → feeling → save at largest text. Production reflection progression was already correct.
- **Release text prepared:** English/Norwegian listings and review notes describe current setup, Home actions/undo, days off, Health authorization and integrations. [Fictional reviewer fixture](reviewer-demo-README.md) enables review of older history without waiting weeks; it grants no entitlement.

## Encrypted CloudKit implementation

After the fixes above, the user authorized replacing KVS schedule writes with native encrypted fields in the user's private CloudKit database. Local source now targets `iCloud.dev.hkarlsen06.kvil`, zone `Schedule`, record `ScheduleState/current`, encrypted Bytes field `payload`. It retains the full schedule, including Home fasting adjustments and retained plan versions, while reflections and weights stay outside the payload.

The service includes account-owner checks, conditional saves/conflict merging, protected migration state, legacy cleanup after an encrypted save, bounded retries, key-reset recovery, and remote-deletion pauses. Phone entitlements/background configuration and the release verifier cover CloudKit and silent push delivery. Integration is complete. The final run passed **129 unit tests, including 27 cloud tests**, and two Settings UI checks. One ordinary-Norwegian native clipping audit failed with a `nil` target; the three captures were visually inspected without visible truncation. The failure remains recorded. [Final test evidence](cloudkit-test-results.json).

CloudKit Console confirmed the existing container, created the encrypted field in Development, removed all public grants on `ScheduleState`, and deployed the reviewed diff. Production fields and export preview confirm ENCRYPTED BYTES with no indexes or public grants; `Users` was preserved. [Schema readback](cloudkit-schema-readback.json).

Release archive and App Store export **1.0.0 (2449.2.47) passed**, including all four distribution signatures/profiles and the phone's CloudKit Production, production APNs, migration KVS, and privacy declarations. The IPA at `build/AppStore-CloudKit/KvilApp.ipa` has **not been uploaded**. [Signed export evidence](cloudkit-archive-verified.json).

Local privacy/support copy and website HTML are prepared for the new transport, along with both listing payloads and reviewer notes. Nothing was published. Real two-device migration/convergence, APNs delivery, offline/account/key-reset behavior, and public-site publication remain outstanding. [Migration report](CLOUDKIT_MIGRATION.md), [runtime checks](CLOUDKIT_DEPLOYMENT.md).

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

## Still open before submission

| Audit finding | Current status |
| --- | --- |
| iCloud health-information boundary | Encrypted private CloudKit is implemented locally. Public Apple sources still do not classify Kvil's actual fasting-action records or grant an app-specific exemption. Read [the findings](ICLOUD_PRIVACY_FINDINGS.md) and [the unsent consultation draft](APPLE_ICLOUD_CLARIFICATION.md). Technical encryption and policy acceptance are separate. |
| CloudKit delivery | Container and encrypted Production schema are verified, and export `2449.2.47` passes signature/profile/capability checks. Verify real two-device migration/convergence, background APNs delivery, offline edits, and account/key-reset behavior. No live private-user record convergence is claimed. |
| CloudKit Settings accessibility | Two UI checks passed. The ordinary Norwegian native audit reports clipping without a target; all three captures were visually complete. The failure is retained without exemption. |
| Native accessibility reports | Two Home contrast audits and the largest-text reminder clipping audit still fail. The original flagged Home text measures 9.77:1 contrast; later reports identify no target. Keep these failures visible. Trial styling changes that did not solve them were removed; no audit was waived. |
| Sync disclosure/default | Backup import no longer changes consent. Prepared privacy/reviewer/listing copy now describes encrypted private sync and fasting adjustments; the public policy is not yet updated. The existing default remains enabled, so first-run disclosure still requires a final review. |
| Extreme custom intervals | Product/qualified safety assessment remains necessary. No unsupported universal fasting limit was invented. |
| Trader status and territories | The live non-trader declaration, paid purchase and China-mainland availability still require the owner's factual/legal assessment. No declarations or territories were changed. |
| Mac and Vision Pro availability | The audit found these enabled live despite local release settings disabling them and missing platform verification. Select the intended launch platforms and align the live settings before submission. |
| Final delivery and hardware | Upload/select the new candidate, update the live listings/screenshots/review materials, and verify real iCloud, Watch, Health authorization, notifications and StoreKit sandbox/TestFlight behavior. The first purchase must be submitted with the app version. |

The initial privacy-manifest and duplicate-ID defects are fixed. The app is not yet cleared for submission while the remaining items above are unresolved.
