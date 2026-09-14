import XCTest

@testable import KvilApp

final class ScheduleBreakTests: XCTestCase {
  private let oslo = LocalDay.calendar(timeZone: TimeZone(identifier: "Europe/Oslo")!)
  private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
  private func engine(days: [DayPlan] = DayPlan.initial) -> ScheduleEngine {
    let stamp = date("2026-01-01T00:00:00Z")
    let stamped = days.map { day in
      var result = day
      result.modifiedAt = stamp
      return result
    }
    return ScheduleEngine(
      snapshot: ScheduleSnapshot(
        revision: stamp,
        versions: [ScheduleVersion(effectiveDay: "2025-01-01", days: stamped, modifiedAt: stamp)],
        overrides: []), calendar: oslo)
  }

  func testRecurringDayOffIsUnrestrictedAndKeepsSavedTimes() throws {
    var days = DayPlan.initial
    days[6].dayOff = true  // Saturday.
    let e = engine(days: days)
    let now = date("2026-09-12T12:00:00Z")
    try e.validate(near: now)
    let state = try XCTUnwrap(e.state(at: now))
    XCTAssertTrue(state.isDayOff)
    XCTAssertFalse(state.isOpen)
    XCTAssertNil(state.active)
    XCTAssertNil(e.window(on: now))
    XCTAssertEqual(state.progress, 0)
    XCTAssertEqual(state.next?.opening, date("2026-09-13T08:00:00Z"))
    XCTAssertEqual(e.plan(on: now)?.opens.hour, 10)
    XCTAssertFalse(e.eligibleReflections(at: now).contains { $0.dayKey == "2026-09-12" })
    XCTAssertThrowsError(try e.settingEatingWindowOpen(true, at: now, modifiedAt: now))
  }

  func testAllWeekdaysOffHasValidStateWithoutInventingNextWindow() throws {
    let days = DayPlan.initial.map { day in
      var result = day
      result.dayOff = true
      return result
    }
    let e = engine(days: days)
    let now = date("2026-09-12T12:00:00Z")
    try e.validate(near: now)
    let state = try XCTUnwrap(e.state(at: now))
    XCTAssertTrue(state.isDayOff)
    XCTAssertNil(state.next)
    XCTAssertNil(state.resumesAt)
    XCTAssertTrue(e.windows(around: now).isEmpty)
  }

  func testLongBreakResumesAtChosenDateWithoutExtendingFastingProgress() throws {
    var e = engine()
    let now = date("2026-09-12T12:00:00Z")
    let versions = e.snapshot.versions
    e.snapshot = try e.takingBreak(
      from: now, resuming: date("2026-10-01T10:00:00Z"), at: now, modifiedAt: now)
    XCTAssertEqual(e.snapshot.versions, versions)
    XCTAssertEqual(e.state(at: now)?.next?.opening, date("2026-10-01T08:00:00Z"))
    XCTAssertEqual(e.state(at: now)?.resumesAt, date("2026-09-30T22:00:00Z"))
    XCTAssertTrue(try XCTUnwrap(e.state(at: date("2026-09-30T21:59:59Z"))).isDayOff)
    let resumed = try XCTUnwrap(e.state(at: date("2026-10-01T03:00:00Z")))
    XCTAssertFalse(resumed.isDayOff)
    XCTAssertEqual(resumed.previousClose, date("2026-09-30T22:00:00Z"))
    XCTAssertEqual(resumed.progress, 0.5, accuracy: 0.0001)
  }

  func testEveningBeforeWeekendOffDoesNotCountThroughUnrestrictedDays() throws {
    var days = DayPlan.initial
    days[0].dayOff = true
    days[6].dayOff = true
    let e = engine(days: days)
    let evening = date("2026-09-11T18:00:00Z")
    let state = try XCTUnwrap(e.state(at: evening))
    XCTAssertFalse(state.isDayOff)
    XCTAssertNil(state.active)
    XCTAssertEqual(state.next?.opening, date("2026-09-14T08:00:00Z"))
    XCTAssertEqual(state.upcomingDayOff, date("2026-09-11T22:00:00Z"))
    XCTAssertEqual(state.progress, 0)
    let beforeClose = try XCTUnwrap(e.state(at: date("2026-09-11T15:59:59Z")))
    XCTAssertTrue(beforeClose.isOpen)
    XCTAssertNil(beforeClose.upcomingDayOff)
    let dayOff = try XCTUnwrap(e.state(at: date("2026-09-11T22:00:00Z")))
    XCTAssertTrue(dayOff.isDayOff)
    XCTAssertNil(dayOff.upcomingDayOff)
    XCTAssertNil(e.state(at: date("2026-09-14T04:00:00Z"))?.upcomingDayOff)
  }

