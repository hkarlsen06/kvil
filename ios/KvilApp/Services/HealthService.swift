import Foundation
import HealthKit

struct HealthWeight: Identifiable, Sendable {
  var id: UUID
  var kilograms: Double
  var date: Date
  var source: String
  var localID: UUID?
}

@MainActor protocol HealthAccess: AnyObject {
  var available: Bool { get }
  var canWrite: Bool { get }
  func authorize(write: Bool) async throws
  func read() async throws -> [HealthWeight]
  func changes(since anchor: Data?) async throws -> (deletions: [HealthDeletion], anchor: Data?)
  func save(_ entry: WeightEntry) async throws -> UUID
  func delete(_ entry: WeightEntry) async throws
}

@MainActor final class HealthService: HealthAccess {
  private let store = HKHealthStore()
  private let type = HKQuantityType(.bodyMass)
  var available: Bool { HKHealthStore.isHealthDataAvailable() }
  var canWrite: Bool { store.authorizationStatus(for: type) == .sharingAuthorized }
  func authorize(write: Bool) async throws {
    guard available else { throw HealthError.unavailable }
    try await store.requestAuthorization(toShare: write ? [type] : [], read: [type])
  }
  func read() async throws -> [HealthWeight] {
    guard available else { return [] }
    let samples: [HKQuantitySample] = try await withCheckedThrowingContinuation { continuation in
      let query = HKSampleQuery(
        sampleType: type, predicate: nil, limit: HKObjectQueryNoLimit,
        sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
      ) { _, samples, error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
        }
      }
      store.execute(query)
    }
    return samples.map { sample in
      let sync = sample.metadata?[HKMetadataKeySyncIdentifier] as? String
      let own = sample.sourceRevision.source.bundleIdentifier == Bundle.main.bundleIdentifier
      let localID =
        own
        ? sync.flatMap { UUID(uuidString: $0.replacingOccurrences(of: "kvil.weight.", with: "")) }
        : nil
      return HealthWeight(
        id: sample.uuid, kilograms: sample.quantity.doubleValue(for: .gramUnit(with: .kilo)),
        date: sample.startDate, source: sample.sourceRevision.source.name, localID: localID)
    }
  }
  func changes(since data: Data?) async throws -> (deletions: [HealthDeletion], anchor: Data?) {
    let anchor =
      try data.map { try NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: $0) }
      ?? nil
    let result: ([HKDeletedObject], HKQueryAnchor?) = try await withCheckedThrowingContinuation {
      continuation in
      let query = HKAnchoredObjectQuery(
        type: type, predicate: nil, anchor: anchor, limit: HKObjectQueryNoLimit
      ) { _, _, deleted, newAnchor, error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: (deleted ?? [], newAnchor))
        }
      }
      store.execute(query)
    }
    let deleted = result.0.map { object in
      let sync = object.metadata?[HKMetadataKeySyncIdentifier] as? String
      let id = sync.flatMap {
        $0.hasPrefix("kvil.weight.")
          ? UUID(uuidString: String($0.dropFirst("kvil.weight.".count))) : nil
      }
      return HealthDeletion(
        sampleID: object.uuid, localID: id,
        version: object.metadata?[HKMetadataKeySyncVersion] as? Int)
    }
    return (
      deleted,
      try result.1.map {
        try NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: true)
      }
    )
  }
  func save(_ entry: WeightEntry) async throws -> UUID {
    guard entry.isValid, canWrite else { throw HealthError.writeNotAuthorized }
    let sample = HKQuantitySample(
      type: type, quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: entry.kilograms),
      start: entry.date, end: entry.date,
      metadata: [
        HKMetadataKeySyncIdentifier: "kvil.weight.\(entry.id.uuidString)",
        HKMetadataKeySyncVersion: entry.healthVersion, HKMetadataKeyWasUserEntered: true,
      ])
    try await store.save(sample)
    return sample.uuid
  }
  func delete(_ entry: WeightEntry) async throws {
    guard canWrite else { throw HealthError.writeNotAuthorized }
    let predicate = HKQuery.predicateForObjects(
      withMetadataKey: HKMetadataKeySyncIdentifier,
      allowedValues: ["kvil.weight.\(entry.id.uuidString)"])
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      store.deleteObjects(of: type, predicate: predicate) { success, _, error in
        if let error {
          continuation.resume(throwing: error)
        } else if success {
          continuation.resume()
        } else {
          continuation.resume(throwing: HealthError.writeNotAuthorized)
        }
      }
    }
  }
}

enum HealthError: Error { case unavailable, writeNotAuthorized }
