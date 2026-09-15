import CloudKit
import Foundation

// This is the complete cloud boundary. Reflections, weight, Health identifiers and
// preferences cannot enter it because only ScheduleSnapshot is accepted.
enum ScheduleCloudPayload {
  static func encode(_ snapshot: ScheduleSnapshot) throws -> Data {
    try ScheduleEngine(snapshot: snapshot, calendar: LocalDay.calendar()).validate(near: Date())
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    let bytes = try encoder.encode(snapshot)
    guard bytes.count < 900_000 else { throw ScheduleError.incompatibleData }
    return bytes
  }

  static func decode(_ bytes: Data) throws -> ScheduleSnapshot {
    guard bytes.count < 900_000 else { throw ScheduleError.incompatibleData }
    let snapshot = try JSONDecoder().decode(ScheduleSnapshot.self, from: bytes)
    _ = try encode(snapshot)
    return snapshot
  }

  @MainActor static func read(_ record: CKRecord) throws -> ScheduleSnapshot {
    guard record.recordID == CloudKitScheduleClient.recordID,
      record.recordType == CloudKitScheduleClient.recordType,
      Set(record.allKeys()) == ["payload"],
      Set(record.encryptedValues.allKeys()) == ["payload"],
      let bytes = record.encryptedValues["payload"] as? Data
    else { throw ScheduleError.incompatibleData }
    return try decode(bytes)
  }

  static func write(_ snapshot: ScheduleSnapshot, to record: CKRecord) throws {
    guard Set(record.allKeys()).subtracting(record.encryptedValues.allKeys()).isEmpty,
      Set(record.encryptedValues.allKeys()).isSubset(of: ["payload"])
    else { throw ScheduleError.incompatibleData }
    record.encryptedValues["payload"] = try encode(snapshot)
  }
}

struct ScheduleCloudState: Codable, Equatable {
  var format = 1
  var ownerID: String?
  // Saved before provisioning so a crash between creating the zone and saving
  // its first record can finish safely on the next launch.
  var zoneCreated = false
  var recordSaved = false
  var pause: ScheduleCloudService.PauseReason?
  var recoveringReset = false
  var ignoreLegacy = false
  var recreateAllowed = false
}

@MainActor protocol ScheduleCloudStateStore {
  func load() throws -> ScheduleCloudState
  func save(_ state: ScheduleCloudState) throws
}

@MainActor final class FileScheduleCloudStateStore: ScheduleCloudStateStore {
  private let url: URL
  init(directory: URL) { url = directory.appendingPathComponent("schedule-cloud-state.json") }

  func load() throws -> ScheduleCloudState {
    guard FileManager.default.fileExists(atPath: url.path) else { return ScheduleCloudState() }
    let state = try JSONDecoder().decode(ScheduleCloudState.self, from: Data(contentsOf: url))
    guard state.format == 1, state.ownerID?.isEmpty != true,
      !state.recordSaved || (state.zoneCreated && state.ownerID != nil),
      !state.recoveringReset || state.ownerID != nil
    else { throw ScheduleError.incompatibleData }
    return state
  }

  func save(_ state: ScheduleCloudState) throws {
    try JSONEncoder().encode(state).write(
      to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    var location = url
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try location.setResourceValues(values)
  }
}

@MainActor protocol LegacyScheduleAccess {
  func read() -> Data?
  @discardableResult func remove(ifUnchanged bytes: Data) -> Bool
}

@MainActor final class LegacyScheduleStore: LegacyScheduleAccess {
  private let store = NSUbiquitousKeyValueStore.default
  private let key = "schedule.v1"
  func read() -> Data? {
    store.synchronize()
    return store.data(forKey: key)
  }
  func remove(ifUnchanged bytes: Data) -> Bool {
    guard store.data(forKey: key) == bytes else { return false }
    store.removeObject(forKey: key)
    store.synchronize()
    return true
  }
}

// CloudKit often wraps the useful zone/record error in partialFailure. Never
// interpret mere presence of the encrypted-reset key as a true reset flag.
enum ScheduleCloudErrors {
  static func items(_ error: Error) -> [CKError] {
    guard let cloud = error as? CKError else { return [] }
    let children = (cloud.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error]) ?? [:]
    return [cloud] + children.values.flatMap { items($0) }
  }
  static func contains(_ code: CKError.Code, in error: Error) -> Bool {
    items(error).contains { $0.code == code }
  }
  static func encryptedReset(_ error: Error) -> Bool {
    !contains(.userDeletedZone, in: error)
      && items(error).contains {
        $0.code == .zoneNotFound
          && ($0.userInfo[CKErrorUserDidResetEncryptedDataKey] as? NSNumber)?.boolValue == true
      }
  }
  static func retryDelay(_ error: Error) -> TimeInterval? {
    let errors = items(error)
    let delays = errors.compactMap { ($0.userInfo[CKErrorRetryAfterKey] as? NSNumber)?.doubleValue }
      .filter { $0.isFinite && $0 >= 0 }
    if let delay = delays.max() { return max(1, delay) }
    return errors.contains {
      [
        .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited,
        .zoneBusy,
      ].contains($0.code)
    } ? 5 : nil
  }
}
