import XCTest

@testable import KvilApp

@MainActor final class OnboardingStorageTests: XCTestCase {
  func testSetupPersistsSelectedCloudPreferenceWithSchedule() throws {
    for previousChoice in [false, true] {
      for selectedChoice in [false, true] {
        let store = try LocalStore(inMemory: true)
        var initial = LocalData()
        initial.preferences.cloudScheduleEnabled = previousChoice
        try store.save(initial)
        let model = try AppModel(store: store, scenario: "onboarding")

        XCTAssertTrue(
          model.configure(days: DayPlan.initial, cloudScheduleEnabled: selectedChoice))
        XCTAssertTrue(model.isConfigured)
        XCTAssertEqual(model.data.preferences.cloudScheduleEnabled, selectedChoice)
        let saved = try store.load()
        XCTAssertEqual(saved, model.data)
        XCTAssertFalse(saved.schedule.versions.isEmpty)
        XCTAssertEqual(saved.preferences.cloudScheduleEnabled, selectedChoice)
      }
    }
  }

  func testInvalidSetupDoesNotPersistCloudChoiceOrSchedule() throws {
    for selectedChoice in [false, true] {
      let store = try LocalStore(inMemory: true)
      var initial = LocalData()
      initial.preferences.cloudScheduleEnabled = !selectedChoice
      try store.save(initial)
      let model = try AppModel(store: store, scenario: "onboarding")
      let before = model.data

      XCTAssertFalse(
        model.configure(
          days: Array(DayPlan.initial.dropLast()), cloudScheduleEnabled: selectedChoice))
      XCTAssertFalse(model.isConfigured)
      XCTAssertEqual(model.data, before)
      XCTAssertEqual(try store.load(), before)
    }
  }

  func testSetupWithoutNewChoicePreservesExistingSyncPreference() throws {
    let store = try LocalStore(inMemory: true)
    var initial = LocalData()
    initial.preferences.cloudScheduleEnabled = false
    try store.save(initial)
    let model = try AppModel(store: store, scenario: "onboarding")

    XCTAssertTrue(model.configure(days: DayPlan.initial))
    XCTAssertFalse(model.data.preferences.cloudScheduleEnabled)
    XCTAssertFalse(try store.load().preferences.cloudScheduleEnabled)
  }
}
