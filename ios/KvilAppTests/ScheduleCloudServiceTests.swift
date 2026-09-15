import CloudKit
import XCTest

@testable import KvilApp

@MainActor final class ScheduleCloudServiceTests: XCTestCase {
  func testLegacyMigrationKeepsItsOnlyCopyUntilTheEncryptedSaveIsAcknowledged() async throws {
    let fixture = CloudFixture(local: .empty)
    let legacy = baseline()
    let bytes = try JSONEncoder().encode(legacy)
    fixture.legacy.bytes = bytes
    fixture.client.saveError = CKError(.permissionFailure)

    await fixture.service.syncNow(enabled: true)

    XCTAssertEqual(fixture.local, legacy)
    XCTAssertEqual(fixture.legacy.bytes, bytes)
    XCTAssertTrue(fixture.legacy.removed.isEmpty)
    XCTAssertTrue(fixture.client.savedSnapshots.isEmpty)

    fixture.client.saveError = nil
    await fixture.service.syncNow(enabled: true)

    XCTAssertEqual(fixture.client.savedSnapshots.last, legacy)
    XCTAssertNil(fixture.legacy.bytes)
    XCTAssertEqual(fixture.legacy.removed, [bytes])
    let record = try XCTUnwrap(fixture.client.record)
    XCTAssertEqual(Set(record.encryptedValues.allKeys()), ["payload"])
    XCTAssertEqual(Set(record.allKeys()), Set(record.encryptedValues.allKeys()))
  }

  func testLegacyMigrationDoesNotDeleteACopyChangedDuringTheSave() async throws {
    let fixture = CloudFixture(local: .empty)
    let original = baseline()
    let changed = edited(original)
    let originalBytes = try JSONEncoder().encode(original)
    let changedBytes = try JSONEncoder().encode(changed)
    fixture.legacy.bytes = originalBytes
    fixture.client.beforeSaveCompletes = { [weak fixture] attempt in
      if attempt == 1 { fixture?.legacy.bytes = changedBytes }
    }

    await fixture.service.syncNow(enabled: true)

    XCTAssertFalse(fixture.legacy.removed.contains(originalBytes))
    // A service may immediately run a second migration, but it must never remove
    // the changed bytes unless that exact schedule has also been acknowledged.
    if fixture.legacy.bytes == nil {
      XCTAssertEqual(fixture.client.savedSnapshots.last, changed)
      XCTAssertEqual(fixture.legacy.removed, [changedBytes])
    } else {
      XCTAssertEqual(fixture.legacy.bytes, changedBytes)
      XCTAssertTrue(fixture.legacy.removed.isEmpty)
    }
  }

  func testRejectedLocalPersistencePreventsRemoteSaveAndLegacyRemoval() async throws {
    let local = baseline()
    let remote = edited(local)
    let fixture = CloudFixture(local: local)
    fixture.client.zoneError = nil
    fixture.client.record = try encryptedRecord(remote)
    fixture.legacy.bytes = try JSONEncoder().encode(remote)
    fixture.acceptsSnapshots = false

    await fixture.service.syncNow(enabled: true)

    XCTAssertFalse(fixture.acceptedSnapshots.isEmpty)
    XCTAssertEqual(fixture.local, local)
    XCTAssertTrue(fixture.client.attemptedSnapshots.isEmpty)
    XCTAssertNotNil(fixture.legacy.bytes)
    XCTAssertTrue(fixture.legacy.removed.isEmpty)
  }

  func testOwnerChangePausesWithoutUploadingToTheNewAccount() async throws {
    let fixture = CloudFixture(local: baseline(), state: knownCloud())
    fixture.client.ownerID = "different-owner"
    fixture.legacy.bytes = try JSONEncoder().encode(fixture.local)

    await fixture.service.syncNow(enabled: true)

    XCTAssertEqual(fixture.pauses, [.accountChanged])
    XCTAssertEqual(fixture.state.value.pause, .accountChanged)
    XCTAssertTrue(fixture.client.attemptedSnapshots.isEmpty)
    XCTAssertEqual(fixture.client.zonesCreated, 0)
    XCTAssertTrue(fixture.legacy.removed.isEmpty)
  }

