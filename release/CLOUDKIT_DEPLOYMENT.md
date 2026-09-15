# Kvil CloudKit deployment

Updated 15 September 2026. The existing container was confirmed in CloudKit Console, the encrypted schema was created in Development and deployed to Production, and App Store export **1.0.0 (2449.2.47)** passed signature/profile and entitlement verification. **Actual two-device synchronization, APNs delivery, and migration against live private records remain unverified.** The IPA has not been uploaded.

Evidence: [migration report](CLOUDKIT_MIGRATION.md), [schema readback](cloudkit-schema-readback.json), and [signed export verification](cloudkit-archive-verified.json).

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

## 1. Capability and signing verification

The container `iCloud.dev.hkarlsen06.kvil` already existed and was confirmed in CloudKit Console. The signed phone in the new App Store export authorizes this container, the CloudKit service, CloudKit Production, production APNs, and temporary legacy KVS access. Its embedded distribution profile passed the corresponding authorization checks. The four exported bundles have valid distribution signatures and matching version/build values. The phone retains background fetch and adds remote notifications; Watch/widgets continue receiving local snapshots.

The repository now supplies the container/services and APNs entitlements. `APS_ENVIRONMENT` is `development` in Debug and `production` in Release. An intentionally development-signed Release device build needs the matching development APNs setting; the App Store export must resolve to production.

**Historical initial snapshot:** before the signing refresh on 15 September, these cached phone profiles had empty CloudKit container arrays and no `aps-environment`:

- Development: `8b3d2aec-7e8e-4538-8f61-96987728cb94.mobileprovision`.
- App Store: `4f05b5b6-1ad4-4838-b664-690a7dc67c2d.mobileprovision`.

They were inspected under `~/Library/Developer/Xcode/UserData/Provisioning Profiles/`. That observation is superseded for the final exported artifact by [its actual profile/signature verification](cloudkit-archive-verified.json). A wildcard iCloud service alone does not authorize a missing container association. For future capability changes, refresh signing and verify the resulting artifact again. [Apple's setup instructions](https://developer.apple.com/documentation/cloudkit/enabling-cloudkit-in-your-app).

## 2. Development schema established

CloudKit Console was used to create `ScheduleState.payload` as **ENCRYPTED BYTES** in Development. All `ScheduleState` public-database grants were removed: `_world` read, `_icloud` create, and `_creator` write. The existing `Users` type was left unchanged. No indexes or parallel unencrypted payload field were added. [Encrypted fields](https://developer.apple.com/documentation/cloudkit/encrypting-user-data).

Creating the schema does not create or exercise a user's private records. The app still needs real-device verification of its custom `Schedule` zone, `current` record, and subscription, using a test account and fictional schedule.

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

## 4. Signed candidate verified; real delivery remains

The root archive/export wrappers succeeded for build `2449.2.47`:

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

Final simulator validation ran 129 unit tests, including 27 CloudKit tests: all passed. English and largest-text Norwegian CloudKit Settings UI checks passed. The ordinary Norwegian run failed Apple's native text-clipping audit without an identified target; the three captured layouts were visually inspected and no clipping was visible. The failure remains recorded in [the final validation log](../build/cloudkit-migration-final-validation.log).

### Remaining physical checks

On two test devices using the same account, verify a schedule edit and reset reach the other device, including when that app is backgrounded. Read back the zone subscription and ensure its notification uses only `shouldSendContentAvailable = true`. Silent delivery is opportunistic and notifications can coalesce; foreground fetching must recover missed updates. Scheduling sync must not require permission for visible reminder alerts. [Zone notifications](https://developer.apple.com/documentation/cloudkit/ckrecordzonenotification).

Exercise offline edits/conflicts, an absent account, an account change, malformed or oversized payloads, user-deleted zones, and lost encryption-key access. Confirm failures preserve local records. Migration must preserve accepted data before clearing legacy KVS, must stop new KVS payload writes, and must handle an older client reintroducing the legacy key. Confirm reflections and weights never enter either cloud payload.

Update the public privacy page and reviewer notes to match the verified implementation. Record signed-build checks, schema readback, real cross-device delivery, and policy guidance separately; none substitutes for the others.
