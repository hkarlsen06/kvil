import CloudKit
import Foundation
import Observation

@MainActor @Observable final class ScheduleCloudService {
  enum Status { case off, waiting, enabled, unavailable, needsAttention }
  enum PauseReason: String, Codable { case accountChanged, remoteDeleted, encryptedReset }
  private(set) var status: Status = .off
  var currentSnapshot: (() -> ScheduleSnapshot)?
  var acceptSnapshot: ((ScheduleSnapshot) -> Bool)?
  var onPause: ((PauseReason) -> Void)?

  private let client: (any ScheduleCloudClient)?
  private let legacy: (any LegacyScheduleAccess)?
  private let stateStore: (any ScheduleCloudStateStore)?
  private var state = ScheduleCloudState()
  private var stateLoadFailed = false
  private var observers: [NSObjectProtocol] = []
  private var task: Task<Void, Never>?
  private var retryTask: Task<Void, Never>?
  private var retryNotBefore = Date.distantPast
  private var retryCount = 0
  private var generation = 0
  private var requested = false
  private var enabled = false
  private var subscribed = false
  private var accountUnavailable = false

  // Isolated scenarios do not even construct CKContainer or the legacy store.
  init(directory: URL?) {
    guard let directory else {
      client = nil
      legacy = nil
      stateStore = nil
      return
    }
    client = CloudKitScheduleClient()
    legacy = LegacyScheduleStore()
    stateStore = FileScheduleCloudStateStore(directory: directory)
    loadState()
    observeAccountsAndLegacyChanges()
  }

  init(
    client: any ScheduleCloudClient, legacy: any LegacyScheduleAccess,
    stateStore: any ScheduleCloudStateStore
  ) {
    self.client = client
    self.legacy = legacy
    self.stateStore = stateStore
    loadState()
  }

  isolated deinit {
    task?.cancel()
    retryTask?.cancel()
    for observer in observers { NotificationCenter.default.removeObserver(observer) }
  }

  private func loadState() {
    do { state = try stateStore?.load() ?? ScheduleCloudState() } catch {
      stateLoadFailed = true
      status = .needsAttention
    }
  }

