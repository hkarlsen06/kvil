#if DEBUG
  import CloudKit
  import XCTest

  @testable import KvilApp

  @MainActor final class CloudKitLiveTests: XCTestCase {
    // Requires a signed Debug host and an iCloud account. Ordinary test runs
    // skip before constructing CloudKit. All mutations use this run's QA zone.
    func testLiveEncryptedRoundTripConflictAndIsolatedZoneRecovery() async throws {
      guard ProcessInfo.processInfo.environment["KVIL_RUN_LIVE_CLOUDKIT"] == "1" else {
        throw XCTSkip("Set KVIL_RUN_LIVE_CLOUDKIT=1 to run the isolated live CloudKit audit.")
      }
      let runID = UUID()
      let zoneID = CloudKitScheduleClient.auditZoneID(for: runID)
      let recordID = CKRecord.ID(recordName: "current", zoneID: zoneID)
      guard zoneID.zoneName == "KvilQA-\(runID.uuidString)",
        zoneID != CloudKitScheduleClient.zoneID
      else { throw AuditError.unsafeNamespace }
      let first = CloudKitScheduleClient(auditRunID: runID)
      let second = CloudKitScheduleClient(auditRunID: runID)
      var checkpoints: [String] = []
      var cleanupSucceeded = false
      defer {
        let report: [String: Any] = [
          "runID": runID.uuidString, "zone": zoneID.zoneName,
          "fictionalDataOnly": true, "checkpoints": checkpoints,
          "cleanupSucceeded": cleanupSucceeded,
        ]
        if let bytes = try? JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]) {
          let attachment = XCTAttachment(data: bytes, uniformTypeIdentifier: "public.json")
          attachment.name = "Isolated live CloudKit audit"
          attachment.lifetime = .keepAlways
          add(attachment)
        }
      }
      let owner = try await first.accountID()
      guard try await second.accountID() == owner else { throw AuditError.accountChanged }
      checkpoints.append("same signed-in account")

      // Refuse to reuse a namespace, even though its name contains a fresh UUID.
      try await expectMissingZone(first)
      checkpoints.append("new QA zone absent")
      do {
        try await first.createZone()
        try await second.fetchZone()
        let initiallyMissing = try await second.fetchRecord()
        XCTAssertNil(initiallyMissing)
        checkpoints.append("QA zone created; record initially absent")

        let baseline = fictionalSnapshot(id: runID)
        let original = CKRecord(recordType: CloudKitScheduleClient.recordType, recordID: recordID)
        try ScheduleCloudPayload.write(baseline, to: original)
        let acknowledged = try await first.saveRecord(original)
        XCTAssertFalse(acknowledged.recordChangeTag?.isEmpty ?? true)
        XCTAssertEqual(try payload(acknowledged, recordID: recordID), baseline)
        let initialFetch = try await requireRecord(second)
        XCTAssertEqual(try payload(initialFetch, recordID: recordID), baseline)
        try await first.ensureSubscription()
        checkpoints.append("encrypted payload acknowledged and independently fetched; subscription saved")

        // Both clients start with the same server version, then edit different
        // weekdays locally without fetching each other's edits.
        let staleFirst = try await requireRecord(first)
        let staleSecond = try await requireRecord(second)
        let firstEdit = edited(baseline, day: 0, hour: 9, seconds: 1)
        let secondEdit = edited(baseline, day: 1, hour: 11, seconds: 2)
        try ScheduleCloudPayload.write(firstEdit, to: staleFirst)
        _ = try await first.saveRecord(staleFirst)
        try ScheduleCloudPayload.write(secondEdit, to: staleSecond)
        let conflict = try await conflictingSave(second, record: staleSecond)
        let merged = try ScheduleMerge.merge(secondEdit, payload(conflict, recordID: recordID))
        XCTAssertEqual(merged.versions[0].days[0].opens.hour, 9)
        XCTAssertEqual(merged.versions[0].days[1].opens.hour, 11)
        try ScheduleCloudPayload.write(merged, to: conflict)
        _ = try await second.saveRecord(conflict)
        let convergedFirst = try await requireRecord(first)
        let convergedSecond = try await requireRecord(second)
        XCTAssertEqual(try payload(convergedFirst, recordID: recordID), merged)
        XCTAssertEqual(try payload(convergedSecond, recordID: recordID), merged)
        checkpoints.append("real stale-write conflict; independent weekday edits converge")

        // A stale client must retain the reset tombstone when resolving its real
        // server conflict, preventing the old fixture from being resurrected.
        var cleared = ScheduleSnapshot.empty
        cleared.revision = baseline.revision.addingTimeInterval(3)
        cleared.resetAt = cleared.revision
        try ScheduleCloudPayload.write(cleared, to: convergedFirst)
        _ = try await first.saveRecord(convergedFirst)
        try ScheduleCloudPayload.write(secondEdit, to: convergedSecond)
        let resetConflict = try await conflictingSave(second, record: convergedSecond)
        let afterReset = try ScheduleMerge.merge(secondEdit, payload(resetConflict, recordID: recordID))
        XCTAssertTrue(afterReset.versions.isEmpty)
        XCTAssertEqual(afterReset.resetAt, cleared.resetAt)
        try ScheduleCloudPayload.write(afterReset, to: resetConflict)
        _ = try await second.saveRecord(resetConflict)
        checkpoints.append("reset tombstone survives stale-client conflict")

        let cancelledRecord = try await requireRecord(first)
        try ScheduleCloudPayload.write(baseline, to: cancelledRecord)
        let cancelled = Task { try await first.saveRecord(cancelledRecord) }
        cancelled.cancel()
        do {
          _ = try await cancelled.value
          throw AuditError.cancellationNotObserved
        } catch is CancellationError {}
        let afterCancellation = try await requireRecord(second)
        XCTAssertEqual(try payload(afterCancellation, recordID: recordID), afterReset)
        checkpoints.append("cancelled-before-submit write leaves cloud data unchanged")

        try await first.deleteAuditSubscription()
        try await first.deleteZone()
        try await expectMissingZone(second)
        checkpoints.append("only QA zone deleted; real zoneNotFound observed")

        // This explicit test step checks native reprovisioning. It does not reset
        // iCloud Keychain or represent a real CKErrorUserDidResetEncryptedDataKey.
        try await first.createZone()
        let missingAfterRecreation = try await second.fetchRecord()
        XCTAssertNil(missingAfterRecreation)
        let recreated = CKRecord(recordType: CloudKitScheduleClient.recordType, recordID: recordID)
        try ScheduleCloudPayload.write(merged, to: recreated)
        _ = try await first.saveRecord(recreated)
        let recovered = try await requireRecord(second)
        XCTAssertEqual(try payload(recovered, recordID: recordID), merged)
        checkpoints.append("explicit QA zone recreation and encrypted round trip")
      } catch {
        do {
          try await cleanup(first, owner: owner)
          cleanupSucceeded = true
        } catch {
          XCTFail("QA cleanup failed; use the audit attachment's exact UUID zone for follow-up.")
        }
        throw error
      }
      try await cleanup(first, owner: owner)
      cleanupSucceeded = true
      checkpoints.append("QA subscription and zone cleaned up")
    }

    private func requireRecord(_ client: CloudKitScheduleClient) async throws -> CKRecord {
      let record = try await client.fetchRecord()
      return try XCTUnwrap(record)
    }

    private func payload(_ record: CKRecord, recordID: CKRecord.ID) throws -> ScheduleSnapshot {
      guard record.recordID == recordID,
        record.recordType == CloudKitScheduleClient.recordType,
        Set(record.allKeys()) == ["payload"],
        Set(record.encryptedValues.allKeys()) == ["payload"],
        let bytes = record.encryptedValues["payload"] as? Data
      else { throw AuditError.invalidEncryptedRecord }
      return try ScheduleCloudPayload.decode(bytes)
    }

    private func expectMissingZone(_ client: CloudKitScheduleClient) async throws {
      do {
        try await client.fetchZone()
        throw AuditError.expectedMissingZone
      } catch let error as CKError {
        guard ScheduleCloudErrors.contains(.zoneNotFound, in: error),
          !ScheduleCloudErrors.encryptedReset(error),
          !ScheduleCloudErrors.contains(.userDeletedZone, in: error)
        else { throw error }
      }
    }

    private func conflictingSave(
      _ client: CloudKitScheduleClient, record: CKRecord
    ) async throws -> CKRecord {
      do {
        _ = try await client.saveRecord(record)
        throw AuditError.expectedConflict
      } catch let error as CKError {
        guard let conflict = ScheduleCloudErrors.items(error).first(where: {
          $0.code == .serverRecordChanged
        }),
          let server = conflict.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord
        else { throw error }
        return server
      }
    }

    private func cleanup(_ client: CloudKitScheduleClient, owner: String) async throws {
      guard try await client.accountID() == owner else { throw AuditError.accountChanged }
      var failure: Error?
      do { try await client.deleteAuditSubscription() } catch { failure = error }
      do { try await client.deleteZone() } catch {
        if !ScheduleCloudErrors.contains(.zoneNotFound, in: error)
          && !ScheduleCloudErrors.contains(.unknownItem, in: error) { failure = failure ?? error }
      }
      if let failure { throw failure }
    }

    private func fictionalSnapshot(id: UUID) -> ScheduleSnapshot {
      let stamp = Date().addingTimeInterval(-60)
      let days = DayPlan.initial.map { value in
        var day = value
        day.modifiedAt = stamp
        return day
      }
      return ScheduleSnapshot(
        revision: stamp,
        versions: [ScheduleVersion(id: id, effectiveDay: "2026-01-01", days: days, modifiedAt: stamp)],
        overrides: [])
    }

    private func edited(
      _ snapshot: ScheduleSnapshot, day: Int, hour: Int, seconds: TimeInterval
    ) -> ScheduleSnapshot {
      var next = snapshot
      next.revision = snapshot.revision.addingTimeInterval(seconds)
      next.versions[0].modifiedAt = next.revision
      next.versions[0].days[day].modifiedAt = next.revision
      next.versions[0].days[day].opens = .init(hour: hour)
      return next
    }

    private enum AuditError: Error {
      case unsafeNamespace, accountChanged, expectedMissingZone, expectedConflict
      case invalidEncryptedRecord, cancellationNotObserved
    }
  }
#endif
