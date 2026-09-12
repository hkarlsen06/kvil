# Kvil MVP

Kvil helps adults keep a flexible eating rhythm without turning their day into a score. Weight logging is optional and secondary. The first release is native iPhone and Apple Watch, requiring iOS 27 and watchOS 27.

## Product decisions

- A separate eating window for each weekday, with an adjustment just for today. Weekly changes begin tomorrow; past plans remain interpretable.
- The schedule runs automatically. There is no start/stop action, completed fast, adherence estimate, streak, or weight target.
- Home shows a large countdown inside a 270-degree arc with the bottom open. At opening, the countdown gives way to a calm open-window message and its time range.
- Optional opening and closing reminders. The phone schedules roughly four weeks ahead and renews them whenever the app runs; background refresh is opportunistic. Settings shows the queued horizon.
- After a window closes and during the following day, an optional Home reflection asks how that day felt. No reflection notification. A recap counts answers without inferring missing days.
- Optional weight logging, editing, deletion, a recent chart, and kilograms or pounds. HealthKit body-mass reading and writing are separate opt-ins. Failed writes and deletions remain retryable.
- The Watch receives and persists the schedule, calculates offline, and can request a refresh. Widgets cover small/medium Home Screen and inline/circular/rectangular Lock Screen families; Watch complications use the accessory families.
- No Kvil account. Only planned schedule settings use iCloud key-value sync. Reflections stay local with free JSON export/import. Apple Health owns weight synchronization. Apple has not provided an app-specific determination about schedule settings under its health-data iCloud rule.
- Free core timer, schedules, reminders, complete artwork, weight, Health, Watch, and widgets. The latest seven days of reflection history and a basic recap are free. One non-consumable purchase unlocks older reflections and longer recaps.
- Intended US price: $3.99, matching the requested roughly four dollars. Product identifier: `dev.hkarlsen06.kvil.history`.
- Support: hjalmar@hkarlsen06.dev. English and Norwegian Bokmål are included.

## Design

Warm ivory, muted green, generous space, serif headings, and quiet native controls. Painted Nordic landscapes appear on Home, onboarding, history, and the purchase screen. iPhone follows system appearance with corresponding night artwork. The Watch uses the night palette so its timer sits clearly with the native Watch clock.

Home, Schedule, and History are the three tabs. Settings is a consistent trailing toolbar action. Weight stays inside History and can be hidden. There is no weight-loss imagery or progress pressure. Dynamic Type uses vertical layouts where needed and preserves readable text instead of squeezing it into the decorative timer arc.

## Architecture

The structure follows the sibling Tidex and Paeonia conventions: feature-first SwiftUI, Observation, initializer injection, shared semantic components, and native frameworks. There are no third-party dependencies.

- `ios/Shared` owns schedule and reflection values, validation, date calculations, merge rules, compact snapshots, weight reconciliation, and Watch transport.
- `ios/SharedUI` owns semantic colors, type, timer arc, artwork placement, and small reusable controls.
- `ios/SharedWidget` owns one timeline provider and widget views for both platforms.
- `ios/KvilApp/Storage` owns the protected local SwiftData container and transactional repository. Automatic CloudKit mirroring is disabled.
- `ios/KvilApp/Services` owns HealthKit, UserNotifications, StoreKit, and iCloud schedule preferences.
- `ios/KvilApp/App` composes dependencies and coordinates persistence and derived device state.
- `ios/KvilApp/Features` contains Home, Schedule, History, Weight, Onboarding, Settings, and Purchase.

Wall-clock windows use a Gregorian calendar in the current device time zone. Overnight windows belong to their opening day. Intervals include their opening instant and exclude their closing instant. All surfaces share the engine. Invalid schedules and imported data are rejected before replacing persistent state.

Schedule sync merges per-day edits, keeps override tombstones, and carries a reset marker. WatchConnectivity transports snapshots between devices; App Groups share state only within a device. Reflections and weights never enter the schedule payload. Health writes preserve a stable identity and incremented version so retries do not duplicate a measurement.

## Implementation and release sequence

The native targets, artwork, localization, persistence, integrations, core flows, unit tests, UI tests, and public-page source have been implemented. The first complete Xcode 27 RC run passed 36 tests. A signed Release build installed and launched on the developer iPhone. These checks are evidence of development progress, not an App Store approval.

Small-phone and 42-mm Watch layouts have been inspected, and small/medium Home Screen widgets have rendered in the system host. A distribution archive has been exported and its four signatures verified. Native store screenshots and purchase review media are prepared, and the review contact is saved. Lock Screen widgets, Watch complications, real-device permission behavior, and device propagation still need separate checks. Public support/privacy URLs and media/build uploads remain release gates. TestFlight upload, App Review submission, and public release are distinct actions. `release/READINESS.md` records the evidence and outstanding work.

See `release/metadata.json` for the store copy and `release/privacy.md` for the data policy. Build and test wrappers emit a final JSON result. Never treat an in-progress build, a local fixture, or a draft listing as a completed release.
