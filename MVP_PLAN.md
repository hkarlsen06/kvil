# Kvil MVP

Kvil helps adults keep a flexible eating rhythm without turning their day into a score. Weight logging is optional and secondary. The first release is native iPhone and Apple Watch. The iOS 27 and watchOS 27 minimums are retained after the market review.

## Product decisions

- Guided setup offers explained 12:12, 14:10, and 16:8 examples plus Custom, meal-based time choices, and a week preview before saving. The practical guide stays available in Settings. Examples do not prescribe a health outcome or advance automatically.
- A separate eating window or day off for each weekday, with an adjustment just for today. Dated breaks have a clear resume date and retain the usual week. Weekly changes begin tomorrow; past plans remain interpretable.
- The schedule runs automatically. Home's early-break and start-fasting actions adjust the current window without recording completed fasts. There is no inferred adherence, streak, or weight target.
- Home shows a large countdown inside a 270-degree arc with the bottom open. At opening, the countdown gives way to a calm open-window message and its time range.
- Optional opening and closing reminders, each at the boundary or 15 or 30 minutes before it. The phone schedules roughly four weeks ahead, excludes days off, and renews the queue whenever the app runs; background refresh is opportunistic. Settings shows the queued horizon.
- Home offers an optional reflection about yesterday once that day's window has closed. A sheet reveals one relevant step at a time: plan experience, optional approximate first/last meal times for changed or uncertain days, then feeling and an optional note. A day off skips the plan question. Cancel saves nothing; “As planned” never substitutes scheduled times for actual meals. History keeps the dated plan, reported answers, and notes together. No reflection notifications or inferred answers for missing days.
- Optional weight logging, editing, deletion, a recent chart, and kilograms or pounds. Connecting Health requests body-mass read and write authorization together; the user chooses what to allow and can disable future writes separately. Failed writes and deletions remain retryable.
- The Watch receives and persists the schedule, calculates offline, and can request a refresh. Widgets cover small/medium Home Screen and inline/circular/rectangular Lock Screen families; Watch complications use the accessory families.
- Optional Live Activities show the wait until opening on the Lock Screen and Dynamic Island. They start while Kvil is active and opening is within eight hours; background start and continuous all-day coverage are not guaranteed. Siri/Shortcuts can report the next opening or open Plan.
- No Kvil account. Schedule settings, days off, breaks, Home fasting-action adjustments, and retained plan history use encrypted fields in the user's private CloudKit database. Legacy KVS remains only for migration and cleanup. Reflections, reported meal times, notes, and weights stay outside the schedule payload, with free JSON export/import for local recovery. Apple Health owns weight synchronization. Apple has not provided an app-specific determination under its health-data iCloud rule; encrypted transport does not establish a policy exception.
- Free core timer, schedules, reminders, complete artwork, weight, Health, Watch, widgets, Live Activities, and Shortcuts. The latest seven days of reflection history and a basic recap are free. One non-consumable purchase unlocks older reflections and longer recaps.
- Intended US price: $3.99, matching the requested roughly four dollars. Product identifier: `dev.hkarlsen06.kvil.history`.
- Support: hjalmar@hkarlsen06.dev. English and Norwegian Bokmål are included.

## Design

Warm ivory, muted green, generous space, serif headings, and quiet native controls. Licensed Rice Lake photography appears in onboarding, secondary screens, and illustrated widgets. Home uses a landscape drawn in code; Schedule and History retain plain backgrounds. iPhone follows system appearance. The Watch uses the night palette so its timer sits clearly with the native Watch clock.

Home, Plan, and History are the three tabs. Settings is available from Plan and History. When weight logging is enabled, Home's trailing action opens the shared weight editor; weight history remains in History. There is no weight-loss imagery or progress pressure. Dynamic Type uses vertical layouts where needed and preserves readable text instead of squeezing it into the decorative timer arc. Reflections always use a sheet with progressive disclosure.

## Architecture

The structure follows the sibling Tidex and Paeonia conventions: feature-first SwiftUI, Observation, initializer injection, shared semantic components, and native frameworks. There are no third-party dependencies.

- `ios/Shared` owns schedule and reflection values, validation, date calculations, merge rules, compact snapshots, weight reconciliation, and Watch transport.
- `ios/SharedUI` owns semantic colors, type, timer arc, artwork placement, and small reusable controls.
- `ios/SharedWidget` owns one timeline provider and widget views for both platforms.
- `ios/KvilApp/Storage` owns the protected local SwiftData container and transactional repository. Automatic CloudKit mirroring is disabled.
- `ios/KvilApp/Services` owns HealthKit, UserNotifications, StoreKit, ActivityKit, App Intents, and iCloud schedule preferences.
- `ios/KvilApp/App` composes dependencies and coordinates persistence and derived device state.
- `ios/KvilApp/Features` contains Home, Schedule, History, Weight, Onboarding, Settings, and Purchase.

Wall-clock windows use a Gregorian calendar in the current device time zone. Overnight windows belong to their opening day and stop at a day-off boundary. Intervals include their opening instant and exclude their closing instant. Breaks follow local dates, with the resume date excluded from the break. All surfaces share the engine. Invalid schedules, reported meal dates, oversized notes, and imported data are rejected before replacing persistent state.

Schedule sync merges per-day edits, keeps override and break tombstones, and carries a reset marker. WatchConnectivity transports snapshots between devices; App Groups share state only within a device. Reflections and weights never enter the schedule payload. Health writes preserve a stable identity and incremented version so retries do not duplicate a measurement.

## Implementation and release sequence

The native targets, artwork, localization, persistence, integrations, core flows, unit tests, UI tests, and public-page source have been implemented. The first complete Xcode 27 RC run passed 36 tests. A signed Release build installed and launched on the developer iPhone. These checks are evidence of development progress, not an App Store approval.

Small-phone and 42-mm Watch layouts have been inspected, and small/medium Home Screen widgets have rendered in the system host. A distribution archive has been exported and its four signatures verified. Native store screenshots and purchase review media are prepared, and the review contact is saved. Lock Screen widgets, Watch complications, real-device permission behavior, and device propagation still need separate checks. Public support/privacy URLs and media/build uploads remain release gates. TestFlight upload, App Review submission, and public release are distinct actions. `release/READINESS.md` records the evidence and outstanding work.

See `release/metadata.json` for the store copy and `release/privacy.md` for the data policy. Build and test wrappers emit a final JSON result. Never treat an in-progress build, a local fixture, or a draft listing as a completed release.
