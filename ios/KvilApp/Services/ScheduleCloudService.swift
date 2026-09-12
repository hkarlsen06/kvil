import Foundation
import Observation

@MainActor @Observable final class ScheduleCloudService {
  enum Status { case off, waiting, enabled, unavailable, needsAttention }
  private(set) var status: Status = .waiting
  private let store: NSUbiquitousKeyValueStore
  private let key = "schedule.v1"
  private var observer: NSObjectProtocol?
  var onChange: (() -> Void)?
  var onAccountChange: (() -> Void)?
  init(store: NSUbiquitousKeyValueStore = .default, enabled: Bool) {
    self.store = store
    guard enabled else {
      status = .off
      return
    }
    observer = NotificationCenter.default.addObserver(
      forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: store,
      queue: .main
    ) { [weak self] note in
      let reason = note.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int
      Task { @MainActor in
        guard let self else { return }
        if reason == NSUbiquitousKeyValueStoreAccountChange {
          self.status = .off
          self.onAccountChange?()
        } else if reason == NSUbiquitousKeyValueStoreQuotaViolationChange {
          self.status = .needsAttention
        } else {
          self.onChange?()
        }
      }
    }
  }
  isolated deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
  func sync(_ local: ScheduleSnapshot, enabled: Bool) throws -> ScheduleSnapshot {
    guard enabled else {
      status = .off
      return local
    }
    guard FileManager.default.ubiquityIdentityToken != nil else {
      status = .unavailable
      return local
    }
    store.synchronize()
    var result = local
    if let bytes = store.data(forKey: key) {
      guard bytes.count < 900_000 else {
        status = .needsAttention
        throw ScheduleError.incompatibleData
      }
      do {
        result = try ScheduleMerge.merge(
          local, JSONDecoder().decode(ScheduleSnapshot.self, from: bytes))
      } catch {
        status = .needsAttention
        throw error
      }
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    let bytes = try encoder.encode(result)
    guard bytes.count < 900_000 else {
      status = .needsAttention
      throw ScheduleError.incompatibleData
    }
    // An enabled state means submitted to the system, not proof of server delivery.
    if store.data(forKey: key) != bytes {
      store.set(bytes, forKey: key)
      store.synchronize()
    }
    status = .enabled
    return result
  }
}
