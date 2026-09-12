import XCTest

@testable import KvilApp

final class ScheduleMergeTests: XCTestCase {
  func baseline() -> ScheduleSnapshot {
    let stamp = Date(timeIntervalSince1970: 1000)
    let days = DayPlan.initial.map { d in
      var d = d
      d.modifiedAt = stamp
      return d
    }
    return ScheduleSnapshot(
      revision: stamp,
      versions: [ScheduleVersion(effectiveDay: "2026-01-01", days: days, modifiedAt: stamp)],
      overrides: [])
  }
  func testConcurrentWeekdayEditsConvergeWithoutLosingEitherDay() throws {
    var a = baseline()
    var b = a
    let later = a.revision.addingTimeInterval(10)
    a.versions[0].days[1].opens = .init(hour: 11)
    a.versions[0].days[1].modifiedAt = later
    b.versions[0].days[2].opens = .init(hour: 12)
    b.versions[0].days[2].modifiedAt = later
    let merged = try ScheduleMerge.merge(a, b)
    XCTAssertEqual(merged.versions[0].days[1].opens.hour, 11)
    XCTAssertEqual(merged.versions[0].days[2].opens.hour, 12)
    XCTAssertEqual(try ScheduleMerge.merge(b, a), merged)
    XCTAssertEqual(try ScheduleMerge.merge(merged, a), merged)
  }
  func testOverrideDeletionSurvivesOfflineOldCopy() throws {
    var a = baseline()
    let day = Date(timeIntervalSince1970: 1_789_200_000)
    let c = LocalDay.calendar(timeZone: TimeZone(secondsFromGMT: 0)!)
    let item = DayOverride(
      dayKey: LocalDay.key(day, calendar: c), timeZoneID: c.timeZone.identifier,
      opening: day.addingTimeInterval(12 * 3600), closing: day.addingTimeInterval(20 * 3600),
      modifiedAt: a.revision)
    a.overrides = [item]
    var b = a
    b.overrides[0].deleted = true
    b.overrides[0].modifiedAt = a.revision.addingTimeInterval(20)
    XCTAssertEqual(try ScheduleMerge.merge(a, b).overrides.first?.deleted, true)
  }
  func testResetDoesNotResurrectOldSchedules() throws {
    let old = baseline()
    let now = Date()
    let erased = ScheduleSnapshot(revision: now, versions: [], overrides: [], resetAt: now)
    XCTAssertTrue(try ScheduleMerge.merge(old, erased).versions.isEmpty)
    XCTAssertTrue(try ScheduleMerge.merge(erased, old).versions.isEmpty)
  }
  func testMergeCannotProduceOverlappingWindows() throws {
    var a = baseline()
    var b = a
    a.versions[0].days[0].opens = .init(hour: 22)
    a.versions[0].days[0].closes = .init(hour: 9)
    a.versions[0].days[0].modifiedAt = Date()
    b.versions[0].days[1].opens = .init(hour: 8)
    b.versions[0].days[1].modifiedAt = Date()
    XCTAssertThrowsError(try ScheduleMerge.merge(a, b))
  }
  @MainActor func testResetMarkerSurvivesLocalStoreReload() throws {
    let store = try LocalStore(inMemory: true)
    var data = LocalData()
    data.schedule.resetAt = Date()
    try store.save(data)
    XCTAssertEqual(try store.load().schedule.resetAt, data.schedule.resetAt)
  }
}
