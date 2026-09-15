# Kvil

A native iOS 27+ eating-schedule companion with a watchOS 27 app, Home Screen widgets, Lock Screen widgets, Watch complications, Live Activities, and Siri/Shortcuts. The iOS 27 and watchOS 27 minimums are retained.

Kvil follows a weekly schedule automatically. Home also lets you break a fast early or start fasting now by adjusting the current window. An early break keeps the next scheduled closing time; starting a fast keeps the next planned opening. These dated adjustments do not change the usual week or record completed fasts. Weight logging and Apple Health are optional. Full reflection history and longer recaps use one non-consumable purchase; the timer, reminders, artwork, and device integrations remain free.

- Guided setup follows five steps: welcome, rhythm, meal times, a personal pause illustration, and the weekly preview. The interactive day diagram is the rhythm picker for 12:12, 14:10, 16:8, or Custom, with curved labels following their matching arcs. Plan's draggable window sets the usual meal times. The following noninteractive illustration shows the pause between those chosen times, including its duration and whether the next meal is tomorrow, with a caption curved above the arc. It explains that sleep counts and that Kvil has no hours to make up, with a single guide link. Individual weekday sliders then let you adjust the week before saving. Progress, native transitions, and light haptics guide the flow; Reduce Motion and large text are supported. Setup and reflection actions stay at the bottom while content scrolls underneath. A short practical guide remains available in Settings. Presets are examples with no automatic progression.
- Home's “How did yesterday go?” button opens a sheet showing one relevant step at a time: whether the day followed the plan, optional approximate first/last meal times if it changed or the person is unsure, then a feeling and optional note. Days off go straight to the feeling. Cancel leaves the draft unsaved. History shows the planned window beside the person's answers and clearly labels meal estimates; answering “As planned” never invents actual meal times.
- Plan supports recurring weekdays off, taking today off, and dated breaks with a resume date. Saved weekday hours remain available when scheduling resumes. The shared engine handles days off across Home, Watch, widgets, reminders, and reflections.
- Opening reminders default to the planned opening time; closing reminders default to 15 minutes before closing. Both support the boundary, 15 minutes, or 30 minutes before. Explicitly saved timings are preserved, with one chosen reminder per boundary.
- Optional Live Activities show the wait until opening on the Lock Screen and Dynamic Island. Siri/Shortcuts can report the next opening or open Plan.

## Development

Open `ios/Kvil.xcodeproj` in Xcode 27 RC or newer. The verified toolchain is Xcode 27.0 (27A266a). The project uses filesystem-synchronized groups and the native app has no third-party dependencies. `App` launches normal onboarding and local storage. `Scenarios` launches an isolated, in-memory Home fixture. `Watch` runs the companion. `StoreKit` connects the local test catalog for purchase tests; UI tests also initialize an isolated StoreKit Test session. The local catalog never creates a charge.

```sh
./scripts/xcode-build-agent.sh --json
XCODE_TEST_AGENT_SCHEME=StoreKit XCODE_TEST_AGENT_DESTINATION='platform=iOS Simulator,id=YOUR_SIMULATOR_ID' ./scripts/xcode-test-agent.sh --json -- -only-testing:KvilAppTests -only-testing:KvilAppUITests -parallel-testing-enabled NO
python3 scripts/validate-localization.py
```

Use `KVIL_SCENARIO=home`, `open`, `reflection`, `reflectionDayOff`, `reflectionOvernight`, `dayOff`, `upcomingDayOff`, `history`, or `onboarding` in Debug to explore the production views without touching real storage, Health, purchases, notifications, Live Activities, or iCloud. Scenarios are compiled out of Release. UI copy lives in the shared English/Norwegian String Catalog. Swift code uses Xcode-generated symbols such as `Text(.cancel)` and `String(localized: .saveFailed)`; Xcode generates them during the build. Health permission descriptions live in `ios/KvilApp/Supporting/InfoPlist.xcstrings`.

Add or update copy with `./scripts/xcstrings-set cancel --comment "Dismiss without saving" --en "Cancel" --nb "Avbryt"`, or use Xcode's catalog editor. The helper marks other translations `needs_review` when English or Norwegian changes. When editing source copy in Xcode, mark affected translations for review yourself. Run `python3 scripts/validate-localization.py` to check English/Norwegian completeness and compile both catalogs without writing generated source.

The API translator is adapted from Tidex and is reserved for when the app's copy is ready. Install its development dependencies with `bun install --frozen-lockfile`. Set `OPENAI_API_KEY` in the ignored root `.env.local` file; `OPENAI_MODEL` and `OPENAI_REASONING_EFFORT` optionally override the script's defaults. `bun run localize --dry-run` previews pending work without API requests or file changes. Later, explicitly run `bun run localize` to translate both catalogs and register the additional Xcode languages, or append a `.xcstrings` path to translate only that catalog. It preserves existing translations, validates placeholders and response IDs, and saves completed batches atomically so interrupted work can resume. `bun run localize:test` runs the regression tests with mocked API responses. Builds, tests and commits never trigger translation automatically.