  private func observeAccountsAndLegacyChanges() {
    for name in [
      Notification.Name.CKAccountChanged,
      NSUbiquitousKeyValueStore.didChangeExternallyNotification,
    ] {
      observers.append(
        NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) {
          [weak self] note in
          let accountChanged =
            note.name == .CKAccountChanged
            || (note.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int)
              == NSUbiquitousKeyValueStoreAccountChange
          Task { @MainActor in
            guard let self else { return }
            if accountChanged {
              self.accountDidChange()
            } else {
              self.requestSync(enabled: self.enabled)
            }
          }
        })
    }
  }

  func accountDidChange() {
    accountUnavailable = false
    invalidatePendingWork()
    // A notification also accompanies transient changes. Compare the current
    // owner before publishing; never treat the notification alone as consent.
    requestSync(enabled: enabled)
  }

  var workGeneration: Int { generation }

  func cancelPendingWork(generation token: Int) {
    if token == generation { invalidatePendingWork() }
  }

  func invalidatePendingWork() {
    generation += 1
    task?.cancel()
    task = nil
    retryTask?.cancel()
    retryTask = nil
    requested = false
    subscribed = false
  }

  // Called only after the user explicitly turns sync back on in Settings.
  func resume() throws {
    guard !stateLoadFailed else { throw ScheduleError.incompatibleData }
    invalidatePendingWork()
    if state.pause != nil {
      var next = ScheduleCloudState()
      // KVS may still expose a cached value from the previous account. An
      // explicit restart publishes the retained local schedule, never that cache.
      next.ignoreLegacy = true
      next.recreateAllowed = true
      try persist(next)
    }
    retryCount = 0
  }

  func requestSync(enabled: Bool) {
    self.enabled = enabled
    guard enabled, client != nil else {
      invalidatePendingWork()
      status = .off
      return
    }
    guard !stateLoadFailed else {
      status = .needsAttention
      return
    }
    guard !accountUnavailable else {
      status = .unavailable
      return
    }
    if let pause = state.pause {
      status = .off
      onPause?(pause)
      return
    }
    requested = true
    guard task == nil else { return }
    guard Date() >= retryNotBefore else {
      status = .waiting
      scheduleRetry()
      return
    }
    let token = generation
    task = Task { [weak self] in
      guard let self else { return }
      await self.drain(token: token)
      if self.generation == token {
        self.task = nil
        if self.requested && self.status == .enabled { self.requestSync(enabled: self.enabled) }
      }
    }
  }

  func syncNow(enabled: Bool) async {
    requestSync(enabled: enabled)
    await task?.value
  }

  private func check(_ token: Int) throws {
    try Task.checkCancellation()
    guard token == generation, enabled else { throw CancellationError() }
  }

  private func persist(_ next: ScheduleCloudState) throws {
    try stateStore?.save(next)
    state = next
  }

  private func pause(_ reason: PauseReason) throws {
    var next = state
    next.pause = reason
    state = next
    enabled = false
    requested = false
    status = .off
    do { try stateStore?.save(next) } catch {
      stateLoadFailed = true
      onPause?(reason)
      throw error
    }
    onPause?(reason)
  }

  private func checkOwner(_ token: Int) async throws {
    guard let client else { throw CancellationError() }
    let owner = try await client.accountID()
    try check(token)
    if let previous = state.ownerID, previous != owner {
      try pause(.accountChanged)
      throw CancellationError()
    }
    if state.ownerID == nil {
      var next = state
      next.ownerID = owner
      try persist(next)
    }
  }

  private func drain(token: Int) async {
    var passes = 0
    while requested && passes < 4 {
      // An old task may start only after its replacement has already queued
      // work. It must not consume the replacement's request or change status.
      guard token == generation, enabled, !Task.isCancelled else { return }
      passes += 1
      requested = false
      status = .waiting
      do {
        try check(token)
        try await synchronize(token: token)
        try check(token)
        status = .enabled
        retryCount = 0
      } catch is CancellationError {
        return
      } catch {
        guard token == generation, enabled else { return }
        if ScheduleCloudErrors.contains(.userDeletedZone, in: error)
          || ScheduleCloudErrors.contains(.zoneNotFound, in: error)
        {
          do { try pause(.remoteDeleted) } catch { status = .needsAttention }
          return
        }
        if ScheduleCloudErrors.contains(.accountTemporarilyUnavailable, in: error) {
          accountUnavailable = true
          status = .unavailable
          return
        }
        if let delay = ScheduleCloudErrors.retryDelay(error) {
          retryNotBefore = Date().addingTimeInterval(
            max(delay, min(300, pow(2, Double(retryCount)) * 5)))
          retryCount += 1
          status = .waiting
          requested = true
          scheduleRetry()
        } else {
          status =
            ScheduleCloudErrors.contains(.notAuthenticated, in: error)
              || ScheduleCloudErrors.contains(.accountTemporarilyUnavailable, in: error)
            ? .unavailable : .needsAttention
        }
        return
      }
    }
  }

  private func scheduleRetry() {
    guard retryTask == nil, retryCount <= 5 else { return }
    let token = generation
    let delay = max(1, retryNotBefore.timeIntervalSinceNow)
    retryTask = Task { [weak self] in
      do { try await Task.sleep(for: .seconds(delay)) } catch { return }
      guard let self, self.generation == token else { return }
      self.retryTask = nil
      self.requestSync(enabled: self.enabled)
    }
  }

  private func synchronize(token: Int) async throws {
    guard let client, let legacy, let currentSnapshot else { throw CancellationError() }
    _ = try ScheduleCloudPayload.encode(currentSnapshot())
    try await checkOwner(token)
    let legacyBytes = state.ignoreLegacy ? nil : legacy.read()
    let legacySnapshot = try legacyBytes.map { try ScheduleCloudPayload.decode($0) }
    var record: CKRecord?
    var recoveredReset = false
    do {
      record = try await fetchOrCreateRecord(token: token, hasLegacy: legacyBytes != nil)
    } catch {
      if ScheduleCloudErrors.encryptedReset(error) {
        guard !state.recoveringReset else {
          try pause(.encryptedReset)
          throw CancellationError()
        }
        record = try await recoverEncryptedZone(token: token)
        recoveredReset = true
      } else {
        throw error
      }
    }
    try check(token)
    // Nothing to publish on a fresh installation without a configured schedule.
    guard record != nil else { return }
    for attempt in 0..<4 {
      try check(token)
      guard let target = record else { throw ScheduleError.incompatibleData }
      var merged = currentSnapshot()
      if target.encryptedValues["payload"] != nil {
        merged = try ScheduleMerge.merge(merged, ScheduleCloudPayload.read(target))
      } else if state.recordSaved && !state.recoveringReset {
        throw ScheduleError.incompatibleData
      }
      if let legacySnapshot { merged = try ScheduleMerge.merge(merged, legacySnapshot) }
      _ = try ScheduleCloudPayload.encode(merged)
      if merged != currentSnapshot() {
        guard acceptSnapshot?(merged) == true else { throw ScheduleError.incompatibleData }
      }
      // Account checks and every suspension can race a local edit. Capture the
      // payload only after the identity check, then queue newer edits separately.
      try await checkOwner(token)
      try check(token)
      let outgoing = try ScheduleMerge.merge(merged, currentSnapshot())
      guard outgoing == currentSnapshot() || acceptSnapshot?(outgoing) == true else {
        throw ScheduleError.incompatibleData
      }
      let alreadySaved =
        target.encryptedValues["payload"] as? Data == (try ScheduleCloudPayload.encode(outgoing))
      do {
        if !alreadySaved {
          try ScheduleCloudPayload.write(outgoing, to: target)
          let saved = try await client.saveRecord(target)
          try check(token)
          guard try ScheduleCloudPayload.read(saved) == outgoing else {
            throw ScheduleError.incompatibleData
          }
        }
        var next = state
        next.zoneCreated = true
        next.recordSaved = true
        next.recoveringReset = false
        next.recreateAllowed = false
        try persist(next)
        // No await between the cancellation fence, durable acknowledgement and
        // compare-and-remove of the legacy value.
        if let legacyBytes, !legacy.remove(ifUnchanged: legacyBytes) { requested = true }
        if currentSnapshot() != outgoing { requested = true }
        if !subscribed {
          try await client.ensureSubscription()
          try check(token)
          subscribed = true
        }
        return
      } catch {
        try check(token)
        if let conflict = ScheduleCloudErrors.items(error).first(where: {
          $0.code == .serverRecordChanged
        }),
          let server = conflict.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord,
          attempt < 3
        {
          _ = try ScheduleCloudPayload.read(server)
          record = server
          continue
        }
        // A zone may disappear between fetch and save. Handle that on the next
        // fetch, which verifies reset metadata and other-device recovery first.
        if ScheduleCloudErrors.contains(.zoneNotFound, in: error) {
          requested = true
          if ScheduleCloudErrors.encryptedReset(error) {
            guard !recoveredReset && !state.recoveringReset else {
              try pause(.encryptedReset)
              throw CancellationError()
            }
            record = try await recoverEncryptedZone(token: token)
            recoveredReset = true
            continue
          }
          try pause(.remoteDeleted)
          throw CancellationError()
        }
        throw error
      }
    }
    throw CKError(.serverRecordChanged)
  }

  private func freshRecord() -> CKRecord {
    CKRecord(
      recordType: CloudKitScheduleClient.recordType, recordID: CloudKitScheduleClient.recordID)
  }

  private func fetchOrCreateRecord(token: Int, hasLegacy: Bool) async throws -> CKRecord? {
    guard let client, let currentSnapshot else { throw CancellationError() }
    do {
      try await client.fetchZone()
      try check(token)
    } catch {
      try check(token)
      guard ScheduleCloudErrors.contains(.zoneNotFound, in: error),
        !ScheduleCloudErrors.encryptedReset(error),
        !ScheduleCloudErrors.contains(.userDeletedZone, in: error)
      else { throw error }
      if state.zoneCreated && !state.recoveringReset {
        try pause(.remoteDeleted)
        throw CancellationError()
      }
      guard hasLegacy || !currentSnapshot().versions.isEmpty || currentSnapshot().resetAt != nil
      else {
        return nil
      }
      var next = state
      next.zoneCreated = true
      try persist(next)
      try await checkOwner(token)
      try await client.createZone()
      try check(token)
    }
    if let record = try await client.fetchRecord() {
      try check(token)
      _ = try ScheduleCloudPayload.read(record)
      var next = state
      next.zoneCreated = true
      next.recordSaved = true
      next.recoveringReset = false
      try persist(next)
      return record
    }
    try check(token)
    guard
      state.recreateAllowed || (state.zoneCreated && (!state.recordSaved || state.recoveringReset))
    else {
      try pause(.remoteDeleted)
      throw CancellationError()
    }
    return freshRecord()
  }

  private func recoverEncryptedZone(token: Int) async throws -> CKRecord {
    guard let client, let currentSnapshot else { throw CancellationError() }
    _ = try ScheduleCloudPayload.encode(currentSnapshot())
    try await checkOwner(token)
    // Re-fetch before deletion: a second device may already have recovered this
    // zone while the original operation was returning its reset error.
    do {
      if let record = try await client.fetchRecord() {
        try check(token)
        _ = try ScheduleCloudPayload.read(record)
        return record
      }
      try check(token)
      // An accessible empty zone is safe to reuse; no deletion is necessary.
    } catch {
      try check(token)
      guard ScheduleCloudErrors.encryptedReset(error) else {
        if !ScheduleCloudErrors.contains(.zoneNotFound, in: error)
          || ScheduleCloudErrors.contains(.userDeletedZone, in: error)
        {
          throw error
        }
        // Plain zoneNotFound after a confirmed reset means it is already gone.
        return try await recreateAfterReset(token: token)
      }
      var next = state
      next.recoveringReset = true
      try persist(next)
      try await checkOwner(token)
      do { try await client.deleteZone() } catch {
        guard ScheduleCloudErrors.contains(.zoneNotFound, in: error),
          !ScheduleCloudErrors.contains(.userDeletedZone, in: error)
        else { throw error }
      }
      try check(token)
      return try await recreateAfterReset(token: token)
    }
    return try await recreateAfterReset(token: token)
  }

  private func recreateAfterReset(token: Int) async throws -> CKRecord {
    guard let client else { throw CancellationError() }
    var next = state
    next.recoveringReset = true
    next.zoneCreated = true
    try persist(next)
    try await checkOwner(token)
    try await client.createZone()
    try check(token)
    subscribed = false
    // Conditional creation will merge a record another device uploaded meanwhile.
    return freshRecord()
  }
}
