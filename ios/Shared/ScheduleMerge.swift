import Foundation

/// Merges only schedule configuration. Reflection and weight types never cross this boundary.
enum ScheduleMerge {
  static func merge(_ local: ScheduleSnapshot, _ remote: ScheduleSnapshot) throws
    -> ScheduleSnapshot
  {
    let c = LocalDay.calendar()
    try ScheduleEngine(snapshot: local, calendar: c).validate(near: Date())
    try ScheduleEngine(snapshot: remote, calendar: c).validate(near: Date())
    let reset = [local.resetAt, remote.resetAt].compactMap { $0 }.max()
    let versions = (local.versions + remote.versions).filter {
      reset == nil || ($0.modifiedAt ?? .distantPast) > reset!
    }
    var mergedVersions: [ScheduleVersion] = []
    for group in Dictionary(grouping: versions, by: \.effectiveDay).values {
      var selected = group.min { $0.id.uuidString < $1.id.uuidString }!
      selected.modifiedAt = group.compactMap(\.modifiedAt).max()
      selected.days = (1...7).compactMap { weekday in
        group.flatMap(\.days).filter { $0.weekday == weekday }.max { a, b in
          if a.modifiedAt != b.modifiedAt {
            return (a.modifiedAt ?? .distantPast) < (b.modifiedAt ?? .distantPast)
          }
          return a.opens.minute * 1440 + a.closes.minute < b.opens.minute * 1440 + b.closes.minute
        }
      }
      mergedVersions.append(selected)
    }
    let overrides = (local.overrides + remote.overrides).filter {
      reset == nil || ($0.modifiedAt ?? .distantPast) > reset!
    }
    let mergedOverrides = Dictionary(grouping: overrides, by: \.id).values.compactMap { group in
      group.max { a, b in
        if a.modifiedAt != b.modifiedAt {
          return (a.modifiedAt ?? .distantPast) < (b.modifiedAt ?? .distantPast)
        }
        if a.deleted != b.deleted { return a.deleted != true }
        if a.opening != b.opening { return a.opening < b.opening }
        return a.closing < b.closing
      }
    }
    let result = ScheduleSnapshot(
      revision: max(local.revision, remote.revision),
      versions: mergedVersions.sorted { $0.effectiveDay < $1.effectiveDay },
      overrides: mergedOverrides.sorted { $0.id < $1.id }, resetAt: reset)
    try ScheduleEngine(snapshot: result, calendar: c).validate(near: Date())
    return result
  }
}
