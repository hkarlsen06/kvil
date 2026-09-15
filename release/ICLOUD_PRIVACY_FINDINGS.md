# iCloud privacy findings

Updated 15 September 2026. Sync remains a product requirement. The user authorized the native encrypted private CloudKit migration after this investigation. Integration and the unit suite are complete; the encrypted Production schema and signed export `2449.2.47` have been verified. Real two-device/APNs and migration verification remain outstanding. The default sync preference remains enabled. [Migration and validation report](CLOUDKIT_MIGRATION.md).

## Conclusion

Kvil now uses native encrypted CloudKit fields in the user's private database for the schedule payload. It retains legacy KVS access for migration and cleanup, without writing new schedule payloads there. This changes the technical protection of the data; it does not resolve Apple's classification of fasting-action timestamps under its health-information restrictions. Public sources do not establish an exception for this app. Written App Review clarification remains useful, and the release cannot yet claim verified production sync.

## What Apple actually documents

- [Review Guideline 5.1.3(ii)](https://developer.apple.com/app-store/review/guidelines/#health-and-health-research) prohibits storing personal health information in iCloud. The clause is not expressly limited to records obtained through HealthKit. It does not classify Kvil's planned hours or user-triggered fasting timestamps.
- [Developer Program License Agreement 3.3.3(D)](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/) names iCloud storage and CloudKit in its restriction concerning sensitive, individually identifiable health information, subject to express written permission. Its reference to HIPAA does not establish that only regulated clinical records are covered.
- [Encrypting User Data](https://developer.apple.com/documentation/cloudkit/encrypting-user-data) explicitly mentions Photos, Notes, Health, and Home in its examples. It documents `CKRecord.encryptedValues`, key material in the user's iCloud Keychain, and fields that the database server cannot read. This is real technical guidance, but it does not discuss 5.1.3 or grant an explicit health-data exception.
- [WWDC21: What's new in CloudKit](https://developer.apple.com/videos/play/wwdc2021/10086/) introduces encrypted fields for developers after describing protection in Apple-owned apps. The capitalized examples in the documentation likely refer to Apple's apps; that is an inference, not a policy ruling.
- [WWDC25: Integrate privacy into your development process](https://developer.apple.com/videos/play/wwdc2025/246/) qualifies third-party CloudKit end-to-end protection by the user's Advanced Data Protection setting. Do not promise that using encrypted fields alone makes all data inaccessible to Apple for every user.
- The current [`CKRecord.encryptedValues` reference](https://developer.apple.com/documentation/cloudkit/ckrecord/encryptedvalues) likewise says field values are encrypted on-device, and qualifies exclusive owner/participant key availability with Advanced Data Protection enabled. The prepared policy describes encrypted fields without claiming universal end-to-end protection.
- A [July 2026 reply by Apple Staff, App Review](https://developer.apple.com/forums/thread/838493), responds to the exact private/encrypted CloudKit question by directing the developer to a one-on-one consultation. It gives no public interpretation or exception.

## Kvil's actual boundary

| Data | Current destination | Assessment |
| --- | --- | --- |
| Recurring intended hours | Encrypted private CloudKit payload, phone, Watch/widgets; legacy KVS until migration cleanup completes | Plausible configuration, but no explicit Apple classification for this use case. |
| Dated changes, days off and retained plan history | Same | Need classification separately from generic preferences. Passing dates do not establish actual adherence. |
| `adjustedOpening` / `adjustedClosing` from actions taken now | Same | Records a user's actual choice to begin/end a fasting pause. Stronger health-information concern than intended hours. |
| Reflections, meal-time reflections, notes and local weights | Local protected storage; user-selected backup export | Excluded from schedule sync. |
| Authorized body-mass samples | Apple Health | A legitimate HealthKit type with Apple-managed sync. |

Apple's [HealthKit framework documentation](https://developer.apple.com/documentation/healthkit/about-the-healthkit-framework) restricts samples to defined types. Inspection of the current iPhoneOS 27 public SDK found no fasting/eating-window type. Unrelated workouts, mindfulness or nutritional samples must not be fabricated to carry fasting state.

## Implemented direction and outstanding verification

`CloudKitScheduleClient` targets container `iCloud.dev.hkarlsen06.kvil`, the current user's private database, custom zone `Schedule`, record type `ScheduleState`, record name `current`, and encrypted Bytes field `payload`. `ScheduleCloudPayload` accepts only a validated `ScheduleSnapshot` below 900,000 bytes and rejects application fields stored outside `encryptedValues`.

The service implements conditional saves and conflict merging, account-owner checks, durable local migration state, bounded retries, encrypted-key-reset recovery, pauses after detected remote deletion, and a silent zone subscription. Legacy `schedule.v1` data is validated and merged, then removal is requested only after the encrypted record is saved and migration state is persisted. An older client can recreate the legacy key, so migration behavior must be exercised with both versions. These are implementation facts, not evidence that the operations succeeded against Apple's production service.

The initial cached development and distribution profiles did not authorize a CloudKit container or push notifications. The actual App Store export now passes the required CloudKit Production and production APNs checks with its embedded profile. CloudKit Console confirmed the existing container, deployed `ScheduleState.payload` as ENCRYPTED BYTES, and read back Production with no indexes or public grants. `Users` was unchanged. [Signed export](cloudkit-archive-verified.json), [schema readback](cloudkit-schema-readback.json).

The final suite passed 129 unit tests, including 27 cloud migration/error/concurrency tests. Two Settings UI checks passed; the ordinary Norwegian clipping audit remains unresolved with no identified target, although all three captures were visually complete. These results do not establish real-device convergence or APNs delivery. [Test evidence](cloudkit-test-results.json), [remaining deployment/runtime checks](CLOUDKIT_DEPLOYMENT.md).

Local listing, reviewer, privacy, and support text now describe this direction. The edited HTML under `release/site/dist/` is prepared for the canonical portfolio website and has not been published.

## Alternatives considered during the investigation

1. **Encrypted private CloudKit:** selected and implemented locally, retaining the shared schedule/merge engine. The live checks and policy uncertainty above remain.
2. **Configuration-only iCloud:** possible only if Apple accepts the selected fields and the product accepts syncing actual actions through another route. Renaming action timestamps as preferences would not change their meaning.
3. **Authenticated non-iCloud backend:** Apple's [WWDC20 HealthKit synchronization session](https://developer.apple.com/videos/play/wwdc2020/10184/) explicitly teaches external-server synchronization of health data. This is an alternative architecture, with consent, access isolation, security, deletion and disclosure work. It is not the only candidate and is not automatically approved.

WatchConnectivity and local widgets can remain in every option. Apple's [WWDC20 CareKit session](https://developer.apple.com/videos/play/wwdc2020/10151/) demonstrates WatchConnectivity for user-reported care outcomes, as well as remote-server synchronization.

The [unsent clarification draft](APPLE_ICLOUD_CLARIFICATION.md) separates planned hours, dated exceptions, actions taken now and retained history, and asks about the implemented encrypted-CloudKit design. No message has been sent to Apple, and no app-specific written permission or approval is recorded.