  func testKnownMissingZoneWithoutConfirmedEncryptedResetPauses() async throws {
    for resetFlag in [nil, NSNumber(value: false)] {
      let fixture = CloudFixture(local: baseline(), state: knownCloud())
      var info: [String: Any] = [:]
      if let resetFlag { info[CKErrorUserDidResetEncryptedDataKey] = resetFlag }
      fixture.client.zoneError = CKError(.zoneNotFound, userInfo: info)

      await fixture.service.syncNow(enabled: true)

      XCTAssertEqual(fixture.pauses, [.remoteDeleted])
      XCTAssertEqual(fixture.state.value.pause, .remoteDeleted)
      XCTAssertEqual(fixture.client.zonesCreated, 0)
      XCTAssertTrue(fixture.client.attemptedSnapshots.isEmpty)
    }
  }

  func testKnownMissingRecordPausesWithoutRecreatingDeletedData() async throws {
    let fixture = CloudFixture(local: baseline(), state: knownCloud())
    fixture.client.record = nil

    await fixture.service.syncNow(enabled: true)

    XCTAssertEqual(fixture.pauses, [.remoteDeleted])
    XCTAssertEqual(fixture.state.value.pause, .remoteDeleted)
    XCTAssertTrue(fixture.client.attemptedSnapshots.isEmpty)
  }

  func testProvisionedZoneDisappearingBeforeItsFirstRecordStillPauses() async throws {
    var state = knownCloud()
    state.recordSaved = false
    let fixture = CloudFixture(local: baseline(), state: state)
    fixture.client.zoneError = CKError(.zoneNotFound)

    await fixture.service.syncNow(enabled: true)

    XCTAssertEqual(fixture.pauses, [.remoteDeleted])
    XCTAssertEqual(fixture.state.value.pause, .remoteDeleted)
    XCTAssertEqual(fixture.client.zonesCreated, 0)
    XCTAssertTrue(fixture.client.attemptedSnapshots.isEmpty)
  }

  func testDurablePauseSurvivesRelaunchUntilExplicitResume() async throws {
    for reason in [ScheduleCloudService.PauseReason.accountChanged, .remoteDeleted] {
      var paused = knownCloud()
      paused.pause = reason
      let reloaded = try JSONDecoder().decode(
        ScheduleCloudState.self, from: JSONEncoder().encode(paused))
      let local = baseline()
      let fixture = CloudFixture(local: local, state: reloaded)
      let oldAccountCache = try JSONEncoder().encode(edited(local))
      fixture.legacy.bytes = oldAccountCache
      fixture.client.ownerID = "explicitly-chosen-owner"
      fixture.client.zoneError = CKError(.zoneNotFound)

      await fixture.service.syncNow(enabled: true)

      XCTAssertEqual(fixture.pauses, [reason])
      XCTAssertEqual(fixture.client.accountRequests, 0)
      XCTAssertTrue(fixture.client.attemptedSnapshots.isEmpty)
      XCTAssertEqual(fixture.state.value.pause, reason)

      try fixture.service.resume()
      await fixture.service.syncNow(enabled: true)

      XCTAssertNil(fixture.state.value.pause)
      XCTAssertEqual(fixture.state.value.ownerID, "explicitly-chosen-owner")
      XCTAssertEqual(fixture.client.savedSnapshots, [local])
      XCTAssertEqual(fixture.local, local)
      XCTAssertEqual(fixture.legacy.reads, 0)
      XCTAssertEqual(fixture.legacy.bytes, oldAccountCache)
      XCTAssertTrue(fixture.state.value.ignoreLegacy)
    }
  }

