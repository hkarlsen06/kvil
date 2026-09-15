# Kvil: iCloud classification clarification

**Unsent draft.** Updated 15 September 2026 for the implemented encrypted CloudKit migration. Production schema and signed export are verified; actual two-device runtime checks remain outstanding. This requests written guidance; it is not approval to ship or an exception to Apple's terms. The [App Review staff reply in thread 838493](https://developer.apple.com/forums/thread/838493) directs developers to an App Review consultation and does not resolve the classification question.

## Consultation draft

**Subject: Kvil eating-schedule sync: clarification under 5.1.3(ii) and 3.3.3(D)**

Hello App Review team,

I develop Kvil, an eating-schedule app for adults (Apple ID 6811427716, bundle ID `dev.hkarlsen06.kvil`). Keeping a user's schedule consistent across their devices is an important feature. I would appreciate written guidance on which parts of the following data may use iCloud.

The replacement implementation encodes a `ScheduleSnapshot` into the `payload` encrypted Bytes field of `ScheduleState/current`, using `CKRecord.encryptedValues` in the user's private CloudKit database (container `iCloud.dev.hkarlsen06.kvil`, zone `Schedule`). The Production schema and signed App Store export have been verified; real cross-device verification remains pending. The record type has no public-database grants, and the app uses no shared database, developer backend, or sharing between users. Reflections, reflection meal times, notes, weights, and HealthKit records are excluded from this payload. Optional HealthKit access is limited to body weight. The local SwiftData store has CloudKit mirroring disabled and is excluded from automatic device backup.

Earlier builds used `NSUbiquitousKeyValueStore` key `schedule.v1`. The new source reads and validates that value for migration, then requests its removal after the encrypted copy is saved. It does not write new schedule payloads to KVS. Existing copies and older clients still need to be considered.

Please assess these categories separately under [App Review Guideline 5.1.3(ii)](https://developer.apple.com/app-store/review/guidelines/#health-and-health-research) and [Developer Program License Agreement 3.3.3(D)](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/):

1. **Recurring planned schedule:** weekday eating-window times, such as 08:00–20:00, and a recurring day-off flag. These are user-selected plans; the app does not infer that a person followed them. Do these fields fall within the health-information restrictions?
2. **Dated plans:** a planned exception with a date, time zone, opening and closing, or a planned day off/break with start and resume dates. Does the classification differ while these are future plans and after their dates have passed?
3. **Actions taken now:** Home has “Break fast early” and “Start fast now”. They write the current timestamp into `adjustedOpening` or `adjustedClosing`, respectively. These timestamps express when the user chose to end or begin a fasting pause; they are not sensor-confirmed meal records. They currently sync inside dated overrides. How do the restrictions apply to these fields?
4. **Retained history and merge metadata:** previous schedule versions, past dated overrides/breaks, modification times, and deletion markers are retained for schedule history and merging offline changes. Does retention change the classification of otherwise permitted fields, and what retention limits or removal requirements apply?

There is also a documentation point we would like to reconcile. Apple's [Encrypting User Data](https://developer.apple.com/documentation/cloudkit/encrypting-user-data) article refers to “your CloudKit-based apps, such as Photos, Notes, Health, Home”. It describes encrypting fields with key material from the user's iCloud Keychain through `CKRecord.encryptedValues`, and says that the server cannot read those encrypted fields. This technical description appears relevant to health-related data, while the guideline and agreement impose the restrictions above.

Does the replacement private CloudKit design, with the sensitive payload stored only through `CKRecord.encryptedValues`, change the classification or permitted use of any of the four categories? How should that documentation be read alongside 5.1.3(ii) and 3.3.3(D)? We also note that the current [`encryptedValues` reference](https://developer.apple.com/documentation/cloudkit/ckrecord/encryptedvalues) qualifies exclusive owner/participant key access with Advanced Data Protection enabled. We do not take the encryption documentation as granting a policy exception.

Here is a fictional excerpt of the current field structure. Dates are rendered as ISO 8601 for readability; the production encoder uses Swift's default numeric date representation. Other weekdays and some metadata are omitted, so this is not an importable backup.

```json
{
  "schema": 2,
  "versions": [{
    "id": "ED4CC6E4-0774-4ADC-B759-B44D9D246122",
    "effectiveDay": "2026-09-01",
    "days": [{
      "weekday": 2, "opens": {"minute": 480},
      "closes": {"minute": 1200}, "dayOff": false
    }]
  }],
  "overrides": [{
    "dayKey": "2026-09-15", "timeZoneID": "Europe/Oslo",
    "opening": "2026-09-15T06:00:00Z",
    "closing": "2026-09-15T18:00:00Z",
    "adjustedClosing": "2026-09-15T17:30:00Z"
  }],
  "breaks": [{
    "id": "B16227AF-E2DB-42D2-BBF8-84B688271F40",
    "startDay": "2026-09-20", "resumeDay": "2026-09-22"
  }]
}
```

The replacement implementation stores this full snapshot inside the encrypted payload, including the retained records above. A shorter snapshot is used for local widgets and the paired Watch, but that does not limit the iCloud payload.

Please identify which categories can be synchronized, any conditions that apply, and how existing iCloud copies should be handled if a category must be excluded. If express written permission under the agreement is required, please direct me to the appropriate process. We understand that private account storage, user consent, and encryption do not by themselves establish an exception, and that consultation guidance does not guarantee App Review approval.

Thank you,
Hjalmar Karlsen

## Local preparation notes

Source checked: `ios/Shared/Schedule.swift`, `ios/Shared/ScheduleBreak.swift`, `ios/KvilApp/Services/ScheduleCloudService.swift`, `CloudKitScheduleClient.swift`, `ScheduleCloudStorage.swift`, and `ios/KvilApp/App/AppModel.swift`. Reconfirm the final integrated behavior, validation status, and action labels before sending. Keep Apple's written response with the final release evidence and distinguish classification guidance from any express permission.
