# Encrypted CloudKit migration

15 September 2026. Implemented and deployed the schedule schema. No app upload, review submission, commit or push was performed by this migration.

## Result

Kvil now stores its schedule in one encrypted `payload` field on `ScheduleState/current`, in the `Schedule` custom zone of the current user's **private** `iCloud.dev.hkarlsen06.kvil` database. The payload includes existing schedule history, window adjustments and days off. Reflections, weight, Health data and device preferences cannot enter this boundary.

The production schema was created and read back in CloudKit Console. The application field is **ENCRYPTED BYTES**, with no indexes or public-database grants. `Users` was preserved. [Live readback](cloudkit-schema-readback.json).

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

- **129 unit tests passed**, including **27 migration/error/concurrency tests**, in the final full unit run. Tests also cover the shared schedule engine, date boundaries, persistence, Health and purchase behavior.
- **Two UI checks passed:** English dark-mode cloud settings and Norwegian at the largest Dynamic Type size.
- **One UI audit remains unresolved:** ordinary Norwegian reports potential clipping but supplies a `nil` target. The entire cloud toggle, status and disclosure are visibly complete in the captured screen. Both root and an independent agent inspected all three captures. No audit exemption was added.
- **Release archive and App Store export passed:** version 1.0.0, build **2449.2.47**. All four distribution signatures and profiles passed verification, including phone CloudKit `Production`, APNs `production`, the exact container, migration KVS access, privacy manifests and absence of Debug resources.
- Localization validation and whitespace checks passed.

Evidence: [test results and source fingerprints](cloudkit-test-results.json), [signed export verification](cloudkit-archive-verified.json), `build/cloudkit-migration-final-validation.log`, `build/cloudkit-ui-final/`, `build/cloudkit-migration-archive.log`, and `build/cloudkit-migration-export.log`.

The local candidate is `build/AppStore-CloudKit/KvilApp.ipa`, from `build/Kvil-CloudKit.xcarchive`. It has **not been uploaded**. The user will upload the latest candidate when ready.

## Remaining release checks

Real-device migration and cross-iPhone convergence, background APNs delivery, offline concurrent edits, and account/keychain-reset flows remain unverified against live user databases. The audit did not create or modify personal cloud records. Use dedicated test accounts and fictional schedules for those checks.

Prepared privacy/support pages and reviewer/listing text still need publication with the final release. Encryption does not establish an app-specific App Review decision; the separate [policy findings](ICLOUD_PRIVACY_FINDINGS.md) retain that distinction. Earlier unrelated audit items remain in [App Review remediation](APP_REVIEW_REMEDIATION.md).