  func testExplicitResumeRecreatesAMissingRecordOnceWithoutReplacingItsZone() async throws {
    var paused = knownCloud()
    paused.pause = .remoteDeleted
    let local = baseline()
    let fixture = CloudFixture(local: local, state: paused)

    try fixture.service.resume()
    await fixture.service.syncNow(enabled: true)

    XCTAssertEqual(fixture.client.zonesCreated, 0)
    XCTAssertEqual(fixture.client.zonesDeleted, 0)
    XCTAssertEqual(fixture.client.savedSnapshots, [local])
    XCTAssertFalse(fixture.state.value.recreateAllowed)

    // The earlier choice does not authorize recreating another later deletion.
    fixture.client.record = nil
    await fixture.service.syncNow(enabled: true)
    XCTAssertEqual(fixture.state.value.pause, .remoteDeleted)
    XCTAssertEqual(fixture.client.savedSnapshots, [local])
  }

  func testZoneDeletedBetweenZoneAndRecordFetchPausesWithoutRecreatingData() async throws {
    let fixture = CloudFixture(local: baseline(), state: knownCloud())
    fixture.client.recordError = CKError(.zoneNotFound)

    await fixture.service.syncNow(enabled: true)

    XCTAssertEqual(fixture.pauses, [.remoteDeleted])
    XCTAssertEqual(fixture.client.zonesCreated, 0)
    XCTAssertTrue(fixture.client.attemptedSnapshots.isEmpty)
  }

  func testConfirmedEncryptedResetCanRecreateZoneFromTheLocalCopy() async throws {
    let local = baseline()
    let fixture = CloudFixture(local: local, state: knownCloud())
    fixture.client.zoneError = CKError(
      .zoneNotFound, userInfo: [CKErrorUserDidResetEncryptedDataKey: NSNumber(value: true)])

    await fixture.service.syncNow(enabled: true)

    XCTAssertTrue(fixture.pauses.isEmpty)
    XCTAssertEqual(fixture.client.zonesCreated, 1)
    XCTAssertEqual(fixture.client.savedSnapshots, [local])
    XCTAssertNil(fixture.state.value.pause)
    XCTAssertFalse(fixture.state.value.recoveringReset)
    XCTAssertTrue(fixture.state.value.recordSaved)
  }

  func testEncryptedResetReusesARecordRecoveredByAnotherDevice() async throws {
    let local = baseline()
    let recovered = edited(local)
    let fixture = CloudFixture(local: local, state: knownCloud())
    fixture.client.zoneError = CKError(
      .zoneNotFound, userInfo: [CKErrorUserDidResetEncryptedDataKey: NSNumber(value: true)])
    fixture.client.record = try encryptedRecord(recovered)

    await fixture.service.syncNow(enabled: true)

    XCTAssertEqual(fixture.local, recovered)
    XCTAssertTrue(fixture.pauses.isEmpty)
    XCTAssertEqual(fixture.client.zonesDeleted, 0)
    XCTAssertEqual(fixture.client.zonesCreated, 0)
    XCTAssertTrue(fixture.client.attemptedSnapshots.isEmpty)
  }

