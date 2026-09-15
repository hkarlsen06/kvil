import CloudKit
import Foundation

@MainActor protocol ScheduleCloudClient {
  func accountID() async throws -> String
  func fetchZone() async throws
  func createZone() async throws
  func deleteZone() async throws
  func fetchRecord() async throws -> CKRecord?
  func saveRecord(_ record: CKRecord) async throws -> CKRecord
  func ensureSubscription() async throws
}

@MainActor final class CloudKitScheduleClient: ScheduleCloudClient {
  static let zoneID = CKRecordZone.ID(zoneName: "Schedule", ownerName: CKCurrentUserDefaultName)
  static let recordID = CKRecord.ID(recordName: "current", zoneID: zoneID)
  static let recordType = "ScheduleState"
  static let subscriptionID = "schedule-changes"

  private let container: CKContainer
  private let database: CKDatabase

  init() {
    let container = CKContainer(identifier: "iCloud.dev.hkarlsen06.kvil")
    self.container = container
    database = container.privateCloudDatabase
  }

  func accountID() async throws -> String {
    try Task.checkCancellation()
    let status: CKAccountStatus = try await readAccount { completion in
      container.accountStatus { status, error in
        if let error { completion(.failure(error)) } else { completion(.success(status)) }
      }
    }
    try Task.checkCancellation()
    switch status {
    case .available:
      break
    case .noAccount:
      throw CKError(.notAuthenticated)
    case .restricted:
      throw CKError(.permissionFailure)
    case .temporarilyUnavailable:
      throw CKError(.accountTemporarilyUnavailable)
    case .couldNotDetermine:
      throw CKError(.serviceUnavailable)
    @unknown default:
      throw CKError(.internalError)
    }
    let recordID: CKRecord.ID = try await readAccount { completion in
      container.fetchUserRecordID { recordID, error in
        if let error {
          completion(.failure(error))
        } else if let recordID {
          completion(.success(recordID))
        } else {
          completion(.failure(CKError(.internalError)))
        }
      }
    }
    try Task.checkCancellation()
    return recordID.recordName
  }

  func fetchZone() async throws {
    let operation = CKFetchRecordZonesOperation(recordZoneIDs: [Self.zoneID])
    let response = CloudOperationResponse<Void>()
    operation.perRecordZoneResultBlock = { _, result in
      response.receive(result.map { _ in () })
    }
    operation.fetchRecordZonesResultBlock = { response.finish($0) }
    try await perform(operation, response: response)
  }

  func createZone() async throws {
    let operation = CKModifyRecordZonesOperation(
      recordZonesToSave: [CKRecordZone(zoneID: Self.zoneID)], recordZoneIDsToDelete: nil)
    let response = CloudOperationResponse<Void>()
    operation.perRecordZoneSaveBlock = { _, result in
      response.receive(result.map { _ in () })
    }
    operation.modifyRecordZonesResultBlock = { response.finish($0) }
    try await perform(operation, response: response)
  }

  func deleteZone() async throws {
    let operation = CKModifyRecordZonesOperation(
      recordZonesToSave: nil, recordZoneIDsToDelete: [Self.zoneID])
    let response = CloudOperationResponse<Void>()
    operation.perRecordZoneDeleteBlock = { _, result in response.receive(result) }
    operation.modifyRecordZonesResultBlock = { response.finish($0) }
    try await perform(operation, response: response)
  }

  func fetchRecord() async throws -> CKRecord? {
    let operation = CKFetchRecordsOperation(recordIDs: [Self.recordID])
    let response = CloudOperationResponse<CKRecord>()
    operation.perRecordResultBlock = { _, result in response.receive(result) }
    operation.fetchRecordsResultBlock = { response.finish($0) }
    do {
      return try await perform(operation, response: response)
    } catch let error as CKError where error.code == .unknownItem {
      return nil
    }
  }

  func saveRecord(_ record: CKRecord) async throws -> CKRecord {
    guard record.recordID == Self.recordID, record.recordType == Self.recordType else {
      throw CKError(.invalidArguments)
    }
    let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
    operation.savePolicy = .ifServerRecordUnchanged
    operation.isAtomic = true
    let response = CloudOperationResponse<CKRecord>()
    operation.perRecordSaveBlock = { _, result in response.receive(result) }
    operation.modifyRecordsResultBlock = { response.finish($0) }
    return try await perform(operation, response: response)
  }

