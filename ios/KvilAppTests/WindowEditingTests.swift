import XCTest

@testable import KvilApp

@MainActor final class WindowEditingTests: XCTestCase {
  func testTodayEditsPersistWithoutChangingTheWeekAndRejectStaleWindows() throws {
    let model = try AppModel(store: LocalStore(inMemory: true), scenario: "home")
    let original = model.data
    let today = try XCTUnwrap(model.engine.window(on: model.now))
    XCTAssertTrue(
      model.saveToday(opens: .init(hour: 13), closes: .init(hour: 19), replacing: today))
    XCTAssertEqual(model.data.schedule.versions, original.schedule.versions)
    XCTAssertEqual(model.data.reflections, original.reflections)
    XCTAssertEqual(model.data.weights, original.weights)
    XCTAssertEqual(try model.store.load(), model.data)
    let moved = try XCTUnwrap(model.engine.window(on: model.now))
    XCTAssertEqual(model.calendar.component(.hour, from: moved.opening), 13)
    XCTAssertEqual(model.calendar.component(.hour, from: moved.closing), 19)
    let saved = model.data
    XCTAssertFalse(
      model.saveToday(opens: .init(hour: 14), closes: .init(hour: 20), replacing: today))
    XCTAssertFalse(
      model.saveToday(opens: .init(hour: 22), closes: .init(hour: 11), replacing: moved))
    var previousDay = moved
    previousDay.dayKey = LocalDay.key(
      model.calendar.date(byAdding: .day, value: -1, to: model.now)!, calendar: model.calendar)
    XCTAssertFalse(
      model.saveToday(opens: .init(hour: 13), closes: .init(hour: 17), replacing: previousDay))
    XCTAssertEqual(model.data, saved)
    XCTAssertEqual(try model.store.load(), saved)
    XCTAssertTrue(model.saveToday(opens: .init(hour: 22), closes: .init(hour: 4), replacing: moved))
    let overnight = try XCTUnwrap(model.engine.window(on: model.now))
    XCTAssertFalse(model.calendar.isDate(overnight.opening, inSameDayAs: overnight.closing))
    XCTAssertTrue(model.removeTodayOverride())
    XCTAssertEqual(model.engine.window(on: model.now), today)
    XCTAssertEqual(model.data.schedule.versions, original.schedule.versions)
  }

  func testMovingWrapsBothDirectionsAndPreservesFractionalLength() throws {
    let day = DayPlan(
      weekday: 1, opens: .init(hour: 10, minute: 15), closes: .init(hour: 18, minute: 45))
    let moved = day.shifted(by: -735)
    XCTAssertEqual(moved.opens, WallTime(hour: 22))
    XCTAssertEqual(moved.closes, WallTime(hour: 6, minute: 30))
    XCTAssertEqual(moved.windowMinutes, 510)
    XCTAssertTrue(moved.overnight)
    XCTAssertEqual(moved.shifted(by: 735), day)
    XCTAssertEqual(day.shifted(by: 1440 * 3), day)
    for delta in [Int.min, Int.max] {
      XCTAssertTrue(day.shifted(by: delta).opens.isValid)
      XCTAssertEqual(day.shifted(by: delta).windowMinutes, day.windowMinutes)
    }
    let resized = try moved.resized(to: 450)
    XCTAssertEqual(resized.opens, moved.opens)
    XCTAssertEqual(resized.closes, WallTime(hour: 5, minute: 30))
    for length in [-1, 0, 1440, 1441] {
      XCTAssertThrowsError(try day.resized(to: length))
    }
  }

  func testLengthForAllDaysKeepsOpeningsAndPersistsFromTomorrow() throws {
    let model = try AppModel(store: LocalStore(inMemory: true), scenario: "home")
    let original = model.data
    let today = model.engine.window(on: model.now)
    let sunday = model.usualDays[0]
    XCTAssertTrue(model.saveWeekDay(sunday.shifted(by: 120), replacing: sunday))
    XCTAssertTrue(model.setWindowLength(360, weekday: 1))
    XCTAssertEqual(model.usualDays[0].windowMinutes, 360)
    XCTAssertEqual(model.usualDays[1].windowMinutes, 480)
    let openings = model.usualDays.map(\.opens)
    XCTAssertTrue(model.setWindowLength(450))
    XCTAssertEqual(model.usualDays.map(\.opens), openings)
    XCTAssertTrue(model.usualDays.allSatisfy { $0.windowMinutes == 450 })
    XCTAssertEqual(model.engine.window(on: model.now), today)
    XCTAssertEqual(try model.store.load(), model.data)
    XCTAssertEqual(
      try ScheduleMerge.merge(original.schedule, model.data.schedule), model.data.schedule)
    XCTAssertEqual(model.data.reflections, original.reflections)
    XCTAssertEqual(model.data.weights, original.weights)
  }

  func testOverlapAndInvalidBulkEditsLeaveEverySavedDayIntact() throws {
    let model = try AppModel(store: LocalStore(inMemory: true), scenario: "home")
    let day = model.usualDays[0]
    XCTAssertTrue(model.saveWeekDay(day.shifted(by: 720), replacing: day))
    let saved = model.data
    XCTAssertFalse(model.setWindowLength(780))
    XCTAssertEqual(model.data, saved)
    XCTAssertEqual(try model.store.load(), saved)
    XCTAssertFalse(model.setWindowLength(0))
    XCTAssertFalse(model.setWindowLength(1440))
    XCTAssertFalse(model.setWindowLength(360, weekday: 99))
    XCTAssertEqual(model.data, saved)
  }

  func testDragMergesOtherWeekdaysAndRejectsAStaleSameDay() throws {
    let model = try AppModel(store: LocalStore(inMemory: true), scenario: "home")
    let first = model.usualDays[0]
    let second = model.usualDays[1]
    XCTAssertTrue(model.saveWeekDay(second.shifted(by: 60), replacing: second))
    XCTAssertTrue(model.saveWeekDay(first.shifted(by: 15), replacing: first))
    XCTAssertEqual(model.usualDays[1].opens, second.shifted(by: 60).opens)
    let saved = model.data
    XCTAssertFalse(model.saveWeekDay(first.shifted(by: 30), replacing: first))
    XCTAssertEqual(model.data, saved)
    XCTAssertEqual(try model.store.load(), saved)
  }

  func testMovedWindowsKeepTheEnginesDSTPolicy() throws {
    let calendar = LocalDay.calendar(timeZone: TimeZone(identifier: "Europe/Oslo")!)
    let days = (1...7).map {
      DayPlan(weekday: $0, opens: .init(hour: 0, minute: 30), closes: .init(hour: 6, minute: 30))
        .shifted(by: 120)
    }
    let engine = ScheduleEngine(
      snapshot: ScheduleSnapshot(
        revision: .distantPast,
        versions: [ScheduleVersion(effectiveDay: "2026-01-01", days: days)], overrides: []),
      calendar: calendar)
    let formatter = ISO8601DateFormatter()
    let spring = try XCTUnwrap(engine.window(on: formatter.date(from: "2026-03-29T10:00:00Z")!))
    let autumn = try XCTUnwrap(engine.window(on: formatter.date(from: "2026-10-25T10:00:00Z")!))
    XCTAssertEqual(spring.opening, formatter.date(from: "2026-03-29T01:00:00Z"))
    XCTAssertEqual(autumn.opening, formatter.date(from: "2026-10-25T00:30:00Z"))
    XCTAssertEqual(spring.closing.timeIntervalSince(spring.opening), 5.5 * 3600)
    XCTAssertEqual(autumn.closing.timeIntervalSince(autumn.opening), 7 * 3600)
  }
}