  func testRepeatedEncryptedResetPausesAcrossRelaunchAndWithinOneRun() async throws {
    let reset = CKError(
      .zoneNotFound, userInfo: [CKErrorUserDidResetEncryptedDataKey: NSNumber(value: true)])
    var recovering = knownCloud()
    recovering.recoveringReset = true
    let local = baseline()
    let interrupted = CloudFixture(local: local, state: recovering)
    interrupted.client.zoneError = reset

    await interrupted.service.syncNow(enabled: true)

    XCTAssertEqual(interrupted.state.value.pause, .encryptedReset)
    XCTAssertEqual(interrupted.pauses, [.encryptedReset])
    XCTAssertEqual(interrupted.client.zonesDeleted, 0)
    XCTAssertEqual(interrupted.client.zonesCreated, 0)
    XCTAssertTrue(interrupted.client.attemptedSnapshots.isEmpty)

    let persisted = try JSONDecoder().decode(
      ScheduleCloudState.self, from: JSONEncoder().encode(interrupted.state.value))
    let relaunched = CloudFixture(local: local, state: persisted)
    relaunched.client.zoneError = reset
    await relaunched.service.syncNow(enabled: true)
    XCTAssertEqual(relaunched.client.accountRequests, 0)
    XCTAssertEqual(relaunched.client.zonesDeleted, 0)
    XCTAssertEqual(relaunched.client.zonesCreated, 0)
    XCTAssertTrue(relaunched.client.attemptedSnapshots.isEmpty)

    try relaunched.service.resume()
    await relaunched.service.syncNow(enabled: true)
    XCTAssertNil(relaunched.state.value.pause)
    XCTAssertEqual(relaunched.client.savedSnapshots, [local])

    let repeating = CloudFixture(local: local, state: knownCloud())
    repeating.client.zoneError = reset
    repeating.client.recordError = reset
    repeating.client.saveError = reset
    await repeating.service.syncNow(enabled: true)
    XCTAssertEqual(repeating.state.value.pause, .encryptedReset)
    XCTAssertEqual(repeating.pauses, [.encryptedReset])
    XCTAssertEqual(repeating.client.zonesDeleted, 1)
    XCTAssertEqual(repeating.client.zonesCreated, 1)
    XCTAssertEqual(repeating.client.attemptedSnapshots.count, 1)
    XCTAssertTrue(repeating.client.savedSnapshots.isEmpty)
  }

  func testUserDeletedZoneAlwaysPausesEvenWithResetMetadata() async throws {
    let fixture = CloudFixture(local: baseline(), state: knownCloud())
    fixture.client.zoneError = CKError(
      .userDeletedZone, userInfo: [CKErrorUserDidResetEncryptedDataKey: NSNumber(value: true)])

    await fixture.service.syncNow(enabled: true)

    XCTAssertEqual(fixture.pauses, [.remoteDeleted])
    XCTAssertEqual(fixture.client.zonesCreated, 0)
    XCTAssertTrue(fixture.client.attemptedSnapshots.isEmpty)
  }

  func testNestedPartialFailuresDistinguishResetFromDeletion() async throws {
    let reset = CKError(
      .zoneNotFound, userInfo: [CKErrorUserDidResetEncryptedDataKey: NSNumber(value: true)])
    let noReset = CKError(
      .zoneNotFound, userInfo: [CKErrorUserDidResetEncryptedDataKey: NSNumber(value: false)])
    let cases: [(CKError, Bool)] = [
      (partialFailure([partialFailure([reset])]), true),
      (partialFailure([partialFailure([noReset])]), false),
      (partialFailure([partialFailure([reset]), CKError(.userDeletedZone)]), false),
    ]
    for (error, shouldRecover) in cases {
      let fixture = CloudFixture(local: baseline(), state: knownCloud())
      fixture.client.zoneError = error

      await fixture.service.syncNow(enabled: true)

      if shouldRecover {
        XCTAssertTrue(fixture.pauses.isEmpty)
        XCTAssertEqual(fixture.client.zonesCreated, 1)
        XCTAssertEqual(fixture.client.savedSnapshots, [fixture.local])
      } else {
        XCTAssertEqual(fixture.pauses, [.remoteDeleted])
        XCTAssertEqual(fixture.client.zonesCreated, 0)
        XCTAssertTrue(fixture.client.attemptedSnapshots.isEmpty)
      }
    }
  }

