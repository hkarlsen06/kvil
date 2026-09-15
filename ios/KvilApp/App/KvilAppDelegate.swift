import CloudKit
import Observation
import UIKit
import UserNotifications

@MainActor @Observable
final class KvilAppDelegate: NSObject, UIApplicationDelegate,
  UNUserNotificationCenterDelegate
{
  private(set) var reminderResponse: UUID?
  private var model: AppModel?

  // The scene and cold-launch pushes share one model and SwiftData context.
  func loadModel() throws -> AppModel {
    if let model { return model }
    var scenario: String?
    #if DEBUG
      scenario = ProcessInfo.processInfo.environment["KVIL_SCENARIO"]
      if scenario == nil
        && ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
      {
        scenario = "onboarding"
      }
    #endif
    let loaded = try AppModel(store: LocalStore(inMemory: scenario != nil), scenario: scenario)
    model = loaded
    if scenario == nil { UIApplication.shared.registerForRemoteNotifications() }
    return loaded
  }

  func application(
    _ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo),
      notification.subscriptionID == CloudKitScheduleClient.subscriptionID
    else {
      completionHandler(.noData)
      return
    }
    var completed = false
    var syncGeneration: Int?
    var work: Task<Void, Never>?
    let deadline = Task { @MainActor in
      do { try await Task.sleep(for: .seconds(25)) } catch { return }
      guard !completed else { return }
      completed = true
      if let syncGeneration { model?.cloud.cancelPendingWork(generation: syncGeneration) }
      work?.cancel()
      completionHandler(.failed)
    }
    work = Task { @MainActor in
      let result: UIBackgroundFetchResult
      do {
        let loaded = try loadModel()
        syncGeneration = loaded.cloud.workGeneration
        let changed = await loaded.syncSchedule()
        switch loaded.cloud.status {
        case .off, .enabled: result = changed ? .newData : .noData
        case .waiting, .unavailable, .needsAttention: result = .failed
        }
      } catch { result = .failed }
      guard !completed else { return }
      completed = true
      deadline.cancel()
      completionHandler(result)
    }
  }

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