  func testUpcomingDatedBreakAndFutureAllOffWeekExposeMidnightBoundary() throws {
    var e = engine()
    let now = date("2026-09-12T18:00:00Z")
    e.snapshot = try e.takingBreak(
      from: date("2026-09-13T10:00:00Z"), resuming: date("2026-10-01T10:00:00Z"),
      at: now, modifiedAt: now)
    XCTAssertEqual(e.state(at: now)?.upcomingDayOff, date("2026-09-12T22:00:00Z"))
    XCTAssertEqual(e.state(at: now)?.progress, 0)
    e = engine()
    let allOff = DayPlan.initial.map { day in
      var result = day
      result.dayOff = true
      return result
    }
    e.snapshot.versions.append(ScheduleVersion(effectiveDay: "2026-09-13", days: allOff))
    let state = try XCTUnwrap(e.state(at: now))
    XCTAssertNil(state.next)
    XCTAssertEqual(state.upcomingDayOff, date("2026-09-12T22:00:00Z"))
    XCTAssertEqual(state.progress, 0)
  }

  func testDistantDayOffDoesNotHideAnEarlierScheduledOpening() throws {
    var e = engine()
    let now = date("2026-09-12T18:00:00Z")
    e.snapshot = try e.takingBreak(
      from: date("2026-09-15T10:00:00Z"), resuming: date("2026-09-16T10:00:00Z"),
      at: now, modifiedAt: now)
    XCTAssertNil(e.state(at: now)?.upcomingDayOff)
    XCTAssertGreaterThan(try XCTUnwrap(e.state(at: now)).progress, 0)
  }

  func testOvernightWindowStopsAtDayOffBoundaryAcrossDST() throws {
    for (openingDay, boundary, resumed) in [
      ("2026-03-28T12:00:00Z", "2026-03-28T23:00:00Z", "2026-03-29T22:00:00Z"),
      ("2026-10-24T12:00:00Z", "2026-10-24T22:00:00Z", "2026-10-25T23:00:00Z"),
    ] {
      let days = (1...7).map {
        DayPlan(weekday: $0, opens: .init(hour: 20), closes: .init(hour: 4))
      }
      var e = engine(days: days)
      let now = date(openingDay)
      e.snapshot = try e.takingBreak(
        from: date(boundary), resuming: date(resumed), at: now, modifiedAt: now)
      XCTAssertEqual(e.window(on: now)?.closing, date(boundary))
      XCTAssertTrue(try XCTUnwrap(e.state(at: date(boundary))).isDayOff)
      XCTAssertFalse(try XCTUnwrap(e.state(at: date(resumed))).isDayOff)
      XCTAssertNil(e.window(on: date(boundary)))
      try e.validate(near: now)
    }
  }

  func testDayOffDatesFollowLocalCalendarAfterTravelAndSuppressOldOverride() throws {
    var e = engine()
    let now = date("2026-09-12T12:00:00Z")
    e.snapshot.overrides = [
      DayOverride(
        dayKey: "2026-09-12", timeZoneID: oslo.timeZone.identifier,
        opening: date("2026-09-12T08:00:00Z"), closing: date("2026-09-12T16:00:00Z"))
    ]
    e.snapshot = try e.takingBreak(
      from: now, resuming: date("2026-09-13T10:00:00Z"), at: now, modifiedAt: now)
    e.calendar = LocalDay.calendar(timeZone: TimeZone(identifier: "America/New_York")!)
    XCTAssertTrue(try XCTUnwrap(e.state(at: date("2026-09-13T03:59:59Z"))).isDayOff)
    let resumed = try XCTUnwrap(e.state(at: date("2026-09-13T04:00:00Z")))
    XCTAssertFalse(resumed.isDayOff)
    XCTAssertEqual(resumed.next?.opening, date("2026-09-13T14:00:00Z"))
    XCTAssertNil(e.state(at: now)?.active)
    try e.validate(near: now)
  }

