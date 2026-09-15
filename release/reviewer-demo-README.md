# Reviewer history fixture

[reviewer-demo.json](reviewer-demo.json) contains fictional data for reviewing Full History without waiting weeks. It is a local release asset and has **not been attached or uploaded** to App Store Connect.

Use `.json`: `BackupDocument` and the Settings file picker accept `UTType.json`. The app does not register a `.kvilbackup` type.

## Contents

- One weekly 08:00–20:00 schedule with a unique UUID, effective 4 August 2026.
- 42 fictional daily reflections, 4 August–14 September 2026, in `Europe/Oslo`. Each note identifies it as a fictional reviewer entry.
- No weights, Health anchor, meal timestamps, dated schedule overrides, or breaks.
- iCloud sync, both reminders, Live Activities, weight logging, Health reads, and Health writes are explicitly disabled. Local Watch/widget schedule snapshots have no separate preference in the backup format.

The fixture uses the production encoder's default date format. Its anchor is 15 September 2026 at 00:00 UTC; no reflection timestamp is later than the anchor. It does not grant a purchase entitlement or bypass StoreKit.

## Import and review

1. Use a clean test installation. Import replaces local app data; export anything worth keeping first. Complete guided setup if necessary and leave iCloud sync off.

   Import preserves the device's existing iCloud choice. The fixture's disabled flag does not turn off sync on a device where it is already enabled.
2. Save `reviewer-demo.json` in Files. In Kvil, open Schedule or History, then Settings > Your data > Restore from a backup. Select the file and confirm Replace.
3. Before purchasing, History shows the latest seven days only. On 15 September the weekly recap has seven answers: two comfortable, two mixed, three difficult.
4. Open History > Explore full history and test the native purchase in the appropriate Apple test environment. After unlock, choose Month for 30 answers or All time for all 42. All time has 14 answers in each feeling category. Open an older reflection to check editing.
5. Test Restore Purchases using an eligible test purchase. Importing the fixture alone cannot establish restore eligibility.

Week and Month follow the device's current date, so their counts change after 15 September. All time retains all 42 entries. Refresh and revalidate the fixture before packaging if populated recent recaps are required on a later review date; do not ask reviewers to change the device clock.

## Packaging

Include the fixture and these directions in the reviewer materials only after confirming how the file will be delivered. Then add the actual attachment name or verified download location to the review notes. The current review notes do not promise that Apple already has the file.

The fixture needs no weight or Health authorization. Do not use it to test writes to a person's Health store.

## Validation record

Validated on 15 September 2026 using the unchanged production Codable models, `LocalData.validated(now:)`, `Recap.recent`, and an in-memory `LocalStore` with CloudKit disabled. The fixture decoded, normalized, and survived a SwiftData save/load unchanged. No app build, persistent store, or external integration was used.

The local audit harness and output are in the ignored `build/reviewer-fixture/` directory. Commands run from the repository root:

```sh
xcrun swiftc -parse-as-library \
  ios/Shared/Schedule.swift ios/Shared/ScheduleBreak.swift \
  ios/Shared/Reflection.swift ios/KvilApp/Storage/LocalStore.swift \
  build/reviewer-fixture/ReviewerDemo.swift \
  -o build/reviewer-fixture/reviewer-demo
build/reviewer-fixture/reviewer-demo
```

Result:

```text
Production validation and JSON / in-memory SwiftData round-trips: passed
Bytes: 13962; schedule versions: 1; reflections: 42; weights: 0
Recap 7 days: 7 answers, comfortable=2, mixed=2, difficult=3
Recap 30 days: 30 answers, comfortable=10, mixed=10, difficult=10
Recap 36500 days: 42 answers, comfortable=14, mixed=14, difficult=14
```

SHA-256: `6f0b6c0e015312d069257b17e402be2c146fcf29d670e6de7a64397ea3a8085c`.