  func testServerRecordConflictMergesBothEditsAndReusesTheReturnedRecord() async throws {
    let original = baseline()
    let local = edited(original)
    var otherDevice = original
    otherDevice.revision = original.revision.addingTimeInterval(120)
    otherDevice.versions[0].days[2].opens = .init(hour: 12)
    otherDevice.versions[0].days[2].modifiedAt = otherDevice.revision
    otherDevice.versions[0].modifiedAt = otherDevice.revision
    let server = try encryptedRecord(otherDevice)
    let fixture = CloudFixture(local: local, state: knownCloud())
    fixture.client.record = try encryptedRecord(original)
    fixture.client.saveErrors = [
      CKError(.serverRecordChanged, userInfo: [CKRecordChangedErrorServerRecordKey: server])
    ]

    await fixture.service.syncNow(enabled: true)

    XCTAssertEqual(fixture.client.attemptedSnapshots.count, 2)
    let second = try XCTUnwrap(fixture.client.attemptedSnapshots.last)
    XCTAssertEqual(second.versions[0].days[1].opens.hour, 11)
    XCTAssertEqual(second.versions[0].days[2].opens.hour, 12)
    XCTAssertEqual(fixture.local, second)
    XCTAssertEqual(fixture.client.savedSnapshots, [second])
    XCTAssertTrue(try XCTUnwrap(fixture.client.attemptedRecords.last) === server)
    XCTAssertEqual(
      fixture.client.attemptedRecords.map(\.recordID),
      [CloudKitScheduleClient.recordID, CloudKitScheduleClient.recordID])
  }

  func testMalformedOrPlaintextOnlyRecordDoesNotReplaceOrUploadData() async throws {
    for plaintextOnly in [false, true] {
      let local = baseline()
      let fixture = CloudFixture(local: local, state: knownCloud())
      let record = CKRecord(
        recordType: CloudKitScheduleClient.recordType, recordID: CloudKitScheduleClient.recordID)
      if plaintextOnly {
        record["payload"] = try ScheduleCloudPayload.encode(edited(local)) as NSData
      } else {
        record.encryptedValues["payload"] = Data("malformed".utf8) as NSData
      }
      fixture.client.record = record

      XCTAssertThrowsError(try ScheduleCloudPayload.read(record))
      await fixture.service.syncNow(enabled: true)

      XCTAssertEqual(fixture.local, local)
      XCTAssertTrue(fixture.acceptedSnapshots.isEmpty)
      XCTAssertTrue(fixture.client.attemptedSnapshots.isEmpty)
    }
  }

  func testLocalEditDuringTheSaveIsPersistedInASecondSave() async throws {
    let original = baseline()
    let changed = edited(original)
    let fixture = CloudFixture(local: original)
    fixture.client.beforeSaveCompletes = { [weak fixture] attempt in
      if attempt == 1 { fixture?.local = changed }
    }

    await fixture.service.syncNow(enabled: true)

    XCTAssertEqual(fixture.local, changed)
    XCTAssertEqual(fixture.client.savedSnapshots, [original, changed])
    XCTAssertEqual(try ScheduleCloudPayload.read(XCTUnwrap(fixture.client.record)), changed)
  }

  func testDisabledSyncNeverReadsTheCloudOrMigratesLegacyData() async throws {
    let fixture = CloudFixture(local: baseline())
    let bytes = try JSONEncoder().encode(fixture.local)
    fixture.legacy.bytes = bytes

    await fixture.service.syncNow(enabled: false)

    XCTAssertEqual(fixture.client.accountRequests, 0)
    XCTAssertTrue(fixture.client.attemptedSnapshots.isEmpty)
    XCTAssertEqual(fixture.legacy.bytes, bytes)
    XCTAssertEqual(fixture.legacy.reads, 0)
  }

  func testInvalidationDuringSaveDoesNotAcknowledgeOrRemoveLegacyData() async throws {
    let fixture = CloudFixture(local: .empty)
    let bytes = try JSONEncoder().encode(baseline())
    fixture.legacy.bytes = bytes
    fixture.client.beforeSaveCompletes = { [weak fixture] _ in
      fixture?.service.invalidatePendingWork()
    }

    await fixture.service.syncNow(enabled: true)

    XCTAssertEqual(fixture.legacy.bytes, bytes)
    XCTAssertTrue(fixture.legacy.removed.isEmpty)
    XCTAssertFalse(fixture.state.value.recordSaved)
  }

