import Foundation

struct HealthDeletion: Sendable {
  var sampleID: UUID
  var localID: UUID?
  var version: Int?
}

enum WeightReconciliation {
  static func applying(_ deletions: [HealthDeletion], to entries: [WeightEntry]) -> [WeightEntry] {
    entries.filter { entry in
      !deletions.contains { deletion in
        // Replacing a Health sample also deletes the old version. Keep a pending edit.
        guard !entry.healthNeedsUpdate else { return false }
        if entry.healthSampleID == deletion.sampleID { return true }
        return entry.saveToHealth && deletion.localID == entry.id
          && (deletion.version ?? 0) >= entry.healthVersion
      }
    }
  }
}
