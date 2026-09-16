# Kvil CloudKit deployment

**Current owner decisions (15 September):** iCloud policy clarification is parked unless App Review raises it; two-iPhone testing is deferred because only one iPhone is available; mainland China is excluded; all build uploads and submission are owner-managed. The two Home accessibility checks now pass; four Settings/reminder clipping audits remain unresolved. [Release decisions](RELEASE_DECISIONS.md).

Updated 15 September 2026. The encrypted schema is deployed to Production, and current App Store export **1.0.0 (2449.6.4)** passed signature/profile and entitlement checks. Latest simulator validation passed 132 model tests (one opt-in live test skipped) and both setup flows. Six native accessibility audits remain unresolved: two Home contrast reports and four Settings/reminder clipping reports. No suppression or blanket waiver was added. A separate earlier native CloudKit test passed on one physical iPhone with two client instances and fictional QA data. **Two physical phones, Production/TestFlight runtime, background APNs, and real legacy-record migration remain unverified.** No new binary has been uploaded.

Evidence: [current signed export](audit-candidate-verified.json), [migration report](CLOUDKIT_MIGRATION.md), [schema readback](cloudkit-schema-readback.json), [earlier signed export](cloudkit-archive-verified.json), and [physical test](cloudkit-physical-verified.json).

## Contract

| Item | Exact value |
| --- | --- |
| Team | `48ZSLD4RMP` |
| Phone bundle | `dev.hkarlsen06.kvil` |
| Container | `iCloud.dev.hkarlsen06.kvil` |
| Database | Current user's private database |
| Custom zone | `Schedule`, owned by the current user |
| Record type | `ScheduleState` |
| Record name | `current` in the `Schedule` zone |
| Application field | `payload`, written/read through `CKRecord.encryptedValues` as `Data`/`NSData` |
| Schema field type | `ENCRYPTED BYTES`; Console label: Encrypted Bytes |
| Change delivery | Silent record-zone subscription; no schedule values in notification content |
| Legacy store | KVS key `schedule.v1`, retained only for migration and cleanup |

Record/zone identifiers and CloudKit system metadata are separate from the encrypted payload. Reflections and weight records remain outside the schedule payload. Encryption does not establish App Review approval; see [the policy findings](ICLOUD_PRIVACY_FINDINGS.md).

## Setup sync choice

The weekly setup preview now includes a schedule-sync toggle. It starts on for a fresh installation and can be switched off before saving setup; an existing preference is used when present. The selected preference and new schedule persist together before the new schedule is published. Existing-account restoration or legacy KVS migration may already occur before setup, so this choice does not guarantee that no earlier cloud access occurred. Both ordinary and largest-text setup tests passed after targeting the native switch. Assertions verify its default-on state, switching off and the saved-off choice.

## 1. Capability and signing verification

The container `iCloud.dev.hkarlsen06.kvil` already existed and was confirmed in CloudKit Console. The signed phone in the current `2449.6.4` App Store export authorizes this container, the CloudKit service, CloudKit Production, production APNs, and temporary legacy KVS access. Its embedded distribution profile passed the corresponding authorization checks. The four exported bundles have valid distribution signatures and matching version/build values. The phone retains background fetch and adds remote notifications; Watch/widgets continue receiving local snapshots.

The repository now supplies the container/services and APNs entitlements. `APS_ENVIRONMENT` is `development` in Debug and `production` in Release. An intentionally development-signed Release device build needs the matching development APNs setting; the App Store export must resolve to production.

**Historical initial snapshot:** before the signing refresh on 15 September, these cached phone profiles had empty CloudKit container arrays and no `aps-environment`:

- Development: `8b3d2aec-7e8e-4538-8f61-96987728cb94.mobileprovision`.
- App Store: `4f05b5b6-1ad4-4838-b664-690a7dc67c2d.mobileprovision`.