  func testOldGenerationCancellationCannotCancelReplacementWork() async throws {
    let local = baseline()
    let fixture = CloudFixture(local: local)
    fixture.service.requestSync(enabled: true)
    let oldToken = fixture.service.workGeneration
    fixture.service.invalidatePendingWork()
    let replacementToken = fixture.service.workGeneration
    XCTAssertNotEqual(oldToken, replacementToken)
    fixture.client.beforeSaveCompletes = { [weak fixture] _ in
      fixture?.service.cancelPendingWork(generation: oldToken)
    }

    await fixture.service.syncNow(enabled: true)

    XCTAssertEqual(fixture.service.workGeneration, replacementToken)
    XCTAssertEqual(fixture.client.savedSnapshots, [local])
    XCTAssertTrue(fixture.state.value.recordSaved)
    XCTAssertEqual(fixture.service.status, .enabled)
  }

  func testMetadataWriteFailureDoesNotPublishAnUnownedRecord() async throws {
    let fixture = CloudFixture(local: baseline())
    fixture.state.saveError = CocoaError(.fileWriteNoPermission)

    await fixture.service.syncNow(enabled: true)

    XCTAssertNil(fixture.state.value.ownerID)
    XCTAssertEqual(fixture.client.zonesCreated, 0)
    XCTAssertTrue(fixture.client.attemptedSnapshots.isEmpty)
  }

  func testMalformedLegacyBytesRemainAvailableForRecovery() async throws {
    let fixture = CloudFixture(local: baseline())
    let original = fixture.local
    let malformed = Data("not-a-schedule".utf8)
    fixture.legacy.bytes = malformed

    await fixture.service.syncNow(enabled: true)

    XCTAssertEqual(fixture.local, original)
    XCTAssertEqual(fixture.legacy.bytes, malformed)
    XCTAssertTrue(fixture.legacy.removed.isEmpty)
    XCTAssertEqual(fixture.client.zonesCreated, 0)
    XCTAssertTrue(fixture.client.attemptedSnapshots.isEmpty)
  }

  func testRetryAfterPreventsAnImmediateSecondAccountLookup() async throws {
    let fixture = CloudFixture(local: baseline())
    defer { fixture.service.invalidatePendingWork() }
    fixture.client.accountError = CKError(
      .requestRateLimited, userInfo: [CKErrorRetryAfterKey: NSNumber(value: 60)])

    await fixture.service.syncNow(enabled: true)

    XCTAssertEqual(fixture.client.accountRequests, 1)
    fixture.client.accountError = nil
    await fixture.service.syncNow(enabled: true)
    XCTAssertEqual(fixture.client.accountRequests, 1)
    XCTAssertEqual(fixture.client.zoneRequests, 0)
    XCTAssertTrue(fixture.client.attemptedSnapshots.isEmpty)
    XCTAssertEqual(fixture.service.status, .waiting)
  }

  func testTemporaryAccountUnavailabilityWaitsForAnAccountChangeNotification() async throws {
    let fixture = CloudFixture(local: baseline())
    defer { fixture.service.invalidatePendingWork() }
    fixture.client.accountError = CKError(
      .accountTemporarilyUnavailable, userInfo: [CKErrorRetryAfterKey: NSNumber(value: 60)])

    await fixture.service.syncNow(enabled: true)

    XCTAssertEqual(fixture.client.accountRequests, 1)
    XCTAssertEqual(fixture.service.status, .unavailable)
    fixture.client.accountError = nil
    for _ in 0..<3 { await fixture.service.syncNow(enabled: true) }
    XCTAssertEqual(fixture.client.accountRequests, 1)
    XCTAssertEqual(fixture.client.zoneRequests, 0)
    XCTAssertTrue(fixture.client.attemptedSnapshots.isEmpty)

    fixture.service.accountDidChange()
    await fixture.service.syncNow(enabled: true)

    XCTAssertGreaterThan(fixture.client.accountRequests, 1)
    XCTAssertEqual(fixture.client.savedSnapshots, [fixture.local])
    XCTAssertEqual(fixture.service.status, .enabled)
  }

