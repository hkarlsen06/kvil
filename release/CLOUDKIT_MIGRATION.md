# Encrypted CloudKit migration

**Current owner decisions (15 September):** iCloud policy clarification is parked unless App Review raises it; two-iPhone testing is deferred because only one iPhone is available; mainland China is excluded; all build uploads and submission are owner-managed. The two Home accessibility checks now pass; four Settings/reminder clipping audits remain unresolved. [Release decisions](RELEASE_DECISIONS.md).

15 September 2026. Implemented and deployed the schedule schema. No app upload, review submission, commit or push was performed by this migration.

## Result

Kvil now stores its schedule in one encrypted `payload` field on `ScheduleState/current`, in the `Schedule` custom zone of the current user's **private** `iCloud.dev.hkarlsen06.kvil` database. The payload includes existing schedule history, window adjustments and days off. Reflections, weight, Health data and device preferences cannot enter this boundary.

The production schema was created and read back in CloudKit Console. The application field is **ENCRYPTED BYTES**, with no indexes or public-database grants. `Users` was preserved. [Live readback](cloudkit-schema-readback.json).

## Setup sync choice

The weekly setup preview now includes a schedule-sync toggle. It starts on for a fresh installation and can be switched off before saving setup; an existing preference is used when present. The selected preference and new schedule persist together before the new schedule is published. Existing-account restoration or legacy KVS migration may already occur before setup, so this choice does not guarantee that no earlier cloud access occurred. Both ordinary and largest-text setup tests passed after targeting the native switch. Assertions verify its default-on state, switching off and the saved-off choice.

## Migration and recovery behavior

| Situation | Behavior |
| --- | --- |
| First encrypted sync | Validate legacy KVS and cloud records, merge with the latest local schedule, commit locally, then save conditionally to CloudKit. |
| Legacy cleanup | Remove only the exact legacy bytes included in an acknowledged encrypted copy, after persisting migration state. Failed uploads keep the legacy copy. No new schedule payload is written to KVS. |
| Older app publishes KVS again | Validate and merge the new legacy value, then clean it up after acknowledgement. Older installations need to update; they can still write KVS until then. |
| Concurrent edits / stale CloudKit change tag | Reuse CloudKit's server record and merge both devices' changes. A local edit during an upload queues another pass. |
| Missing zone or record | Provision a genuinely fresh account. If an already observed cloud copy disappears, pause and preserve local data. Explicitly reenabling sync authorizes uploading the retained local schedule. |
| Confirmed encryption-key reset | Require `zoneNotFound` and a true `CKErrorUserDidResetEncryptedDataKey`. Recheck for another device's recovered copy before deleting an unreadable zone. Recreate and upload validated local data. |
| Repeated reset failure | Pause durably across launches instead of repeatedly deleting/recreating the zone. The user can explicitly retry from Settings. |
| User-deleted zone | Always pause. Do not silently recreate the zone or erase the local schedule. |
| Account change | Cancel stale work and compare the owner ID before publishing. A different owner pauses sync. Explicit restart cannot import stale legacy data cached from the previous account. |
| Temporary account unavailability | Wait for Apple's account-change notification before requesting more account operations. |
| Network throttling | Respect retry-after values, including values wrapped in partial failures; retry with bounded backoff. Foreground reconciliation recovers missed notifications. |
| Restore, erase, toggle off or timeout | Cancel operations and fence late responses by generation. Old work cannot acknowledge legacy cleanup or consume a replacement task's request. |
| Corrupt payload or metadata / local save failure | Keep local and legacy copies, stop publishing, and show a needs-attention state. |

The local SwiftData schedule is the durable pending copy. Protected sync metadata is excluded from device backups and from user-exported backups. Watch, widgets, reminders and Live Activities receive local changes without waiting for the network.

Silent CloudKit notifications share the scene's app model even on a cold launch. Their completion is bounded to 25 seconds; an expired fetch cannot cancel a newer sync generation. Debug scenarios never construct the real CloudKit container.

