import XCTest

@testable import KvilApp

@MainActor final class FakeHealth: HealthAccess {
  var available = true
  var canWrite = true
  var failWrites = true
  var saved: [UUID] = []
  var deleted: [UUID] = []
  var sampleID = UUID()
  var authorizationRequests: [Bool] = []
  var authorizationError: HealthError?
  func authorize(write: Bool) async throws {
    authorizationRequests.append(write)
    if let authorizationError { throw authorizationError }
  }
  func read() async throws -> [HealthWeight] { [] }
  func changes(since anchor: Data?) async throws -> (deletions: [HealthDeletion], anchor: Data?) {
    ([], nil)
  }
  func save(_ entry: WeightEntry) async throws -> UUID {
    if failWrites { throw HealthError.unavailable }
    saved.append(entry.id)
    return sampleID
  }
  func delete(_ entry: WeightEntry) async throws {
    if failWrites { throw HealthError.unavailable }
    deleted.append(entry.id)
  }
}
@MainActor final class HealthTests: XCTestCase {
  func testConnectingOnceEnablesAuthorizedWritesAndSavesTheNextWeight() async throws {
    let health = FakeHealth()
    health.failWrites = false
    let store = try LocalStore(inMemory: true)
    let model = try AppModel(store: store, health: health)
    await model.connectHealth()
    XCTAssertEqual(health.authorizationRequests, [true])
    XCTAssertTrue(model.data.preferences.healthEnabled)
    XCTAssertTrue(model.data.preferences.healthWritesEnabled)
    XCTAssertTrue(try store.load().preferences.healthWritesEnabled)
    let saved = await model.addWeight(value: 73.2, date: Date().addingTimeInterval(-60))
    XCTAssertTrue(saved)
    let entry = try XCTUnwrap(model.data.weights.first)
    XCTAssertTrue(entry.saveToHealth)
    XCTAssertEqual(health.saved, [entry.id])
    XCTAssertEqual(entry.healthSampleID, health.sampleID)
    XCTAssertEqual(health.authorizationRequests.count, 1)
  }

  func testConnectingWithWriteAccessDeniedKeepsNewWeightsLocal() async throws {
    let health = FakeHealth()
    health.canWrite = false
    health.failWrites = false
    let store = try LocalStore(inMemory: true)
    let model = try AppModel(store: store, health: health)
    await model.connectHealth()
    XCTAssertEqual(health.authorizationRequests, [true])
    XCTAssertTrue(model.data.preferences.healthEnabled)
    XCTAssertFalse(model.data.preferences.healthWritesEnabled)
    XCTAssertFalse(try store.load().preferences.healthWritesEnabled)
    let saved = await model.addWeight(value: 73.2, date: Date().addingTimeInterval(-60))
    XCTAssertTrue(saved)
    XCTAssertFalse(try XCTUnwrap(model.data.weights.first).saveToHealth)
    XCTAssertTrue(health.saved.isEmpty)
  }

  func testFailedConnectionDoesNotEnableHealth() async throws {
    let health = FakeHealth()
    health.authorizationError = .unavailable
    let store = try LocalStore(inMemory: true)
    let model = try AppModel(store: store, health: health)
    await model.connectHealth()
    XCTAssertFalse(model.data.preferences.healthEnabled)
    XCTAssertFalse(model.data.preferences.healthWritesEnabled)
    XCTAssertEqual(try store.load().preferences, model.data.preferences)
    XCTAssertNotNil(model.message)
  }

  func testScenarioConnectionNeverRequestsHealthAccess() async throws {
    let health = FakeHealth()
    let model = try AppModel(store: LocalStore(inMemory: true), health: health, scenario: "home")
    await model.connectHealth()
    XCTAssertTrue(health.authorizationRequests.isEmpty)
  }

  func model(health: FakeHealth) throws -> AppModel {
    let store = try LocalStore(inMemory: true)
    var data = LocalData()
    data.preferences.healthEnabled = true
    data.preferences.healthWritesEnabled = true
    try store.save(data)
    return try AppModel(store: store, health: health)
  }
  func testFailedHealthWriteKeepsWeightAndRetryUsesSameIdentity() async throws {
    let health = FakeHealth()
    let model = try model(health: health)
    let saved = await model.addWeight(value: 73.2, date: Date().addingTimeInterval(-60))
    XCTAssertTrue(saved)
    XCTAssertEqual(model.data.weights.count, 1)
    let id = try XCTUnwrap(model.data.weights.first).id
    XCTAssertNil(model.data.weights.first?.healthSampleID)
    health.failWrites = false
    await model.refreshHealth()
    await model.refreshHealth()
    XCTAssertEqual(health.saved, [id])
    XCTAssertEqual(model.data.weights.first?.healthSampleID, health.sampleID)
  }
  func testFailedHealthDeleteKeepsTombstoneUntilSuccessfulRetry() async throws {
    let health = FakeHealth()
    let model = try model(health: health)
    health.failWrites = false
    _ = await model.addWeight(value: 73.2, date: Date().addingTimeInterval(-60))
    let weight = try XCTUnwrap(model.data.weights.first)
    health.failWrites = true
    await model.deleteWeight(weight)
    XCTAssertEqual(model.data.weights.first?.pendingDeletion, true)
    health.failWrites = false
    await model.refreshHealth()
    XCTAssertTrue(model.data.weights.isEmpty)
    XCTAssertEqual(health.deleted, [weight.id])
  }
  func testExternalDeletionAndReplacementRespectVersions() {
    let sample = UUID()
    var entry = WeightEntry(
      kilograms: 70, date: Date(), healthSampleID: sample, saveToHealth: true, healthVersion: 2)
    let oldDeletion = HealthDeletion(sampleID: UUID(), localID: entry.id, version: 1)
    XCTAssertEqual(WeightReconciliation.applying([oldDeletion], to: [entry]).count, 1)
    let currentDeletion = HealthDeletion(sampleID: sample, localID: entry.id, version: 2)
    XCTAssertTrue(WeightReconciliation.applying([currentDeletion], to: [entry]).isEmpty)
    entry.healthNeedsUpdate = true
    XCTAssertEqual(WeightReconciliation.applying([currentDeletion], to: [entry]).count, 1)
  }
  func testEditingWeightKeepsIdentityAndIncreasesHealthVersion() async throws {
    let health = FakeHealth()
    let model = try model(health: health)
    health.failWrites = false
    _ = await model.addWeight(value: 75, date: Date().addingTimeInterval(-120))
    let original = try XCTUnwrap(model.data.weights.first)
    let updated = await model.updateWeight(original, value: 75.5, date: original.date)
    XCTAssertTrue(updated)
    XCTAssertEqual(model.data.weights.first?.id, original.id)
    XCTAssertEqual(model.data.weights.first?.healthVersion, 2)
    XCTAssertEqual(model.data.weights.first?.kilograms, 75.5)
  }
}
