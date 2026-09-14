import Foundation

/// A break follows local calendar dates when travelling, just like the usual week.
/// The resume date is the first day that uses the usual schedule again.
struct ScheduleBreak: Codable, Equatable, Sendable, Identifiable {
  var id = UUID()
  var startDay: String
  var resumeDay: String
  var modifiedAt: Date
  var deleted: Bool? = nil

  func contains(_ key: String) -> Bool {
    deleted != true && startDay <= key && key < resumeDay
  }

  func validate(calendar: Calendar) throws {
    guard let start = LocalDay.date(startDay, calendar: calendar),
      let resume = LocalDay.date(resumeDay, calendar: calendar), start < resume,
      modifiedAt.timeIntervalSince1970.isFinite
    else { throw ScheduleError.invalidDate }
  }
}

extension ScheduleEngine {
  func isDayOff(on date: Date) -> Bool {
    let key = LocalDay.key(date, calendar: calendar)
    return plan(on: date)?.isDayOff == true
      || (snapshot.breaks ?? []).contains { $0.contains(key) }
  }

  /// Restrict overnight and travel exceptions at the first unrestricted local day.
  /// An unrestricted day is never represented as a 24-hour eating window.
  func restrictingToScheduledDays(_ window: EatingWindow) -> EatingWindow? {
    guard !isDayOff(on: window.opening) else { return nil }
    var result = window
    var day = calendar.startOfDay(for: window.opening)
    while let following = calendar.date(byAdding: .day, value: 1, to: day),
      following < window.closing
    {
      if isDayOff(on: following) {
        result.closing = following
        break
      }
      day = following
    }
    return result
  }

  func nextWindow(after now: Date) -> EatingWindow? {
    // A fixed eight-day search cannot find the next window during a longer break.
    // Each dated break or future version gives another possible resumption point.
    let candidates =
      [now]
      + (snapshot.breaks ?? []).filter { $0.deleted != true }.compactMap {
        LocalDay.date($0.resumeDay, calendar: calendar)
      }
      + snapshot.versions.compactMap { LocalDay.date($0.effectiveDay, calendar: calendar) }
      + snapshot.overrides.filter { $0.deleted != true }.map(\.window.opening)
    for day in Set(candidates.filter { $0 >= now }).sorted() {
      if let window = windows(around: day, daysBefore: 0, daysAfter: 8).first(where: {
        $0.opening > now && $0.closing > $0.opening
      }) {
        return window
      }
    }
    return nil
  }

  func latestDayOffEnd(before now: Date) -> Date? {
    let endings = (0...7).compactMap { offset -> Date? in
      guard let day = calendar.date(byAdding: .day, value: -offset, to: now),
        let previous = calendar.date(byAdding: .day, value: -1, to: day),
        isDayOff(on: previous)
      else { return nil }
      return calendar.startOfDay(for: day)
    }
    return endings.filter { $0 <= now }.max()
  }

  func nextDayOff(after now: Date, before nextOpening: Date?) -> Date? {
    let followingWeek = (1...7).compactMap {
      calendar.date(byAdding: .day, value: $0, to: calendar.startOfDay(for: now))
    }
    let datedStarts = (snapshot.breaks ?? []).filter { $0.deleted != true }.compactMap {
      LocalDay.date($0.startDay, calendar: calendar)
    }
    let changedWeeks = snapshot.versions.compactMap {
      LocalDay.date($0.effectiveDay, calendar: calendar)
    }.filter { $0 > now }.flatMap { start in
      (0...6).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
    return (followingWeek + datedStarts + changedWeeks).filter {
      $0 > now && (nextOpening == nil || $0 < nextOpening!) && isDayOff(on: $0)
    }.min()
  }

  func takingBreak(from start: Date, resuming resume: Date, at now: Date, modifiedAt: Date) throws
    -> ScheduleSnapshot
  {
    try validate(near: now)
    guard !snapshot.versions.isEmpty,
      calendar.startOfDay(for: start) >= calendar.startOfDay(for: now)
    else { throw ScheduleError.invalidDate }
    let item = ScheduleBreak(
      startDay: LocalDay.key(start, calendar: calendar),
      resumeDay: LocalDay.key(resume, calendar: calendar), modifiedAt: modifiedAt)
    try item.validate(calendar: calendar)
    var result = snapshot
    result.schema = 2
    var breaks = result.breaks ?? []
    breaks.append(item)
    result.breaks = breaks
    result.revision = modifiedAt
    try ScheduleEngine(snapshot: result, calendar: calendar).validate(near: now)
    return result
  }

  /// Ending an active break preserves past off days for the following day's review.
  func endingBreak(_ id: UUID, at now: Date, modifiedAt: Date) throws -> ScheduleSnapshot {
    try validate(near: now)
    var result = snapshot
    guard var breaks = result.breaks, let index = breaks.firstIndex(where: { $0.id == id }) else {
      return result
    }
    let key = LocalDay.key(now, calendar: calendar)
    guard breaks[index].deleted != true, breaks[index].resumeDay > key else { return result }
    if breaks[index].startDay < key {
      breaks[index].resumeDay = key
    } else {
      breaks[index].deleted = true
    }
    breaks[index].modifiedAt = modifiedAt
    result.breaks = breaks
    result.schema = 2
    result.revision = modifiedAt
    try ScheduleEngine(snapshot: result, calendar: calendar).validate(near: now)
    return result
  }
}
