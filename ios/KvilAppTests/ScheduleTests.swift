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
    XCTAssertEqual(try XCTUnwrap(s.next).opening, date("2026-09-12T08:00:00Z"))
    XCTAssertEqual(s.previousClose, date("2026-09-11T16:00:00Z"))
    XCTAssertEqual(s.progress, 0.75, accuracy: 0.0001)
  }
  func testOpenWindowProgressDrainsUntilClosingAcrossDateBoundaries() throws {
    let overnight = engine(
      (1...7).map { DayPlan(weekday: $0, opens: .init(hour: 20), closes: .init(hour: 4)) })
    let cases: [(ScheduleEngine, String, String, String)] = [
      (engine(), "2026-09-12T08:00:00Z", "2026-09-12T12:00:00Z", "2026-09-12T16:00:00Z"),
      (overnight, "2026-12-31T19:00:00Z", "2026-12-31T23:00:00Z", "2027-01-01T03:00:00Z"),
      (overnight, "2026-03-28T19:00:00Z", "2026-03-28T22:30:00Z", "2026-03-29T02:00:00Z"),
      (overnight, "2026-10-24T18:00:00Z", "2026-10-24T22:30:00Z", "2026-10-25T03:00:00Z"),
    ]
    for (engine, opening, midpoint, closing) in cases {
      XCTAssertEqual(try XCTUnwrap(engine.state(at: date(opening))).progress, 1)
      XCTAssertEqual(
        try XCTUnwrap(engine.state(at: date(midpoint))).progress, 0.5, accuracy: 0.0001)
      let beforeClose = try XCTUnwrap(engine.state(at: date(closing).addingTimeInterval(-1)))
      XCTAssertTrue(beforeClose.isOpen)
      XCTAssertGreaterThan(beforeClose.progress, 0)
      XCTAssertLessThan(beforeClose.progress, 0.0001)
      let closed = try XCTUnwrap(engine.state(at: date(closing)))
      XCTAssertFalse(closed.isOpen)
      XCTAssertEqual(closed.progress, 0)
    }
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
    let next = try XCTUnwrap(engine(days).state(at: date("2026-09-13T17:00:00Z"))?.next)
    XCTAssertEqual(next.opening, date("2026-09-14T10:00:00Z"))
    XCTAssertEqual(engine().state(at: date("2026-12-31T22:00:00Z"))?.next?.dayKey, "2027-01-01")
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
  func testBreakFastEarlyKeepsClosingAndUsualWeek() throws {
    var e = engine()
    let original = e.snapshot
    let now = date("2026-09-12T04:03:27Z")
    e.snapshot = try e.settingEatingWindowOpen(true, at: now, modifiedAt: now)
    let active = try XCTUnwrap(e.state(at: now)?.active)
    XCTAssertEqual(active.opening, now)
    XCTAssertEqual(active.closing, date("2026-09-12T16:00:00Z"))
    XCTAssertEqual(e.state(at: now)?.progress, 1)
    let midpoint = now.addingTimeInterval(active.closing.timeIntervalSince(now) / 2)
    XCTAssertEqual(try XCTUnwrap(e.state(at: midpoint)).progress, 0.5, accuracy: 0.0001)
    XCTAssertEqual(e.snapshot.versions, original.versions)
    XCTAssertFalse(try XCTUnwrap(e.state(at: active.closing)).isOpen)
    XCTAssertEqual(e.state(at: active.closing)?.next?.opening, date("2026-09-13T08:00:00Z"))
    XCTAssertEqual(try e.settingEatingWindowOpen(true, at: now, modifiedAt: now), e.snapshot)
  }
  func testStartFastNowKeepsNextOpeningAndUpdatesReminders() throws {
    var e = engine()
    let now = date("2026-09-12T12:15:43Z")
    e.snapshot = try e.settingEatingWindowOpen(false, at: now, modifiedAt: now)
    let state = try XCTUnwrap(e.state(at: now))
    XCTAssertFalse(state.isOpen)
    XCTAssertEqual(state.previousClose, now)
    XCTAssertEqual(state.progress, 0)
    XCTAssertEqual(try XCTUnwrap(state.next).opening, date("2026-09-13T08:00:00Z"))
    var preferences = Preferences()
    preferences.openingReminder = true
    preferences.closingReminder = true
    let events = ReminderPlan.make(
      snapshot: e.snapshot, preferences: preferences, now: now, calendar: c
    ).events
    XCTAssertFalse(events.contains { $0.date == date("2026-09-12T16:00:00Z") })
    XCTAssertEqual(events.first?.date, try XCTUnwrap(state.next).opening)
  }
  func testUndoEarlyBreakRestoresScheduleUntilExactOpeningAcrossDateBoundaries() throws {
    for value in [
      "2026-09-12T06:00:00Z", "2026-12-31T22:30:00Z",
      "2026-03-28T20:30:00Z", "2026-10-24T20:30:00Z",
    ] {
      var e = engine()
      let now = date(value)
      let original = try XCTUnwrap(e.state(at: now))
      XCTAssertNil(e.earlyBreak(at: now))
      e.snapshot = try e.settingEatingWindowOpen(true, at: now, modifiedAt: now)
      let broken = e.snapshot
      let plannedOpening = try XCTUnwrap(original.next).opening
      let beforeOpening = plannedOpening.addingTimeInterval(-1)
      XCTAssertNotNil(e.earlyBreak(at: now))
      XCTAssertNotNil(e.earlyBreak(at: beforeOpening))
      XCTAssertNil(e.earlyBreak(at: plannedOpening))
      XCTAssertNil(e.earlyBreak(at: plannedOpening.addingTimeInterval(1)))
      XCTAssertEqual(
        try e.undoingEarlyBreak(at: plannedOpening, modifiedAt: plannedOpening),
        broken)
      e.snapshot = try e.undoingEarlyBreak(at: beforeOpening, modifiedAt: beforeOpening)
      let restored = try XCTUnwrap(e.state(at: beforeOpening))
      XCTAssertFalse(restored.isOpen)
      XCTAssertNil(e.earlyBreak(at: beforeOpening))
      XCTAssertEqual(restored.previousClose, original.previousClose)
      XCTAssertEqual(restored.next, original.next)
      XCTAssertEqual(e.snapshot.versions, broken.versions)
      XCTAssertTrue(try XCTUnwrap(e.state(at: plannedOpening)).isOpen)
      var preferences = Preferences()
      preferences.openingReminder = true
      XCTAssertEqual(
        ReminderPlan.make(
          snapshot: e.snapshot, preferences: preferences, now: beforeOpening, calendar: c
        ).events.first?.date, plannedOpening)
    }
  }
  func testUndoEarlyBreakPreservesCustomWindowAfterClosingAndTravel() throws {
    let item = DayOverride(
      dayKey: "2026-09-12", timeZoneID: c.timeZone.identifier,
      opening: date("2026-09-12T10:00:00Z"), closing: date("2026-09-12T18:00:00Z"))
    var e = engine(overrides: [item])
    let now = date("2026-09-12T06:00:00Z")
    e.snapshot = try e.settingEatingWindowOpen(true, at: now, modifiedAt: now)
    let stopped = now.addingTimeInterval(60)
    e.snapshot = try e.settingEatingWindowOpen(false, at: stopped, modifiedAt: stopped)
    e.calendar = LocalDay.calendar(timeZone: TimeZone(identifier: "America/New_York")!)
    let undoTime = stopped.addingTimeInterval(60)
    XCTAssertNotNil(e.earlyBreak(at: undoTime))
    e.snapshot = try e.undoingEarlyBreak(at: undoTime, modifiedAt: undoTime)
    XCTAssertEqual(e.state(at: undoTime)?.next, item.window)
    XCTAssertNil(e.earlyBreak(at: undoTime))
    let restored = e.snapshot
    XCTAssertEqual(try e.undoingEarlyBreak(at: undoTime, modifiedAt: undoTime), restored)
    let afterOpening = item.opening.addingTimeInterval(60)
    e.snapshot = try e.settingEatingWindowOpen(false, at: afterOpening, modifiedAt: afterOpening)
    e.snapshot = try e.settingEatingWindowOpen(true, at: afterOpening, modifiedAt: afterOpening)
    XCTAssertNil(e.earlyBreak(at: afterOpening))
  }
  func testBreakFastAfterClosingCrossesMidnightAndYearBoundary() throws {
    for value in ["2026-09-13T20:00:00Z", "2026-12-31T22:30:00Z"] {
      var e = engine()
      let now = date(value)
      let planned = try XCTUnwrap(e.state(at: now)?.next)
      e.snapshot = try e.settingEatingWindowOpen(true, at: now, modifiedAt: now)
      let active = try XCTUnwrap(e.state(at: now)?.active)
      XCTAssertEqual(active.opening, now)
      XCTAssertEqual(active.closing, planned.closing)
      XCTAssertEqual(active.dayKey, planned.dayKey)
      XCTAssertTrue(try XCTUnwrap(e.state(at: planned.opening)).isOpen)
      XCTAssertFalse(try XCTUnwrap(e.state(at: planned.closing)).isOpen)
    }
  }
  func testStartFastInOvernightWindowAdjustsItsOpeningDay() throws {
    let days = (1...7).map { DayPlan(weekday: $0, opens: .init(hour: 20), closes: .init(hour: 4)) }
    var e = engine(days)
    let now = date("2026-09-13T00:00:00Z")
    e.snapshot = try e.settingEatingWindowOpen(false, at: now, modifiedAt: now)
    XCTAssertEqual(e.snapshot.overrides.first?.dayKey, "2026-09-12")
    XCTAssertEqual(e.state(at: now)?.previousClose, now)
    XCTAssertEqual(e.state(at: now)?.next?.opening, date("2026-09-13T18:00:00Z"))
  }
  func testImmediateStartAndReopenAtOpeningDoesNotCreateReflectionOrLoseClosing() throws {
    for value in ["2026-09-12T08:00:00Z", "2026-09-12T04:03:27Z"] {
      var e = engine()
      let now = date(value)
      e.snapshot = try e.settingEatingWindowOpen(true, at: now, modifiedAt: now)
      e.snapshot = try e.settingEatingWindowOpen(false, at: now, modifiedAt: now)
      XCTAssertFalse(try XCTUnwrap(e.state(at: now)).isOpen)
      XCTAssertEqual(e.state(at: now)?.previousClose, now)
      XCTAssertFalse(e.eligibleReflections(at: now).contains { $0.dayKey == "2026-09-12" })
      e.snapshot = try e.settingEatingWindowOpen(true, at: now, modifiedAt: now)
      XCTAssertEqual(e.state(at: now)?.active?.closing, date("2026-09-12T16:00:00Z"))
    }
  }
  func testManualAdjustmentsKeepAbsoluteTimesAcrossDSTAndTravel() throws {
    var e = engine()
    let now = date("2026-10-24T20:30:00Z")
    e.snapshot = try e.settingEatingWindowOpen(true, at: now, modifiedAt: now)
    XCTAssertEqual(e.state(at: now)?.active?.closing, date("2026-10-25T17:00:00Z"))
    e.calendar = LocalDay.calendar(timeZone: TimeZone(identifier: "America/New_York")!)
    try e.validate(near: now)
    XCTAssertEqual(e.state(at: now)?.active?.opening, now)
    let stop = now.addingTimeInterval(3600)
    e.snapshot = try e.settingEatingWindowOpen(false, at: stop, modifiedAt: stop)
    XCTAssertFalse(try XCTUnwrap(e.state(at: stop)).isOpen)
    XCTAssertEqual(e.state(at: stop)?.previousClose, stop)
  }
  func testInvalidManualAdjustmentsAreRejected() throws {
    let now = date("2026-09-12T06:00:00Z")
    var e = engine()
    e.snapshot = try e.settingEatingWindowOpen(true, at: now, modifiedAt: now)
    var bad = e
    bad.snapshot.overrides[0].adjustedOpening = date("2026-09-10T06:00:00Z")
    XCTAssertThrowsError(try bad.validate(near: now))
    bad = e
    bad.snapshot.overrides[0].adjustedClosing = now.addingTimeInterval(-1)
    XCTAssertThrowsError(try bad.validate(near: now))
    bad = e
    bad.snapshot.overrides[0].adjustedClosing = date("2026-09-12T17:00:00Z")
    XCTAssertThrowsError(try bad.validate(near: now))
    bad = e
    bad.snapshot.overrides[0].adjustedOpening = date("2026-09-11T15:00:00Z")
    XCTAssertThrowsError(try bad.validate(near: now))
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
