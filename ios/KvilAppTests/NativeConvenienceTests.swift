import XCTest

@testable import KvilApp

final class NativeConvenienceTests: XCTestCase {
  let calendar = LocalDay.calendar(timeZone: TimeZone(secondsFromGMT: 0)!)

  private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
  private func snapshot(_ days: [DayPlan] = DayPlan.initial) -> ScheduleSnapshot {
    ScheduleSnapshot(
      revision: date("2026-01-01T00:00:00Z"),
      versions: [ScheduleVersion(effectiveDay: "2025-01-01", days: days)], overrides: [])
  }

  func testLeadTimeReplacesBoundaryNotificationAndRespectsEachToggle() {
    var preferences = Preferences()
    preferences.openingReminder = true
    preferences.closingReminder = true
    preferences.openingReminderLeadMinutes = 15
    preferences.closingReminderLeadMinutes = 30
    let now = date("2026-09-12T00:00:00Z")
    let plan = ReminderPlan.make(
      snapshot: snapshot(), preferences: preferences, now: now, calendar: calendar)
    let today = plan.events.filter { calendar.isDate($0.date, inSameDayAs: now) }
    XCTAssertEqual(today.map(\.date), [date("2026-09-12T09:45:00Z"), date("2026-09-12T17:30:00Z")])
    XCTAssertEqual(today.map(\.leadMinutes), [15, 30])
    XCTAssertEqual(plan.events.count, Set(plan.events.map(\.id)).count)
    XCTAssertLessThanOrEqual(plan.events.count, 64)
    preferences.closingReminder = false
    let openingOnly = ReminderPlan.make(
      snapshot: snapshot(), preferences: preferences, now: now, calendar: calendar)
    XCTAssertTrue(openingOnly.events.allSatisfy(\.opening))
  }

  func testLeadTimeInPastIsNotReplacedByASecondBoundaryReminder() {
    var preferences = Preferences()
    preferences.openingReminder = true
    preferences.openingReminderLeadMinutes = 30
    let now = date("2026-09-12T09:40:00Z")
    let plan = ReminderPlan.make(
      snapshot: snapshot(), preferences: preferences, now: now, calendar: calendar)
    XCTAssertEqual(plan.events.first?.date, date("2026-09-13T09:30:00Z"))
  }

  func testReminderLeadUsesElapsedMinutesAcrossSpringDSTGap() {
    let oslo = LocalDay.calendar(timeZone: TimeZone(identifier: "Europe/Oslo")!)
    let days = (1...7).map {
      DayPlan(weekday: $0, opens: WallTime(hour: 3), closes: WallTime(hour: 8))
    }
    var preferences = Preferences()
    preferences.openingReminder = true
    preferences.openingReminderLeadMinutes = 30
    let plan = ReminderPlan.make(
      snapshot: snapshot(days), preferences: preferences, now: date("2026-03-29T00:00:00Z"),
      calendar: oslo)
    XCTAssertEqual(plan.events.first?.date, date("2026-03-29T00:30:00Z"))
  }

  func testDaysOffSuppressTheirRemindersAndPreviousOvernightClippedClose() {
    var days = (1...7).map {
      DayPlan(weekday: $0, opens: WallTime(hour: 20), closes: WallTime(hour: 4))
    }
    days[6].dayOff = true
    var preferences = Preferences()
    preferences.openingReminder = true
    preferences.closingReminder = true
    preferences.closingReminderLeadMinutes = 30
    let plan = ReminderPlan.make(
      snapshot: snapshot(days), preferences: preferences, now: date("2026-09-11T19:00:00Z"),
      calendar: calendar)
    XCTAssertFalse(plan.events.contains { $0.date == date("2026-09-11T23:30:00Z") })
    XCTAssertFalse(
      plan.events.contains { calendar.isDate($0.date, inSameDayAs: date("2026-09-12T12:00:00Z")) })
    XCTAssertEqual(plan.events.first?.date, date("2026-09-11T20:00:00Z"))
  }

