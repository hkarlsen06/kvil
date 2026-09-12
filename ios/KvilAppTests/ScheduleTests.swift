import XCTest

@testable import KvilApp

final class ScheduleTests: XCTestCase {
  let c = LocalDay.calendar(timeZone: TimeZone(identifier: "Europe/Oslo")!)
  func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
  func engine(_ days: [DayPlan] = DayPlan.initial, overrides: [DayOverride] = []) -> ScheduleEngine
  {
    ScheduleEngine(
      snapshot: ScheduleSnapshot(
        revision: date("2026-01-01T00:00:00Z"),
        versions: [ScheduleVersion(effectiveDay: "2025-01-01", days: days)], overrides: overrides),
      calendar: c)
  }
  func testExactOpeningAndClosingAreHalfOpen() throws {
    let e = engine()
    XCTAssertFalse(try XCTUnwrap(e.state(at: date("2026-09-12T07:59:59Z"))).isOpen)
    XCTAssertTrue(try XCTUnwrap(e.state(at: date("2026-09-12T08:00:00Z"))).isOpen)
    XCTAssertFalse(try XCTUnwrap(e.state(at: date("2026-09-12T16:00:00Z"))).isOpen)
  }
  func testCountdownUsesPreviousCloseAndNextOpening() throws {
    let now = date("2026-09-12T04:00:00Z")
    let s = try XCTUnwrap(engine().state(at: now))
    XCTAssertEqual(s.next.opening, date("2026-09-12T08:00:00Z"))
    XCTAssertEqual(s.previousClose, date("2026-09-11T16:00:00Z"))
    XCTAssertEqual(s.progress, 0.75, accuracy: 0.0001)
  }
  func testOvernightBelongsToOpeningDay() throws {
    let plans = (1...7).map { DayPlan(weekday: $0, opens: .init(hour: 20), closes: .init(hour: 4)) }
    let e = engine(plans)
    let now = date("2026-09-13T00:00:00Z")
    XCTAssertEqual(try XCTUnwrap(e.state(at: now)?.active).dayKey, "2026-09-12")
    XCTAssertTrue(e.eligibleReflections(at: now).isEmpty)
    XCTAssertEqual(
      e.eligibleReflections(at: date("2026-09-13T02:00:00Z")).map(\.dayKey), ["2026-09-12"])
  }
  func testEqualTimesAndOverlapRejected() throws {
    var days = DayPlan.initial
    days[0].closes = days[0].opens
    XCTAssertThrowsError(try ScheduleEngine.validate(days: days))
    days = DayPlan.initial
    days[0].opens = .init(hour: 22)
    days[0].closes = .init(hour: 11)
    XCTAssertThrowsError(try ScheduleEngine.validate(days: days)) {
      XCTAssertEqual($0 as? ScheduleError, .overlappingWindows)
    }
  }
  func testMissingOrDuplicateWeekdayRejected() {
    XCTAssertThrowsError(try ScheduleEngine.validate(days: Array(DayPlan.initial.dropLast())))
    var days = DayPlan.initial
    days[6].weekday = 1
    XCTAssertThrowsError(try ScheduleEngine.validate(days: days))
  }
  func testSundayToMondayAndYearBoundary() throws {
    var days = DayPlan.initial
    days[1].opens = .init(hour: 12)
    let next = try XCTUnwrap(engine(days).state(at: date("2026-09-13T17:00:00Z"))).next
    XCTAssertEqual(next.opening, date("2026-09-14T10:00:00Z"))
    XCTAssertEqual(engine().state(at: date("2026-12-31T22:00:00Z"))?.next.dayKey, "2027-01-01")
  }
  func testDSTGapMovesForwardAndRepeatedHourUsesFirstOccurrence() throws {
    let days = (1...7).map {
      DayPlan(weekday: $0, opens: .init(hour: 2, minute: 30), closes: .init(hour: 8))
    }
    let e = engine(days)
    XCTAssertEqual(
      e.window(on: date("2026-03-29T10:00:00Z"))?.opening, date("2026-03-29T01:00:00Z"))
    XCTAssertEqual(
      e.window(on: date("2026-10-25T10:00:00Z"))?.opening, date("2026-10-25T00:30:00Z"))
  }
  func testTodayOverrideExpiresWithoutChangingWeek() throws {
    let item = DayOverride(
      dayKey: "2026-09-12", timeZoneID: c.timeZone.identifier,
      opening: date("2026-09-12T10:00:00Z"), closing: date("2026-09-12T18:00:00Z"))
    let e = engine(overrides: [item])
    XCTAssertEqual(e.window(on: date("2026-09-12T12:00:00Z"))?.opening, item.opening)
    XCTAssertEqual(
      e.window(on: date("2026-09-13T12:00:00Z"))?.opening, date("2026-09-13T08:00:00Z"))
  }
  func testTravelOverrideKeepsAbsoluteBounds() throws {
    let item = DayOverride(
      dayKey: "2026-09-12", timeZoneID: c.timeZone.identifier,
      opening: date("2026-09-12T10:00:00Z"), closing: date("2026-09-12T18:00:00Z"))
    var e = engine(overrides: [item])
    e.calendar = LocalDay.calendar(timeZone: TimeZone(identifier: "America/New_York")!)
    XCTAssertEqual(e.state(at: date("2026-09-12T12:00:00Z"))?.active?.opening, item.opening)
  }
  func testUsualWeekEditDoesNotRewriteYesterday() throws {
    var e = engine()
    var new = DayPlan.initial
    for i in new.indices { new[i].opens = .init(hour: 12) }
    e.snapshot.versions.append(ScheduleVersion(effectiveDay: "2026-09-13", days: new))
    XCTAssertEqual(
      e.window(on: date("2026-09-12T12:00:00Z"))?.opening, date("2026-09-12T08:00:00Z"))
    XCTAssertEqual(
      e.window(on: date("2026-09-13T12:00:00Z"))?.opening, date("2026-09-13T10:00:00Z"))
  }
  func testReflectionExpiresAtEndOfFollowingDay() {
    let e = engine()
    XCTAssertTrue(
      e.eligibleReflections(at: date("2026-09-13T21:59:59Z")).contains { $0.dayKey == "2026-09-12" }
    )
    XCTAssertFalse(
      e.eligibleReflections(at: date("2026-09-13T22:00:00Z")).contains { $0.dayKey == "2026-09-12" }
    )
  }
  func testReminderPlanContainsOnlyFutureUniqueEventsWithinHorizon() {
    let now = date("2026-09-12T12:00:00Z")
    var preferences = Preferences()
    preferences.openingReminder = true
    preferences.closingReminder = true
    let plan = ReminderPlan.make(
      snapshot: engine().snapshot, preferences: preferences, now: now, calendar: c)
    XCTAssertFalse(plan.events.isEmpty)
    XCTAssertLessThanOrEqual(plan.events.count, 56)
    XCTAssertEqual(plan.events.count, Set(plan.events.map(\.id)).count)
    XCTAssertTrue(plan.events.allSatisfy { $0.date > now && $0.date <= plan.scheduledThrough })
    preferences.closingReminder = false
    XCTAssertTrue(
      ReminderPlan.make(
        snapshot: engine().snapshot, preferences: preferences, now: now, calendar: c
      ).events.allSatisfy(\.opening))
  }
  func testMalformedSnapshotCannotReplaceWidgetState() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = SnapshotStore(directory: folder)
    let good = engine().snapshot
    try store.write(good)
    var bad = good
    bad.schema = 99
    XCTAssertThrowsError(try store.write(bad))
    XCTAssertEqual(store.read(), good)
    var older = good
    older.revision = .distantPast
    older.versions[0].days[0].opens = .init(hour: 12)
    try store.write(older)
    XCTAssertEqual(store.read(), good)
  }
}
