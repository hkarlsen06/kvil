# Kvil

A native iOS 27+ eating-schedule companion with a watchOS 27 app, Home Screen widgets, Lock Screen widgets, and Watch complications.

Kvil follows a weekly schedule automatically. It does not record completed fasts or require start/stop controls. Weight logging and Apple Health are optional. Full reflection history and longer recaps use one non-consumable purchase; the timer, reminders, artwork, and device integrations remain free.

## Development

Open `ios/Kvil.xcodeproj` in Xcode 27 RC or newer. The verified toolchain is Xcode 27.0 (27A266a). The project uses filesystem-synchronized groups and has no third-party dependencies. `App` launches normal onboarding and local storage. `Scenarios` launches an isolated, in-memory Home fixture. `Watch` runs the companion. `StoreKit` connects the local test catalog for purchase tests; UI tests also initialize an isolated StoreKit Test session. The local catalog never creates a charge.

```sh
./scripts/xcode-build-agent.sh --json
XCODE_TEST_AGENT_SCHEME=StoreKit XCODE_TEST_AGENT_DESTINATION='platform=iOS Simulator,id=YOUR_SIMULATOR_ID' ./scripts/xcode-test-agent.sh --json -- -only-testing:KvilAppTests -only-testing:KvilAppUITests -parallel-testing-enabled NO
python3 scripts/localize.py
```

Use `KVIL_SCENARIO=home`, `open`, `reflection`, `history`, or `onboarding` in Debug to explore the production views without touching real storage, Health, purchases, notifications, or iCloud. Scenarios are compiled out of Release. All UI text lives in the shared English/Norwegian String Catalog; the localization script validates it and generates `L10n` accessors.

## Ownership

- `ios/Shared`: pure schedule, reflection, merge, and snapshot contracts, plus Watch transport shared by the two apps.
- `ios/SharedUI`: semantic appearance tokens and small cross-surface SwiftUI components.
- `ios/SharedWidget`: the common timeline provider and widget presentation.
- `ios/KvilApp/Features`: Home, Schedule, History, Weight, Onboarding, Settings, Purchase.
- `ios/KvilApp/Storage`: the single SwiftData container and transactional local repository.
- `ios/KvilApp/Services`: UserNotifications, HealthKit, StoreKit, and iCloud schedule preferences.
- `ios/KvilApp/App`: composition, observable presentation state, lifecycle, and scenarios.

Dates are derived from wall-clock schedule values with a Gregorian calendar in the device time zone. Overnight windows belong to their opening day. Windows are half-open; an opening instant is open and a closing instant is closed. One engine supplies phone, Watch, reminders, and widget transitions. Weekly edits begin tomorrow; today's override is immediate. History reflects the person's answers, not inferred adherence.

## Data and integrations

SwiftData is local and explicitly disables automatic CloudKit mirroring. The protected local store and derived snapshots are excluded from automatic backup. Free JSON export/import supplies local-history recovery; imports validate before replacing any records.

Only schedule configuration uses native iCloud key-value synchronization. Per-day timestamps merge edits, dated override tombstones preserve deletion, and a reset marker prevents erased schedules from reappearing from an offline device. Apple Health owns weight synchronization; reflections never enter the schedule payload. iCloud transmission is eventual, and enabling sync is not proof of server delivery.

Opening/closing reminders use a rolling queue of about four weeks, renewed whenever the app runs. Background refresh is opportunistic. Settings exposes the scheduled-through date. There are no reflection notifications. The phone owns reminder delivery and normal Watch routing.

The Watch persists a validated schedule in its own App Group and calculates locally without the phone. WatchConnectivity transfers the latest configuration; App Groups do not transport data between devices. Widget countdowns are bounded and timelines include opening/closing transitions.

Product: `dev.hkarlsen06.kvil.history`, configured US price $3.99. Support: hjalmar@hkarlsen06.dev. Release materials are under `release/`; their existence does not imply upload or submission.

## Release preparation

Use the App scheme and Release configuration for signing and archives. Set `XCODE_BUILD_AGENT_ALLOW_PROVISIONING=1` to let the signed-in Xcode account manage profiles. `XCODE_BUILD_AGENT_ACTION=archive` creates `build/Kvil.xcarchive` by default. Archive/export does not upload to Apple.

App Store version 1.0.0 and Full History are in the same READY_FOR_REVIEW draft, with manual release selected. The app is free and the non-consumable Full History record is configured at US $3.99 with localized descriptions and territorial availability. The review contact and review notes are saved. Build 2446.23.21 has been uploaded, processed, and attached to the version; internal TestFlight reports READY_FOR_BETA_TESTING. All ten screenshots have processed successfully. Kvil’s [overview](https://hkarlsen06.dev/kvil/), [support](https://hkarlsen06.dev/kvil/support/), and [privacy](https://hkarlsen06.dev/kvil/privacy/) pages are live on the existing portfolio and saved in both App Store locales. The user accepted Apple’s privacy declaration and “Data Not Collected” is published. Apple’s listing checks pass, and the draft displays both items ready to submit. No App Review submission or public App Store release has occurred. See `release/READINESS.md` for completed checks and remaining release gates.

After an archive, run `./scripts/xcode-export-agent.sh` and `python3 scripts/verify-release.py`. The latter verifies all four distribution signatures, embedded profiles, minimum OS versions, localizations, privacy manifests, shared build numbers, and the absence of test resources. Neither command uploads the app.