  func ensureSubscription() async throws {
    let subscription = CKRecordZoneSubscription(
      zoneID: Self.zoneID, subscriptionID: Self.subscriptionID)
    let info = CKSubscription.NotificationInfo()
    info.shouldSendContentAvailable = true
    subscription.notificationInfo = info
    let operation = CKModifySubscriptionsOperation(
      subscriptionsToSave: [subscription], subscriptionIDsToDelete: nil)
    let response = CloudOperationResponse<Void>()
    operation.perSubscriptionSaveBlock = { _, result in
      response.receive(result.map { _ in () })
    }
    operation.modifySubscriptionsResultBlock = { response.finish($0) }
    try await perform(operation, response: response)
  }

  // Container account reads expose no cancellable operation. Stop awaiting them
  // immediately on cancellation and ignore their eventual read-only callbacks.
  private func readAccount<Value: Sendable>(
    _ start: (@escaping @Sendable (Result<Value, Error>) -> Void) -> Void
  ) async throws -> Value {
    try Task.checkCancellation()
    let response = CloudOperationResponse<Value>()
    do {
      let value = try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
          guard response.install(continuation) else { return }
          start { result in
            response.receive(result)
            response.finish(.success(()))
          }
        }
      } onCancel: {
        response.cancel()
      }
      try Task.checkCancellation()
      return value
    } catch {
      try Task.checkCancellation()
      throw error
    }
  }

  private func perform<Value: Sendable>(
    _ operation: CKDatabaseOperation, response: CloudOperationResponse<Value>
  ) async throws -> Value {
    try Task.checkCancellation()
    let configuration = CKOperation.Configuration()
    configuration.timeoutIntervalForRequest = 15
    configuration.timeoutIntervalForResource = 20
    operation.configuration = configuration
    operation.qualityOfService = .utility
    do {
      let value = try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
          guard response.install(continuation) else { return }
          database.add(operation)
        }
      } onCancel: {
        operation.cancel()
        response.cancel()
      }
      try Task.checkCancellation()
      return value
    } catch {
      try Task.checkCancellation()
      throw error
    }
  }
}

// CloudKit callbacks and task cancellation can race on different queues. The lock
// protects the continuation and guarantees exactly one result, even before enqueue.
private final class CloudOperationResponse<Value: Sendable>: @unchecked Sendable {
  private let lock = NSLock()
  private var continuation: CheckedContinuation<Value, Error>?
  private var itemResult: Result<Value, Error>?
  private var completedResult: Result<Value, Error>?

  func install(_ continuation: CheckedContinuation<Value, Error>) -> Bool {
    let completed = lock.withLock { () -> Result<Value, Error>? in
      if let completedResult { return completedResult }
      self.continuation = continuation
      return nil
    }
    if let completed {
      continuation.resume(with: completed)
      return false
    }
    return true
  }

  func receive(_ result: Result<Value, Error>) {
    lock.withLock { itemResult = result }
  }

  func finish(_ operationResult: Result<Void, Error>) {
    let completion = lock.withLock {
      guard completedResult == nil else {
        return nil as (CheckedContinuation<Value, Error>?, Result<Value, Error>)?
      }
      let result: Result<Value, Error>
      // Preserve the item error, including server records and reset metadata,
      // instead of replacing it with the operation's partialFailure wrapper.
      if case .failure(let error) = operationResult,
        let cloud = error as? CKError, cloud.code == .userDeletedZone
      {
        result = .failure(error)
      } else if case .failure(let error) = itemResult {
        if let cloud = error as? CKError,
          case .failure(let operationError) = operationResult,
          let operationCloud = operationError as? CKError
        {
          var info = cloud.userInfo
          let delays = [cloud, operationCloud].compactMap {
            ($0.userInfo[CKErrorRetryAfterKey] as? NSNumber)?.doubleValue
          }.filter { $0.isFinite && $0 >= 0 }
          if let delay = delays.max() { info[CKErrorRetryAfterKey] = delay }
          result = .failure(CKError(cloud.code, userInfo: info))
        } else {
          result = .failure(error)
        }
      } else if case .failure(let error) = operationResult {
        result = .failure(error)
      } else {
        result = itemResult ?? .failure(CKError(.internalError))
      }
      completedResult = result
      let current = continuation
      continuation = nil
      return (current, result)
    }
    if let (continuation, result) = completion {
      continuation?.resume(with: result)
    }
  }

  func cancel() {
    let continuation = lock.withLock {
      guard completedResult == nil else { return nil as CheckedContinuation<Value, Error>? }
      completedResult = .failure(CancellationError())
      let current = self.continuation
      self.continuation = nil
      return current
    }
    continuation?.resume(throwing: CancellationError())
  }
}
