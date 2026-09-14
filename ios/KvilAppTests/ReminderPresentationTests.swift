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
    XCTAssertNil(model.homePresentationID)
    model.selectedTab = .history
    model.presentHome()
    XCTAssertEqual(model.selectedTab, .home)
    let firstPresentation = try XCTUnwrap(model.homePresentationID)
    // A second link while already on Home must still replay the landscape reveal.
    model.presentHome()
    XCTAssertEqual(model.selectedTab, .home)
    XCTAssertNotEqual(model.homePresentationID, firstPresentation)
    XCTAssertEqual(model.data, original)
  }
}