They were inspected under `~/Library/Developer/Xcode/UserData/Provisioning Profiles/`. That observation is superseded for the `2449.2.47` exported artifact by [its actual profile/signature verification](cloudkit-archive-verified.json). A wildcard iCloud service alone does not authorize a missing container association. For future capability changes, refresh signing and verify the resulting artifact again. [Apple's setup instructions](https://developer.apple.com/documentation/cloudkit/enabling-cloudkit-in-your-app).

## 2. Development schema established

CloudKit Console was used to create `ScheduleState.payload` as **ENCRYPTED BYTES** in Development. All `ScheduleState` public-database grants were removed: `_world` read, `_icloud` create, and `_creator` write. The existing `Users` type was left unchanged. No indexes or parallel unencrypted payload field were added. [Encrypted fields](https://developer.apple.com/documentation/cloudkit/encrypting-user-data).

Creating the schema does not create or exercise a user's private records. The later physical test exercised encrypted records and a subscription in a dedicated QA zone. Runtime verification of the app's Production `Schedule/current` record and two-device delivery remains outstanding.

The equivalent minimal CloudKit Schema Language declaration is:

```text
DEFINE SCHEMA
    RECORD TYPE ScheduleState (
        payload ENCRYPTED BYTES
    );
```

`ENCRYPTED BYTES` is two tokens. It is not `ENCRYPTED_BYTES` or plain `BYTES`. This record type needs no public-database grants. The custom zone, `current` record, and per-user zone subscription are runtime data, not declarations in the schema file. If the container already has a schema, export it and preserve its other definitions instead of replacing it with this minimal example. [Apple's schema grammar](https://developer.apple.com/documentation/cloudkit/integrating-a-text-based-schema-into-your-workflow).

The command syntax below was checked against installed `cktool` **1.0.23001** help and [Apple's CLI documentation](https://developer.apple.com/icloud/ck-tool/). No authenticated commands were run. Schema operations use a management token stored through cktool's Keychain workflow; do not place tokens in this document or shell history.

For a future CLI readback, these are the verified command forms:

```sh
mkdir -p build/cloudkit
xcrun cktool export-schema \
  --team-id 48ZSLD4RMP \
  --container-id iCloud.dev.hkarlsen06.kvil \
  --environment development \
  --output-file build/cloudkit/development.ckdb

xcrun cktool validate-schema \
  --team-id 48ZSLD4RMP \
  --container-id iCloud.dev.hkarlsen06.kvil \
  --environment development \
  --file build/cloudkit/development.ckdb
```

If applying a reviewed local schema to Development is necessary, the verified command form is:

```sh
xcrun cktool import-schema \
  --team-id 48ZSLD4RMP \
  --container-id iCloud.dev.hkarlsen06.kvil \
  --environment development \
  --validate \
  --file build/cloudkit/development.ckdb
```

That import mutates the development schema. `validate-schema` sends the schema to Apple for validation but does not import it. Neither has been executed for this migration.

## 3. Production schema deployed

The exact deployment diff was reviewed in Console: one `ScheduleState` type containing encrypted `payload`, no public grants on that type, and no changes to `Users`. After deployment, Console reported **Changes Deployed**. The environment was switched to Production and `ScheduleState` was read back with seven fields: six system metadata fields and `payload` as **ENCRYPTED BYTES**, with indexes **None**. The Production export preview, `cloudkit-production.ckdb` (643 bytes), confirmed the complete `ScheduleState` definition has no `GRANT` clauses. It was previewed, not downloaded. [Schema readback record](cloudkit-schema-readback.json).

An optional later CLI export uses:

```sh
xcrun cktool export-schema \
  --team-id 48ZSLD4RMP \
  --container-id iCloud.dev.hkarlsen06.kvil \
  --environment production \
  --output-file build/cloudkit/production.ckdb
```

For future schema changes, review and preserve the exact diff and Production readback again. Schema promotion copies definitions, not test records; App Store builds require the Production schema. Existing production types/fields cannot simply be removed, and existing unencrypted fields cannot be converted to encrypted ones. [Schema deployment](https://developer.apple.com/documentation/cloudkit/deploying-an-icloud-container-s-schema).

## 4. Current signed candidate: 2449.6.4

The current local signed candidate is **1.0.0 (2449.6.4)**: `build/Kvil-FinalAudit.xcarchive` and `build/AppStore-FinalAudit/KvilApp.ipa`. Its SHA-256 is `82e4a9246d7789791ae0696a244002c4b7bdd3dbee8764087ee6136ecab9ade8`. All four distribution signatures/profiles and matching bundle versions/builds passed verification, including phone CloudKit Production, production APNs, migration KVS access, privacy manifests and absence of Debug resources and QA audit hooks from exported binaries. The binary has **not been uploaded**. Localization validation passed. Latest simulator validation passed 132 model tests (one opt-in live test skipped) and both setup flows. Six native accessibility audits remain unresolved: two Home contrast reports and four Settings/reminder clipping reports. No suppression or blanket waiver was added. [Current signed artifact](audit-candidate-verified.json). [Accessibility evidence](accessibility-verified.json).

The export wrapper accepts `KVIL_ASC_ENV_FILE`, matching the build wrapper's existing signing-credential context. This makes the managed export reproducible when Xcode has no separately loaded account.

Recheck the current artifact with its explicit paths:

```sh
python3 scripts/verify-release.py \
  --ipa build/AppStore-FinalAudit/KvilApp.ipa \
  --archive build/Kvil-FinalAudit.xcarchive \
  --output release/audit-candidate-verified.json
```

### Final simulator results

The model bundle at build `2449.5.45` passed 132 tests and skipped its opt-in live CloudKit test. Final build `2449.5.56` passed both setup flows and the compact Home geometry assertions, while both Home native contrast audits failed. Build `2449.6.0` failed all four Settings/reminder native audits with `Text clipped`. These six reports remain unresolved and unsuppressed. The separate physical CloudKit result is retained below. [Final simulator details](APP_REVIEW_REMEDIATION.md#final-simulator-verification).

### Historical signed checkpoint: 2449.2.47

The root archive/export wrappers also succeeded for build `2449.2.47`. The retained results below cover that earlier source-specific checkpoint:

- Archive: `build/Kvil-CloudKit.xcarchive`.
- IPA: `build/AppStore-CloudKit/KvilApp.ipa`.
- SHA-256: `f2ad7d4e278cd5a0877d0e886f0194c04a57a4fda81fba32ed302906089786be`.
- Upload: **not performed**.

The verifier passed against this artifact and wrote a separate record, preserving the old archive checkpoint. Repeat it with explicit paths:

```sh
python3 scripts/verify-release.py \
  --ipa build/AppStore-CloudKit/KvilApp.ipa \
  --archive build/Kvil-CloudKit.xcarchive \
  --output release/cloudkit-archive-verified.json
```

The signed phone and embedded distribution profile were verified for:

- Container `iCloud.dev.hkarlsen06.kvil` and CloudKit service.
- CloudKit `Production` environment and APNs `production` environment.
- The temporary KVS entitlement needed by migration.

The built phone's background mode and required UserDefaults privacy declaration also passed verification. These checks establish capability/signing configuration; they do not establish runtime convergence in the private Production database.

The earlier simulator checkpoint ran 129 unit tests, including 27 CloudKit tests: all passed. English and largest-text Norwegian CloudKit Settings UI checks passed. The ordinary Norwegian run failed Apple's native text-clipping audit without an identified target; the three captured layouts were visually inspected and no clipping was visible. The failure remains recorded in [the final validation log](../build/cloudkit-migration-final-validation.log).

## 5. One-device native CloudKit check

Build `2449.4.42` passed one native integration test on a physical iPhone 17 Pro running iOS 27.0. Two independent clients used `KvilQA-6A38095F-4C18-4DB5-BC8A-8AC84D1B59CF`, containing only fictional data. They verified encrypted save/fetch, subscription creation, actual stale-write conflict merging, reset-tombstone preservation, cancellation before submission, a real `zoneNotFound` response, explicit zone recreation, and another encrypted round trip. QA subscription and zone cleanup succeeded. [Physical readback](cloudkit-physical-verified.json).

The test was development-signed with APNs `development`. It did not verify Production/TestFlight private-record behavior or background notification delivery. This single physical test is separate from the earlier 129-unit-test suite and signed distribution archive.

### Remaining physical checks

On two test devices using the same account, verify a schedule edit and reset reach the other device, including when that app is backgrounded. Read back the zone subscription and ensure its notification uses only `shouldSendContentAvailable = true`. Silent delivery is opportunistic and notifications can coalesce; foreground fetching must recover missed updates. Scheduling sync must not require permission for visible reminder alerts. [Zone notifications](https://developer.apple.com/documentation/cloudkit/ckrecordzonenotification).

Exercise offline edits/conflicts, an absent account, an account change, malformed or oversized payloads, user-deleted zones, and lost encryption-key access. Confirm failures preserve local records. Migration must preserve accepted data before clearing legacy KVS, must stop new KVS payload writes, and must handle an older client reintroducing the legacy key. Confirm reflections and weights never enter either cloud payload.

The public privacy/support articles were published and read back on 15 September. [Publication evidence](privacy-site-verified.json). The reviewer notes, both localized listing updates and all eleven screenshot assets are saved and verified in App Store Connect. [Material readback](appstore-materials-verified.json). Select the new binary separately when it is uploaded. Record signed-build checks, schema readback, real cross-device delivery, and policy guidance separately; none substitutes for the others.
