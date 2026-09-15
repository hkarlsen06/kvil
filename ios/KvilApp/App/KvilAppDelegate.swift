import Observation
import UIKit
import UserNotifications

@MainActor @Observable final class KvilAppDelegate: NSObject, UIApplicationDelegate,
  UNUserNotificationCenterDelegate
{
  private(set) var reminderResponse: UUID?

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return true
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping @Sendable () -> Void
  ) {
    let identifier = response.notification.request.identifier
    let action = response.actionIdentifier
    // UIKit's launch completion must also run on main; the async delegate bridge can finish off-main.
    Task { @MainActor in
      receiveReminder(identifier: identifier, action: action)
      completionHandler()
    }
  }

  func receiveReminder(identifier: String, action: String) {
    guard action == UNNotificationDefaultActionIdentifier,
      identifier.hasPrefix("kvil.open.") || identifier.hasPrefix("kvil.close.")
    else { return }
    // Retain a cold-launch response until RootView and its model are ready.
    reminderResponse = UUID()
  }
}
