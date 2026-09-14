import UserNotifications
import XCTest

@testable import KvilApp

@MainActor final class ReminderPresentationTests: XCTestCase {
  func testReminderTapSurvivesColdLaunchAndEachTapHasANewPresentation() {
    let delegate = KvilAppDelegate()
    delegate.receiveReminder(identifier: "unrelated", action: UNNotificationDefaultActionIdentifier)
    XCTAssertNil(delegate.reminderResponse)
    delegate.receiveReminder(identifier: "kvil.open.123", action: UNNotificationDismissActionIdentifier)
    XCTAssertNil(delegate.reminderResponse)
    delegate.receiveReminder(identifier: "kvil.open.123", action: UNNotificationDefaultActionIdentifier)
    let pending = delegate.reminderResponse
    XCTAssertNotNil(pending)
    delegate.receiveReminder(identifier: "kvil.close.456", action: UNNotificationDefaultActionIdentifier)
    XCTAssertNotEqual(delegate.reminderResponse, pending)
  }

  func testPresentingHomeLeavesTheScheduleAndPersonalDataUntouched() throws {
    let model = try AppModel(store: LocalStore(inMemory: true), scenario: "home")
    let original = model.data
    model.selectedTab = .history
    model.presentHome()
    XCTAssertEqual(model.selectedTab, .home)
    model.presentHome()
    XCTAssertEqual(model.selectedTab, .home)
    XCTAssertEqual(model.data, original)
  }
}