  func testNewYearResumeAndOverlappingBreaksUseUnion() throws {
    var e = engine()
    let now = date("2026-12-31T10:00:00Z")
    e.snapshot = try e.takingBreak(
      from: now, resuming: date("2027-01-02T10:00:00Z"), at: now, modifiedAt: now)
    e.snapshot = try e.takingBreak(
      from: date("2027-01-01T10:00:00Z"), resuming: date("2027-01-05T10:00:00Z"),
      at: now, modifiedAt: now)
    XCTAssertEqual(e.state(at: now)?.next?.dayKey, "2027-01-05")
    XCTAssertTrue(e.isDayOff(on: date("2027-01-02T10:00:00Z")))
    XCTAssertFalse(e.isDayOff(on: date("2027-01-05T10:00:00Z")))
  }

  func testEarlyResumePreservesPreviousOffDaysAndSurvivesOfflineMerge() throws {
    var e = engine()
    let start = date("2026-09-12T12:00:00Z")
    e.snapshot = try e.takingBreak(
      from: start, resuming: date("2026-09-20T12:00:00Z"), at: start, modifiedAt: start)
    let old = e.snapshot
    let now = date("2026-09-14T12:00:00Z")
    e.snapshot = try e.endingBreak(
      try XCTUnwrap(e.snapshot.breaks?.first).id, at: now, modifiedAt: now)
    let merged = try ScheduleMerge.merge(old, e.snapshot)
    XCTAssertEqual(try ScheduleMerge.merge(e.snapshot, old), merged)
    e.snapshot = merged
    XCTAssertTrue(e.isDayOff(on: start))
    XCTAssertFalse(e.isDayOff(on: now))
    XCTAssertEqual(e.snapshot.breaks?.first?.resumeDay, "2026-09-14")
  }

  func testCancelledFutureBreakUsesTombstoneAndResetCannotResurrectBreak() throws {
    var e = engine()
    let now = date("2026-09-12T12:00:00Z")
    e.snapshot = try e.takingBreak(
      from: date("2026-09-14T12:00:00Z"), resuming: date("2026-09-20T12:00:00Z"),
      at: now, modifiedAt: now)
    let old = e.snapshot
    let later = now.addingTimeInterval(60)
    e.snapshot = try e.endingBreak(
      try XCTUnwrap(e.snapshot.breaks?.first).id, at: now, modifiedAt: later)
    XCTAssertEqual(try ScheduleMerge.merge(old, e.snapshot).breaks?.first?.deleted, true)
    let erased = ScheduleSnapshot(revision: later, versions: [], overrides: [], resetAt: later)
    let merged = try ScheduleMerge.merge(old, erased)
    XCTAssertTrue(merged.versions.isEmpty)
    XCTAssertTrue(merged.breaks?.isEmpty ?? true)
  }

  func testConcurrentWeekdayOffAndTimeEditConverge() throws {
    var a = engine().snapshot
    var b = a
    let now = date("2026-09-12T12:00:00Z")
    a.versions[0].days[6].dayOff = true
    a.versions[0].days[6].modifiedAt = now
    b.versions[0].days[1].opens = .init(hour: 12)
    b.versions[0].days[1].modifiedAt = now
    let merged = try ScheduleMerge.merge(a, b)
    XCTAssertEqual(try ScheduleMerge.merge(b, a), merged)
    XCTAssertTrue(merged.versions[0].days[6].isDayOff)
    XCTAssertEqual(merged.versions[0].days[1].opens.hour, 12)
  }

  func testEquivalentOptionalDeletionFlagsConvergeAtEqualTimestamps() throws {
    var a = engine().snapshot
    let now = date("2026-09-12T12:00:00Z")
    a.breaks = [ScheduleBreak(startDay: "2026-09-13", resumeDay: "2026-09-14", modifiedAt: now)]
    a.overrides = [
      DayOverride(
        dayKey: "2026-09-12", timeZoneID: oslo.timeZone.identifier,
        opening: date("2026-09-12T10:00:00Z"), closing: date("2026-09-12T18:00:00Z"),
        modifiedAt: now)
    ]
    var b = a
    b.breaks?[0].deleted = false
    b.overrides[0].deleted = false
    XCTAssertEqual(try ScheduleMerge.merge(a, b), try ScheduleMerge.merge(b, a))
  }

