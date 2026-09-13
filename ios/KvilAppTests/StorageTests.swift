import XCTest

@testable import KvilApp

@MainActor final class StorageTests: XCTestCase {
  func fixture() -> LocalData {
    try! ScenarioData.make(
      now: ISO8601DateFormatter().date(from: "2026-09-12T06:15:00Z")!,
      calendar: LocalDay.calendar(timeZone: TimeZone(identifier: "Europe/Oslo")!)
    ).validated()
  }
  func testStoreRoundTripAndInvalidWritePreservesPreviousData() throws {
    let store = try LocalStore(inMemory: true)
    let data = fixture()
    try store.save(data)
    XCTAssertEqual(try store.load(), data)
    var invalid = data
    invalid.schedule.versions[0].days.removeLast()
    XCTAssertThrowsError(try store.save(invalid))
    XCTAssertEqual(try store.load(), data)
  }
  func testManualWindowActionsPersistAndMergeWithoutChangingPersonalData() throws {
    let model = try AppModel(store: LocalStore(inMemory: true), scenario: "home")
    let original = model.data
    XCTAssertTrue(model.setEatingWindowOpen(true))
    XCTAssertTrue(try XCTUnwrap(model.engine.state(at: model.now)).isOpen)
    XCTAssertEqual(try model.store.load(), model.data)
    XCTAssertEqual(try ScheduleMerge.merge(original.schedule, model.data.schedule), model.data.schedule)
    let open = model.data.schedule
    XCTAssertTrue(model.setEatingWindowOpen(false))
    XCTAssertFalse(try XCTUnwrap(model.engine.state(at: model.now)).isOpen)
    XCTAssertEqual(try model.store.load(), model.data)
    XCTAssertEqual(try ScheduleMerge.merge(open, model.data.schedule), model.data.schedule)
    let closed = model.data.schedule
    XCTAssertTrue(model.undoEarlyBreak())
    let reloaded = try model.store.load()
    let restored = ScheduleEngine(snapshot: reloaded.schedule, calendar: model.calendar)
    XCTAssertEqual(reloaded, model.data)
    XCTAssertNil(restored.earlyBreak(at: model.now))
    XCTAssertFalse(try XCTUnwrap(restored.state(at: model.now)).isOpen)
    XCTAssertEqual(
      restored.state(at: model.now)?.next.opening,
      ScheduleEngine(snapshot: original.schedule, calendar: model.calendar)
        .state(at: model.now)?.next.opening)
    XCTAssertEqual(try ScheduleMerge.merge(open, reloaded.schedule), reloaded.schedule)
    XCTAssertEqual(try ScheduleMerge.merge(reloaded.schedule, closed), reloaded.schedule)
    XCTAssertEqual(model.data.reflections, original.reflections)
    XCTAssertEqual(model.data.weights, original.weights)
    XCTAssertEqual(model.data.schedule.versions, original.schedule.versions)
  }
  func testPersistentStoreReopensWithoutLoss() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let data = fixture()
    do {
      let first = try LocalStore(directory: folder)
      try first.save(data)
    }
    let reopened = try LocalStore(directory: folder)
    XCTAssertEqual(try reopened.load(), data)
  }
  func testWeeklyTimeChangesPersistFromTomorrowAndRejectOverlapAtomically() throws {
    let model = try AppModel(store: LocalStore(inMemory: true), scenario: "home")
    let original = model.data
    let today = try XCTUnwrap(model.engine.window(on: model.now))
    let tomorrow = try XCTUnwrap(model.calendar.date(byAdding: .day, value: 1, to: model.now))
    let weekday = model.calendar.component(.weekday, from: tomorrow)
    var days = try XCTUnwrap(original.schedule.versions.last).days
    let index = try XCTUnwrap(days.firstIndex { $0.weekday == weekday })
    days[index].opens = WallTime(hour: 22, minute: 15)
    days[index].closes = WallTime(hour: 6, minute: 45)
    XCTAssertTrue(model.saveWeek(days))
    XCTAssertEqual(model.engine.window(on: model.now), today)
    XCTAssertEqual(model.engine.plan(on: tomorrow)?.opens, days[index].opens)
    XCTAssertEqual(model.engine.plan(on: tomorrow)?.closes, days[index].closes)
    XCTAssertEqual(try model.store.load(), model.data)
    XCTAssertEqual(try ScheduleMerge.merge(original.schedule, model.data.schedule), model.data.schedule)

    for day in days.indices {
      days[day].opens = days[index].opens
      days[day].closes = days[index].closes
    }
    XCTAssertTrue(model.saveWeek(days))
    XCTAssertEqual(model.engine.window(on: model.now), today)
    XCTAssertTrue(try XCTUnwrap(model.data.schedule.versions.last).days.allSatisfy {
      $0.opens == WallTime(hour: 22, minute: 15) && $0.closes == WallTime(hour: 6, minute: 45)
    })
    let saved = model.data
    days[index].closes = days[index].opens
    XCTAssertFalse(model.saveWeek(days))
    XCTAssertEqual(model.data, saved)
    XCTAssertEqual(try model.store.load(), saved)
    days[index].closes = WallTime(hour: 23)
    days[index].opens = WallTime(hour: 5)
    XCTAssertFalse(model.saveWeek(days))
    XCTAssertEqual(model.data, saved)
    XCTAssertEqual(try model.store.load(), saved)
  }
  func testExportRoundTripAndMalformedImport() throws {
    let data = fixture()
    let encoded = try JSONEncoder().encode(data)
    XCTAssertEqual(try JSONDecoder().decode(LocalData.self, from: encoded).validated(), data)
    var bad = data
    bad.formatVersion = 999
    XCTAssertThrowsError(try bad.validated())
    bad = data
    bad.reflections.append(data.reflections[0])
    XCTAssertThrowsError(try bad.validated())
  }
  func testWeightUnitConversionAndInvalidValues() {
    XCTAssertEqual(WeightUnit.lb.kilograms(WeightUnit.lb.display(83.2)), 83.2, accuracy: 0.00001)
    for value in [Double.nan, .infinity, -1, 0, 1001] {
      XCTAssertFalse(WeightEntry(kilograms: value, date: Date()).isValid)
    }
    XCTAssertTrue(WeightEntry(kilograms: 83.2, date: Date()).isValid)
  }
  func testRecapExcludesMissingDaysAndToday() {
    let data = fixture()
    let now = ISO8601DateFormatter().date(from: "2026-09-12T06:15:00Z")!
    let recap = Recap.recent(data.reflections, days: 7, now: now, calendar: .current)
    XCTAssertEqual(recap.answerCount, 6)
    XCTAssertEqual(DayFeeling.allCases.reduce(0) { $0 + recap.count($1) }, 6)
  }
  func testRestoreDoesNotWriteToHealthOrEnableNotifications() throws {
    let model = try AppModel(store: LocalStore(inMemory: true), scenario: "onboarding")
    var data = fixture()
    data.preferences.healthEnabled = true
    data.preferences.healthWritesEnabled = true
    data.preferences.openingReminder = true
    data.weights = [WeightEntry(kilograms: 75, date: model.now, saveToHealth: true)]
    XCTAssertTrue(model.restore(data))
    XCTAssertFalse(model.data.preferences.healthEnabled)
    XCTAssertFalse(model.data.preferences.openingReminder)
    XCTAssertFalse(model.data.weights[0].saveToHealth)
  }
}
