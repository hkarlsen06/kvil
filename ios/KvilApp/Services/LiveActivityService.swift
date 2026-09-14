import ActivityKit
import Foundation
import UIKit

struct OpeningActivityPlan: Equatable, Sendable {
  var dayKey: String
  var timeZoneID: String
  var opening: Date

  static func make(snapshot: ScheduleSnapshot, now: Date, calendar: Calendar) -> Self? {
    guard let state = ScheduleEngine(snapshot: snapshot, calendar: calendar).state(at: now),
      !state.isOpen, !state.isDayOff, state.upcomingDayOff == nil, let next = state.next,
      next.opening > now, next.opening.timeIntervalSince(now) <= 8 * 3600
    else { return nil }
    return Self(dayKey: next.dayKey, timeZoneID: next.timeZoneID, opening: next.opening)
  }
}

@MainActor final class LiveActivityService {
  // Remember requests across launches so dismissing an activity stays respected for that opening.
  private let defaults: UserDefaults
  private static let lastOpeningKey = "liveActivity.lastOpening"
  private var operation: Task<Void, Error>?

  init(defaults: UserDefaults = .standard) { self.defaults = defaults }

  func reconcile(
    snapshot: ScheduleSnapshot, enabled: Bool, now: Date, calendar: Calendar, allowStart: Bool
  ) async throws {
    // Actor isolation alone does not serialize ActivityKit calls across their awaits.
    // Finish any in-flight mutation before applying the latest requested plan.
    let previous = operation
    previous?.cancel()
    let task = Task {
      _ = await previous?.result
      try Task.checkCancellation()
      try await apply(
        snapshot: snapshot, enabled: enabled, now: max(now, Date()), calendar: calendar,
        allowStart: allowStart)
    }
    operation = task
    try await withTaskCancellationHandler {
      try await task.value
    } onCancel: {
      task.cancel()
    }
  }

  private func apply(
    snapshot: ScheduleSnapshot, enabled: Bool, now: Date, calendar: Calendar, allowStart: Bool
  ) async throws {
    guard enabled, ActivityAuthorizationInfo().areActivitiesEnabled,
      let plan = OpeningActivityPlan.make(snapshot: snapshot, now: now, calendar: calendar)
    else {
      await endActivities(resetDismissal: !enabled)
      return
    }
    let content = ActivityContent(
      state: OpeningActivityAttributes.ContentState(opening: plan.opening), staleDate: plan.opening)
    var retained: Activity<OpeningActivityAttributes>?
    for activity in Activity<OpeningActivityAttributes>.activities {
      try Task.checkCancellation()
      if retained == nil, activity.attributes.dayKey == plan.dayKey,
        activity.attributes.timeZoneID == plan.timeZoneID,
        activity.activityState == .active || activity.activityState == .stale,
        plan.opening.timeIntervalSince(activity.attributes.startedAt) <= 8 * 3600
      {
        retained = activity
        await activity.update(content)
      } else {
        await activity.end(nil, dismissalPolicy: .immediate)
      }
    }
    try Task.checkCancellation()
    let identity =
      plan.timeZoneID + "/" + plan.dayKey + "/" + String(plan.opening.timeIntervalSince1970)
    if retained != nil { defaults.set(identity, forKey: Self.lastOpeningKey) }
    guard retained == nil, allowStart, UIApplication.shared.applicationState == .active,
      plan.opening > Date(), defaults.string(forKey: Self.lastOpeningKey) != identity
    else {
      return
    }
    _ = try Activity.request(
      attributes: OpeningActivityAttributes(
        dayKey: plan.dayKey, timeZoneID: plan.timeZoneID, startedAt: now),
      content: content, pushType: nil)
    defaults.set(identity, forKey: Self.lastOpeningKey)
  }

  func endAll(resetDismissal: Bool = true) async {
    let previous = operation
    previous?.cancel()
    let task = Task<Void, Error> {
      _ = await previous?.result
      // Erasure must finish cleanup even if its caller is canceled.
      await endActivities(resetDismissal: resetDismissal)
    }
    operation = task
    _ = await task.result
  }

  private func endActivities(resetDismissal: Bool) async {
    for activity in Activity<OpeningActivityAttributes>.activities {
      await activity.end(nil, dismissalPolicy: .immediate)
    }
    if resetDismissal { defaults.removeObject(forKey: Self.lastOpeningKey) }
  }
}