  func testFileStateStoreRoundTripsPauseAndExcludesItsFileFromBackup() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = FileScheduleCloudStateStore(directory: directory)
    XCTAssertEqual(try store.load(), ScheduleCloudState())
    var persisted = knownCloud()
    persisted.pause = .remoteDeleted
    persisted.ignoreLegacy = true

    try store.save(persisted)

    let reopened = FileScheduleCloudStateStore(directory: directory)
    XCTAssertEqual(try reopened.load(), persisted)
    let files = try FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: [.isExcludedFromBackupKey])
    XCTAssertEqual(files.count, 1)
    let file = try XCTUnwrap(files.first)
    XCTAssertEqual(
      try file.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
  }

  func testCorruptedFileStateFailsClosedWithoutCloudOperations() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = FileScheduleCloudStateStore(directory: directory)
    try store.save(knownCloud())
    let file = try XCTUnwrap(
      FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).first)
    var invalidState = knownCloud()
    invalidState.ownerID = nil
    let corruptions = [Data("broken".utf8), try JSONEncoder().encode(invalidState)]
    for bytes in corruptions {
      try bytes.write(to: file, options: .atomic)
      XCTAssertThrowsError(try store.load())
      let client = ScheduleCloudClientFake()
      let service = ScheduleCloudService(
        client: client, legacy: LegacyScheduleFake(), stateStore: store)
      service.currentSnapshot = { self.baseline() }
      service.acceptSnapshot = { _ in true }

      await service.syncNow(enabled: true)

      XCTAssertEqual(service.status, .needsAttention)
      XCTAssertEqual(client.accountRequests, 0)
      XCTAssertTrue(client.attemptedSnapshots.isEmpty)
      XCTAssertThrowsError(try service.resume())
    }
  }

  private func baseline() -> ScheduleSnapshot {
    let stamp = Date(timeIntervalSince1970: 1_788_220_800)
    let days = DayPlan.initial.map { day in
      var day = day
      day.modifiedAt = stamp
      return day
    }
    return ScheduleSnapshot(
      revision: stamp,
      versions: [
        ScheduleVersion(
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
          effectiveDay: "2026-01-01", days: days, modifiedAt: stamp)
      ], overrides: [])
  }

  private func edited(_ snapshot: ScheduleSnapshot) -> ScheduleSnapshot {
    var changed = snapshot
    changed.revision = snapshot.revision.addingTimeInterval(60)
    changed.versions[0].days[1].opens = .init(hour: 11)
    changed.versions[0].days[1].modifiedAt = changed.revision
    changed.versions[0].modifiedAt = changed.revision
    return changed
  }

  private func knownCloud() -> ScheduleCloudState {
    var state = ScheduleCloudState()
    state.ownerID = "original-owner"
    state.zoneCreated = true
    state.recordSaved = true
    return state
  }

  private func encryptedRecord(_ snapshot: ScheduleSnapshot) throws -> CKRecord {
    let record = CKRecord(
      recordType: CloudKitScheduleClient.recordType, recordID: CloudKitScheduleClient.recordID)
    try ScheduleCloudPayload.write(snapshot, to: record)
    return record
  }

  private func partialFailure(_ errors: [CKError]) -> CKError {
    let items: [AnyHashable: Error] = Dictionary(
      uniqueKeysWithValues: errors.enumerated().map {
        (AnyHashable($0.offset), $0.element as Error)
      })
    return CKError(.partialFailure, userInfo: [CKPartialErrorsByItemIDKey: items])
  }
}

