import Foundation

struct SnapshotStore: Sendable {
  static let groupID = "group.dev.hkarlsen06.kvil"
  var directory: URL?
  init(
    directory: URL? = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: groupID)
  ) { self.directory = directory }
  private var url: URL? { directory?.appendingPathComponent("schedule.json") }
  func read() -> ScheduleSnapshot? {
    guard let url, let data = try? Data(contentsOf: url), data.count < 2_000_000,
      let snapshot = try? JSONDecoder().decode(ScheduleSnapshot.self, from: data),
      (try? ScheduleEngine(snapshot: snapshot, calendar: LocalDay.calendar()).validate(near: Date()))
        != nil
    else { return nil }
    return snapshot
  }
  func write(_ snapshot: ScheduleSnapshot) throws {
    guard let url else { throw CocoaError(.fileNoSuchFile) }
    try ScheduleEngine(snapshot: snapshot, calendar: LocalDay.calendar()).validate(near: Date())
    if let current = read(), current.revision > snapshot.revision { return }
    try JSONEncoder().encode(snapshot).write(
      to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    var protectedURL = url
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try protectedURL.setResourceValues(values)
  }
  func clear() throws {
    if let url, FileManager.default.fileExists(atPath: url.path) {
      try FileManager.default.removeItem(at: url)
    }
  }
}