`openingSoon` uses the real clock and opens an isolated window after 20 seconds to check foreground and background transitions. `progressReturn` uses a two-minute isolated window to inspect the ring catching up after time on another tab. `onboardingLiveClock` keeps onboarding storage and services isolated while using the real clock to check weekday dragging. The Reduce Motion UI test runs with that accessibility setting enabled on the test simulator.

## Ownership

- `ios/Shared`: pure schedule, reflection, merge, and snapshot contracts, plus Watch transport shared by the two apps.
- `ios/SharedUI`: semantic appearance tokens and small cross-surface SwiftUI components.
- `ios/SharedWidget`: the common timeline provider and widget presentation.
- `ios/KvilApp/Features`: Home, Schedule, History, Weight, Onboarding, Settings, Purchase.
- `ios/KvilApp/Storage`: the single SwiftData container and transactional local repository.
- `ios/KvilApp/Services`: UserNotifications, HealthKit, StoreKit, ActivityKit, App Intents, and iCloud schedule preferences.
- `ios/KvilApp/App`: composition, observable presentation state, lifecycle, and scenarios.

Dates are derived from wall-clock schedule values with a Gregorian calendar in the device time zone. Overnight windows belong to their opening day. Windows are half-open; an opening instant is open and a closing instant is closed. One engine supplies phone, Watch, reminders, and widget transitions. Weekly edits begin tomorrow; today's override is immediate. Days off are unrestricted local dates; a break's resume date is the first day using the usual schedule again. Overnight windows stop at the start of a day off. History reflects the person's answers, not inferred adherence.

## Data and integrations

Connecting Apple Health requests weight read and write access together. Save to Health turns on only when write access is granted and can be switched off in Settings. Existing local-only weights remain local.

SwiftData is local and explicitly disables automatic CloudKit mirroring. The protected local store and derived snapshots are excluded from automatic backup. Free JSON export/import supplies local-history recovery; imports validate before replacing any records.

Schedule synchronization uses native encrypted fields in the user's private CloudKit database. The payload includes weekly plans, days off, dated breaks, Home fasting-action adjustments, and retained schedule versions. Per-day timestamps merge edits, override/break tombstones preserve deletion, and a reset marker prevents erased schedules from reappearing from an offline device. Reflections, reported meal times, feelings, notes, and weights stay outside this payload. Apple Health owns weight synchronization. Legacy iCloud key-value data is read for migration; removal is requested after the encrypted save, and new payloads are not written to KVS. Account changes and detected remote deletion pause sync. The encrypted Production schema and signed export 2449.2.47 are verified; real two-device migration and APNs delivery remain outstanding. See [the migration evidence](release/CLOUDKIT_MIGRATION.md), [remaining runtime checks](release/CLOUDKIT_DEPLOYMENT.md), and [privacy findings](release/ICLOUD_PRIVACY_FINDINGS.md) for the separate policy question.

Opening/closing reminders use a rolling queue of about four weeks, renewed whenever the app runs. Schedule edits recalculate their selected advance timing, and days off suppress delivery. Background refresh is opportunistic. Settings exposes the scheduled-through date. There are no reflection notifications. The phone owns reminder delivery and normal Watch routing.

Live Activities are off by default. When enabled, Kvil can start one while the app is active and the next opening is within eight hours. They update as the app runs and show a refresh state when stale. There is no server push or guaranteed background start; widgets remain available for ongoing schedule access. Physical-device notification, Siri, and Live Activity behavior require separate verification from simulator and unit tests.

The Watch persists a validated schedule in its own App Group and calculates locally without the phone. WatchConnectivity transfers the latest configuration; App Groups do not transport data between devices. Widget countdowns are bounded and timelines include opening/closing transitions.

Product: `dev.hkarlsen06.kvil.history`, configured US price $3.99. Support: hjalmar@hkarlsen06.dev. Release materials are under `release/`; their existence does not imply upload or submission.

## Release preparation

Use the App scheme and Release configuration for signing and archives. Set `XCODE_BUILD_AGENT_ALLOW_PROVISIONING=1` to let the signed-in Xcode account manage profiles. `XCODE_BUILD_AGENT_ACTION=archive` creates `build/Kvil.xcarchive` by default. Archive/export does not upload to Apple.

App Store version 1.0.0 and Full History are in the same READY_FOR_REVIEW draft, with manual release selected. The app is free and the non-consumable Full History record is configured at US $3.99 with localized descriptions and territorial availability. The review contact and review notes are saved. Build 2446.23.21 has been uploaded, processed, and attached to the version; internal TestFlight reports READY_FOR_BETA_TESTING. All ten screenshots have processed successfully. Kvil’s [overview](https://hkarlsen06.dev/kvil/), [support](https://hkarlsen06.dev/kvil/support/), and [privacy](https://hkarlsen06.dev/kvil/privacy/) pages are live on the existing portfolio and saved in both App Store locales. The user accepted Apple’s privacy declaration and “Data Not Collected” is published. Apple’s listing checks pass, and the draft displays both items ready to submit. No App Review submission or public App Store release has occurred. See `release/READINESS.md` for completed checks and remaining release gates.

After an archive, run `./scripts/xcode-export-agent.sh` and `python3 scripts/verify-release.py`. The latter verifies all four distribution signatures, embedded profiles, minimum OS versions, localizations, privacy manifests, shared build numbers, and the absence of test resources. Neither command uploads the app.
