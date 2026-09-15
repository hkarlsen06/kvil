import UserNotifications
import XCTest

@testable import KvilApp

@MainActor final class ReminderPresentationTests: XCTestCase {
  func testNotificationCallbackCompletesOnMainThreadAfterRetainingColdLaunchResponse() async throws {
    let delegate = KvilAppDelegate()
    let completed = expectation(description: "Notification response completed")
    completed.assertForOverFulfill = true

    try await Task.detached {
      let response = try Self.notificationResponse()
      // Exercise the Objective-C completion-handler entry point used by iOS.
      let notificationDelegate: any UNUserNotificationCenterDelegate = delegate
      notificationDelegate.userNotificationCenter?(
        .current(), didReceive: response,
        withCompletionHandler: {
          XCTAssertTrue(Thread.isMainThread, "UIKit's launch completion must run on the main thread")
          if Thread.isMainThread {
            MainActor.assumeIsolated {
              XCTAssertNotNil(delegate.reminderResponse, "Retain the route before completing launch")
            }
          }
          completed.fulfill()
        })
    }.value

    await fulfillment(of: [completed], timeout: 5)
    XCTAssertNotNil(delegate.reminderResponse)
  }

  private nonisolated static func notificationResponse() throws -> UNNotificationResponse {
    // These system types expose NSSecureCoding initializers, but no public value initializers.
    let notificationArchive = NSKeyedArchiver(requiringSecureCoding: true)
    notificationArchive.encode(
      UNNotificationRequest(
        identifier: "kvil.open.123", content: UNMutableNotificationContent(), trigger: nil),
      forKey: "request")
    notificationArchive.encode(Date(), forKey: "date")
    let notificationCoder = try NSKeyedUnarchiver(forReadingFrom: notificationArchive.encodedData)
    let notification = try XCTUnwrap(UNNotification(coder: notificationCoder))
    let responseArchive = NSKeyedArchiver(requiringSecureCoding: true)
    responseArchive.encode(notification, forKey: "notification")
    responseArchive.encode(UNNotificationDefaultActionIdentifier, forKey: "actionIdentifier")
    let responseCoder = try NSKeyedUnarchiver(forReadingFrom: responseArchive.encodedData)
    return try XCTUnwrap(UNNotificationResponse(coder: responseCoder))
  }

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
