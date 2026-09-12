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