@MainActor private final class CloudFixture {
  let client = ScheduleCloudClientFake()
  let legacy = LegacyScheduleFake()
  let state = ScheduleCloudStateStoreFake()
  let service: ScheduleCloudService
  var local: ScheduleSnapshot
  var acceptsSnapshots = true
  var acceptedSnapshots: [ScheduleSnapshot] = []
  var pauses: [ScheduleCloudService.PauseReason] = []

  init(local: ScheduleSnapshot, state initialState: ScheduleCloudState = ScheduleCloudState()) {
    self.local = local
    state.value = initialState
    if !initialState.zoneCreated { client.zoneError = CKError(.zoneNotFound) }
    service = ScheduleCloudService(client: client, legacy: legacy, stateStore: state)
    service.currentSnapshot = { [weak self] in self?.local ?? .empty }
    service.acceptSnapshot = { [weak self] snapshot in
      guard let self else { return false }
      self.acceptedSnapshots.append(snapshot)
      guard self.acceptsSnapshots else { return false }
      self.local = snapshot
      return true
    }
    service.onPause = { [weak self] reason in self?.pauses.append(reason) }
  }
}

@MainActor private final class ScheduleCloudClientFake: ScheduleCloudClient {
  var ownerID = "original-owner"
  var accountError: Error?
  var zoneError: Error?
  var recordError: Error?
  var saveError: Error?
  var saveErrors: [Error] = []
  var record: CKRecord?
  var beforeSaveCompletes: ((Int) -> Void)?
  var accountRequests = 0
  var zoneRequests = 0
  var zonesCreated = 0
  var zonesDeleted = 0
  var attemptedSnapshots: [ScheduleSnapshot] = []
  var attemptedRecords: [CKRecord] = []
  var savedSnapshots: [ScheduleSnapshot] = []

  func accountID() async throws -> String {
    accountRequests += 1
    if let accountError { throw accountError }
    return ownerID
  }
  func fetchZone() async throws {
    zoneRequests += 1
    if let zoneError { throw zoneError }
  }
  func createZone() async throws {
    zonesCreated += 1
    zoneError = nil
  }
  func deleteZone() async throws {
    zonesDeleted += 1
    record = nil
  }
  func fetchRecord() async throws -> CKRecord? {
    if let recordError { throw recordError }
    guard let record else { return nil }
    return try XCTUnwrap(record.copy() as? CKRecord)
  }
  func saveRecord(_ record: CKRecord) async throws -> CKRecord {
    let submitted = try ScheduleCloudPayload.read(record)
    attemptedSnapshots.append(submitted)
    attemptedRecords.append(record)
    beforeSaveCompletes?(attemptedSnapshots.count)
    if !saveErrors.isEmpty { throw saveErrors.removeFirst() }
    if let saveError { throw saveError }
    savedSnapshots.append(submitted)
    self.record = try XCTUnwrap(record.copy() as? CKRecord)
    return try XCTUnwrap(record.copy() as? CKRecord)
  }
  func ensureSubscription() async throws {}
}

@MainActor private final class LegacyScheduleFake: LegacyScheduleAccess {
  var bytes: Data?
  var reads = 0
  var removed: [Data] = []

  func read() -> Data? {
    reads += 1
    return bytes
  }
  func remove(ifUnchanged data: Data) -> Bool {
    guard bytes == data else { return false }
    removed.append(data)
    bytes = nil
    return true
  }
}

@MainActor private final class ScheduleCloudStateStoreFake: ScheduleCloudStateStore {
  var value = ScheduleCloudState()
  var saveError: Error?
  func load() throws -> ScheduleCloudState { value }
  func save(_ state: ScheduleCloudState) throws {
    if let saveError { throw saveError }
    value = state
  }
}