  func testOpeningActivityStartsOnlyWithinEightHoursAndEndsAtOpening() {
    let plan = snapshot()
    XCTAssertNil(
      OpeningActivityPlan.make(
        snapshot: plan, now: date("2026-09-12T01:59:59Z"), calendar: calendar))
    XCTAssertEqual(
      OpeningActivityPlan.make(
        snapshot: plan, now: date("2026-09-12T02:00:00Z"), calendar: calendar)?.opening,
      date("2026-09-12T10:00:00Z"))
    XCTAssertNil(
      OpeningActivityPlan.make(
        snapshot: plan, now: date("2026-09-12T10:00:00Z"), calendar: calendar))
  }

  func testOpeningActivityStaysOffOnDayOffEvenNearNextOpening() {
    var days = DayPlan.initial
    days[6].dayOff = true
    days[0].opens = WallTime(hour: 2)
    let plan = OpeningActivityPlan.make(
      snapshot: snapshot(days), now: date("2026-09-12T23:00:00Z"), calendar: calendar)
    XCTAssertNil(plan)
  }

  func testLegacyPreferencesKeepBoundaryRemindersAndLiveActivitiesOff() throws {
    var original = try XCTUnwrap(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(Preferences())) as? [String: Any])
    original.removeValue(forKey: "openingReminderLeadMinutes")
    original.removeValue(forKey: "closingReminderLeadMinutes")
    original.removeValue(forKey: "liveActivitiesEnabled")
    let decoded = try JSONDecoder().decode(
      Preferences.self, from: JSONSerialization.data(withJSONObject: original))
    XCTAssertEqual(decoded.openingReminderLeadMinutes ?? 0, 0)
    XCTAssertEqual(decoded.closingReminderLeadMinutes ?? 0, 0)
    XCTAssertFalse(decoded.liveActivitiesEnabled == true)
  }

  func testScheduleQueryDistinguishesNoPlanOpenFutureAndUnrestrictedDays() {
    let format = Date.FormatStyle(
      date: .abbreviated, time: .shortened, calendar: calendar, timeZone: calendar.timeZone)
    let saturdayOpening = date("2026-09-12T10:00:00Z").formatted(format)
    let sundayOpening = date("2026-09-13T10:00:00Z").formatted(format)
    XCTAssertEqual(
      ScheduleQuery.reply(snapshot: .empty, now: date("2026-09-12T08:00:00Z"), calendar: calendar),
      .shortcutSetUp)
    XCTAssertEqual(
      ScheduleQuery.reply(
        snapshot: snapshot(), now: date("2026-09-12T08:00:00Z"), calendar: calendar),
      .shortcutNextOpeningReply(saturdayOpening))
    XCTAssertEqual(
      ScheduleQuery.reply(
        snapshot: snapshot(), now: date("2026-09-12T12:00:00Z"), calendar: calendar),
      .shortcutOpenReply(sundayOpening))
    var days = DayPlan.initial
    days[6].dayOff = true
    XCTAssertEqual(
      ScheduleQuery.reply(
        snapshot: snapshot(days), now: date("2026-09-12T12:00:00Z"), calendar: calendar),
      .shortcutDayOffReply(sundayOpening))
    // Before a day off, Siri reports the next planned opening date, without claiming a long fast.
    XCTAssertEqual(
      ScheduleQuery.reply(
        snapshot: snapshot(days), now: date("2026-09-11T19:00:00Z"), calendar: calendar),
      .shortcutNextOpeningReply(sundayOpening))
    for index in days.indices { days[index].dayOff = true }
    XCTAssertEqual(
      ScheduleQuery.reply(
        snapshot: snapshot(days), now: date("2026-09-12T12:00:00Z"), calendar: calendar),
      .shortcutNoWindow)
  }
}
