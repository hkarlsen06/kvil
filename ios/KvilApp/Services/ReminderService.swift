import BackgroundTasks
import Foundation
import UserNotifications

struct ReminderEvent: Equatable, Sendable, Identifiable {
  var date: Date
  var opening: Bool
  var leadMinutes: Int = 0
  var id: String { "kvil.\(opening ? "open" : "close").\(Int(date.timeIntervalSince1970))" }
}
struct ReminderPlan: Sendable {
  var events: [ReminderEvent]
  var scheduledThrough: Date
  static func make(
    snapshot: ScheduleSnapshot, preferences: Preferences, now: Date, calendar: Calendar
  ) -> Self {
    let horizon = calendar.date(byAdding: .day, value: 27, to: calendar.startOfDay(for: now)) ?? now
    let engine = ScheduleEngine(snapshot: snapshot, calendar: calendar)
    let openingLead = preferences.openingReminderLead
    let closingLead = preferences.closingReminderLead
    let events = engine.windows(
      around: now, daysBefore: 1, daysAfter: 28
    ).flatMap { w in
      [
        ReminderEvent(
          date: w.opening.addingTimeInterval(-Double(openingLead * 60)), opening: true,
          leadMinutes: openingLead),
        ReminderEvent(
          date: w.closing.addingTimeInterval(-Double(closingLead * 60)), opening: false,
          leadMinutes: closingLead),
      ]
    }.filter {
      $0.date > now && $0.date <= horizon
        // A day off has no reminder, including an overnight window clipped at midnight.
        && !engine.isDayOff(on: $0.date)
        && !engine.isDayOff(on: $0.date.addingTimeInterval(Double($0.leadMinutes * 60)))
        && ($0.opening ? preferences.openingReminder : preferences.closingReminder)
    }
    return Self(events: events.sorted { $0.date < $1.date }, scheduledThrough: horizon)
  }
}

actor ReminderService {
  static let backgroundID = "dev.hkarlsen06.kvil.reminders"
  private let center = UNUserNotificationCenter.current()
  func requestAuthorization() async throws -> Bool {
    try await center.requestAuthorization(options: [.alert, .sound])
  }
  func status() async -> UNAuthorizationStatus {
    await center.notificationSettings().authorizationStatus
  }
  func reconcile(snapshot: ScheduleSnapshot, preferences: Preferences, now: Date = Date())
    async throws -> Date?
  {
    let calendar = LocalDay.calendar()
    let plan = ReminderPlan.make(
      snapshot: snapshot, preferences: preferences, now: now, calendar: calendar)
    let existing = await center.pendingNotificationRequests().filter {
      $0.identifier.hasPrefix("kvil.")
    }
    let desired = Set(plan.events.map(\.id))
    // Cancel outdated events before adding replacements; old schedule must not continue firing.
    center.removePendingNotificationRequests(
      withIdentifiers: existing.map(\.identifier).filter { !desired.contains($0) })
    guard preferences.openingReminder || preferences.closingReminder else { return nil }
    let authorization = await status()
    guard authorization == .authorized || authorization == .provisional else { return nil }
    for event in plan.events {
      try Task.checkCancellation()
      let content = UNMutableNotificationContent()
      if event.leadMinutes > 0 {
        content.title = String(
          localized: event.opening ? .reminderOpeningSoon : .reminderClosingSoon)
        content.body = String(
          localized: event.opening
            ? .reminderOpensIn(event.leadMinutes) : .reminderClosesIn(event.leadMinutes))
      } else {
        content.title = String(
          localized: event.opening ? .reminderOpenTitle : .reminderCloseTitle)
        content.body = String(
          localized: event.opening ? .reminderOpenBody : .reminderCloseBody)
      }
      content.sound = .default
      var components = calendar.dateComponents(
        [.year, .month, .day, .hour, .minute, .second], from: event.date)
      components.timeZone = calendar.timeZone
      let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
      try await center.add(
        UNNotificationRequest(identifier: event.id, content: content, trigger: trigger))
    }
    return plan.scheduledThrough
  }
  func clear() async {
    let ids = await center.pendingNotificationRequests().filter { $0.identifier.hasPrefix("kvil.") }
      .map(\.identifier)
    center.removePendingNotificationRequests(withIdentifiers: ids)
    center.removeAllDeliveredNotifications()
  }
  nonisolated func scheduleRefresh() async {
    let request = BGAppRefreshTaskRequest(identifier: Self.backgroundID)
    request.earliestBeginDate = Date(timeIntervalSinceNow: 12 * 3600)
    try? await BGTaskScheduler.shared.submitTaskRequest(request)
  }
}