[Apple's encrypted-field and keychain-reset documentation](https://developer.apple.com/documentation/cloudkit/encrypting-user-data) informed recovery. The code distinguishes Apple's encryption-reset error from a deliberate remote deletion.

## Verification

### Current signed candidate: 2449.6.4

The current local signed candidate is **1.0.0 (2449.6.4)**: `build/Kvil-FinalAudit.xcarchive` and `build/AppStore-FinalAudit/KvilApp.ipa`. Its SHA-256 is `82e4a9246d7789791ae0696a244002c4b7bdd3dbee8764087ee6136ecab9ade8`. All four distribution signatures/profiles and matching bundle versions/builds passed verification, including phone CloudKit Production, production APNs, migration KVS access, privacy manifests and absence of Debug resources and QA audit hooks from exported binaries. The binary has **not been uploaded**. Localization validation passed. Latest simulator validation passed 132 model tests (one opt-in live test skipped) and both setup flows. Six native accessibility audits remain unresolved: two Home contrast reports and four Settings/reminder clipping reports. No suppression or blanket waiver was added. [Current signed artifact](audit-candidate-verified.json). [Accessibility evidence](accessibility-verified.json).

### Final simulator results

The model bundle at build `2449.5.45` passed 132 tests and skipped its opt-in live CloudKit test. Final build `2449.5.56` passed both setup flows and the compact Home geometry assertions, while both Home native contrast audits failed. Build `2449.6.0` failed all four Settings/reminder native audits with `Text clipped`. These six reports remain unresolved and unsuppressed. The separate physical CloudKit result is retained below. [Final simulator details](APP_REVIEW_REMEDIATION.md#final-simulator-verification).

### Earlier unit and archive checkpoint

- **129 unit tests passed**, including **27 migration/error/concurrency tests**, in the earlier full unit run. Tests also cover the shared schedule engine, date boundaries, persistence, Health and purchase behavior.
- **Two UI checks passed:** English dark-mode cloud settings and Norwegian at the largest Dynamic Type size.
- **One UI audit remains unresolved:** ordinary Norwegian reports potential clipping but supplies a `nil` target. The entire cloud toggle, status and disclosure are visibly complete in the captured screen. Both root and an independent agent inspected all three captures. No audit exemption was added.
- **Release archive and App Store export passed:** version 1.0.0, build **2449.2.47**. All four distribution signatures and profiles passed verification, including phone CloudKit `Production`, APNs `production`, the exact container, migration KVS access, privacy manifests and absence of Debug resources.
- Localization validation and whitespace checks passed.

Evidence: [test results and source fingerprints](cloudkit-test-results.json), [signed export verification](cloudkit-archive-verified.json), `build/cloudkit-migration-final-validation.log`, `build/cloudkit-ui-final/`, `build/cloudkit-migration-archive.log`, and `build/cloudkit-migration-export.log`.

The signed `2449.2.47` checkpoint was exported to `build/AppStore-CloudKit/KvilApp.ipa` from `build/Kvil-CloudKit.xcarchive`. Its verification applies to that recorded source and artifact and is retained separately from the current `2449.6.4` candidate above. No new binary has been uploaded; the user will upload the final candidate when ready.

### Physical CloudKit server check

A separate native integration test passed on one physical iPhone 17 Pro running iOS 27.0, build `2449.4.42`: **one passed, none failed or skipped**. Two independent client instances used a dedicated UUID QA zone and fictional schedules. The test verified encrypted save and independent fetch, a saved zone subscription, real stale-write conflict merging, and a reset tombstone surviving a stale client. A write cancelled before submission left cloud data unchanged. It then observed `zoneNotFound`, explicitly recreated the QA zone, repeated the encrypted round trip, and cleaned up its subscription and zone. [Physical test evidence](cloudkit-physical-verified.json).

The device test was development-signed, with APNs `development`. It is separate from the earlier 129-unit-test run and the `2449.2.47` distribution archive. Saving a subscription does not establish notification delivery.

## Remaining release checks

Two physical iPhones converging, Production/TestFlight private-record operations, background APNs delivery, offline concurrent edits, real account/keychain-reset flows, and transport migration of a real legacy KVS record remain unverified. The passed physical test used and cleaned up only its fictional QA data. Continue with dedicated test accounts and fictional schedules for the remaining checks.

The privacy/support articles were published on 15 September and read back from the public URLs. [Publication evidence](privacy-site-verified.json). Reviewer notes and both localized listing updates are saved in App Store Connect and match the requested fields exactly. Ten storefront screenshots and the purchase review image are uploaded and processed. [App Store material evidence](appstore-materials-verified.json). The new binary remains local. Encryption does not establish an app-specific App Review decision; the separate [policy findings](ICLOUD_PRIVACY_FINDINGS.md) retain that distinction. Earlier unrelated audit items remain in [App Review remediation](APP_REVIEW_REMEDIATION.md).