  func testLegacySchemaDecodesButCannotPretendToUnderstandDayOffData() throws {
    let encoder = JSONEncoder()
    var original = engine().snapshot
    original.schema = 1
    let legacy = try JSONDecoder().decode(ScheduleSnapshot.self, from: encoder.encode(original))
    XCTAssertNil(legacy.breaks)
    XCTAssertTrue(legacy.versions.flatMap(\.days).allSatisfy { $0.dayOff == nil })
    XCTAssertNoThrow(try ScheduleEngine(snapshot: legacy, calendar: oslo).validate(near: Date()))
    var invalid = legacy
    invalid.versions[0].days[0].dayOff = true
    XCTAssertThrowsError(
      try ScheduleEngine(snapshot: invalid, calendar: oslo).validate(near: Date()))
    invalid.schema = 2
    XCTAssertNoThrow(try ScheduleEngine(snapshot: invalid, calendar: oslo).validate(near: Date()))
    let roundtrip = try JSONDecoder().decode(ScheduleSnapshot.self, from: encoder.encode(invalid))
    XCTAssertEqual(roundtrip, invalid)
  }

  func testMalformedBreakAndDuplicateIdentityAreRejected() throws {
    var e = engine()
    let now = date("2026-09-12T12:00:00Z")
    XCTAssertThrowsError(try e.takingBreak(from: now, resuming: now, at: now, modifiedAt: now))
    XCTAssertThrowsError(
      try e.takingBreak(
        from: now.addingTimeInterval(-86400), resuming: now, at: now, modifiedAt: now))
    e.snapshot.breaks = [
      ScheduleBreak(startDay: "2026-02-30", resumeDay: "2026-03-01", modifiedAt: now)
    ]
    XCTAssertThrowsError(try e.validate(near: now))
    let item = ScheduleBreak(startDay: "2026-09-12", resumeDay: "2026-09-13", modifiedAt: now)
    e.snapshot.breaks = [item, item]
    XCTAssertThrowsError(try e.validate(near: now))
    e.snapshot.versions = []
    e.snapshot.breaks = [item]
    XCTAssertThrowsError(try e.validate(near: now))
  }

  @MainActor func testBreakRoundTripsLocalStoreAndBackup() throws {
    var data = LocalData()
    var e = engine()
    let now = date("2026-09-12T12:00:00Z")
    e.snapshot = try e.takingBreak(
      from: now, resuming: date("2026-09-15T12:00:00Z"), at: now, modifiedAt: now)
    data.schedule = e.snapshot
    let store = try LocalStore(inMemory: true)
    try store.save(data)
    XCTAssertEqual(try store.load().schedule, data.schedule)
    let encoded = try JSONEncoder().encode(data)
    let decoded = try JSONDecoder().decode(LocalData.self, from: encoded).validated(now: now)
    XCTAssertEqual(decoded.schedule.breaks, data.schedule.breaks)
  }

  @MainActor func testUsualWeekOffEditStartsTomorrowAndCanRestoreSavedTimes() throws {
    let model = try AppModel(store: LocalStore(inMemory: true), scenario: "closed")
    let weekday = model.calendar.component(.weekday, from: model.now)
    let original = try XCTUnwrap(model.usualDays.first { $0.weekday == weekday })
    var off = original
    off.dayOff = true
    XCTAssertTrue(model.saveWeekDay(off, replacing: original))
    XCTAssertFalse(model.engine.isDayOff(on: model.now))
    let followingWeek = try XCTUnwrap(model.calendar.date(byAdding: .day, value: 7, to: model.now))
    XCTAssertTrue(model.engine.isDayOff(on: followingWeek))
    let saved = try XCTUnwrap(model.usualDays.first { $0.weekday == weekday })
    var restored = saved
    restored.dayOff = false
    XCTAssertTrue(model.saveWeekDay(restored, replacing: saved))
    XCTAssertFalse(model.engine.isDayOff(on: followingWeek))
    XCTAssertEqual(model.engine.plan(on: followingWeek)?.opens, original.opens)
    XCTAssertEqual(model.engine.plan(on: followingWeek)?.closes, original.closes)
    // An editor opened before the day-off change cannot silently override that change.
    XCTAssertTrue(model.saveWeekDay(off, replacing: restored))
    var stale = original
    stale.opens = .init(hour: 11)
    XCTAssertFalse(model.saveWeekDay(stale, replacing: original))
  }
}
