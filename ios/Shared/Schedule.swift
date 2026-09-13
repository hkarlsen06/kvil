import Foundation

struct WallTime: Codable, Hashable, Sendable, Comparable {
  var minute: Int
  init(hour: Int, minute: Int = 0) { self.minute = hour * 60 + minute }
  init(minute: Int) { self.minute = minute }
  var hour: Int { minute / 60 }
  var minuteComponent: Int { minute % 60 }
  var isValid: Bool { (0..<1440).contains(minute) }
  static func < (lhs: Self, rhs: Self) -> Bool { lhs.minute < rhs.minute }
  func date(on day: Date, calendar: Calendar) -> Date? {
    guard isValid else { return nil }
    return calendar.date(
      bySettingHour: hour, minute: minuteComponent, second: 0, of: day,
      matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward)
  }
}

struct DayPlan: Codable, Equatable, Sendable, Identifiable {
  var weekday: Int
  var modifiedAt: Date? = nil
  var opens: WallTime
  var closes: WallTime
  var id: Int { weekday }
  var overnight: Bool { closes < opens }
  var windowMinutes: Int { (closes.minute - opens.minute + 1440) % 1440 }

  func shifted(by minutes: Int) -> Self {
    var day = self
    let offset = minutes % 1440 + 1440
    day.opens = WallTime(minute: (opens.minute + offset) % 1440)
    day.closes = WallTime(minute: (closes.minute + offset) % 1440)
    return day
  }

  func resized(to minutes: Int) throws -> Self {
    guard (1..<1440).contains(minutes) else { throw ScheduleError.invalidTime }
    var day = self
    day.closes = WallTime(minute: (opens.minute + minutes) % 1440)
    return day
  }
  static let initial = (1...7).map {
    DayPlan(weekday: $0, opens: .init(hour: 10), closes: .init(hour: 18))
  }
}

struct ScheduleVersion: Codable, Equatable, Sendable, Identifiable {
  var id = UUID()
  var effectiveDay: String
  var days: [DayPlan]
  var modifiedAt: Date? = nil
}

struct DayOverride: Codable, Equatable, Sendable, Identifiable {
  var id: String { dayKey + "@" + timeZoneID }
  var dayKey: String
  var timeZoneID: String
  var opening: Date
  var closing: Date
  var modifiedAt: Date? = nil
  var deleted: Bool? = nil
  // Keep the scheduled bounds so a manual adjustment can be reopened until its usual close.
  var adjustedOpening: Date? = nil
  var adjustedClosing: Date? = nil
  var window: EatingWindow {
    EatingWindow(
      dayKey: dayKey, timeZoneID: timeZoneID, opening: adjustedOpening ?? opening,
      closing: adjustedClosing ?? closing, isOverride: true)
  }
}

struct EatingWindow: Equatable, Sendable, Identifiable {
  var dayKey: String
  var timeZoneID: String
  var opening: Date
  var closing: Date
  var isOverride: Bool
  var id: String { dayKey }
  func contains(_ date: Date) -> Bool { opening <= date && date < closing }
}

struct ScheduleSnapshot: Codable, Equatable, Sendable {
  var schema = 1
  var revision: Date
  var versions: [ScheduleVersion]
  var overrides: [DayOverride]
  var resetAt: Date? = nil
  func forDisplay(now: Date, calendar: Calendar) -> Self {
    let start = calendar.date(byAdding: .day, value: -3, to: now) ?? now
    let key = LocalDay.key(start, calendar: calendar)
    let base = versions.filter { $0.effectiveDay <= key }.max { $0.effectiveDay < $1.effectiveDay }
    var copy = self
    copy.versions = (base.map { [$0] } ?? []) + versions.filter { $0.effectiveDay > key }
    copy.overrides = overrides.filter { $0.closing >= start }
    return copy
  }
  static let empty = ScheduleSnapshot(revision: .distantPast, versions: [], overrides: [])
}

enum ScheduleError: Error, Equatable {
  case invalidTime, missingWeekdays, overlappingWindows, invalidDate, incompatibleData
}

enum LocalDay {
  static func calendar(timeZone: TimeZone = .current) -> Calendar {
    var c = Calendar(identifier: .gregorian)
    c.locale = .current
    c.timeZone = timeZone
    return c
  }
  static func key(_ date: Date, calendar: Calendar) -> String {
    let p = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", p.year ?? 0, p.month ?? 0, p.day ?? 0)
  }
  static func date(_ key: String, calendar: Calendar) -> Date? {
    let parts = key.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3,
      let value = calendar.date(
        from: DateComponents(year: parts[0], month: parts[1], day: parts[2])),
      self.key(value, calendar: calendar) == key
    else { return nil }
    return value
  }
}

struct ScheduleState: Sendable {
  var active: EatingWindow?
  var next: EatingWindow
  var previousClose: Date
  var progress: Double
  var isOpen: Bool { active != nil }
}

struct ScheduleEngine: Sendable {
  var snapshot: ScheduleSnapshot
  var calendar: Calendar

  func plan(on date: Date) -> DayPlan? {
    let key = LocalDay.key(date, calendar: calendar)
    let version = snapshot.versions.filter { $0.effectiveDay <= key }.max {
      $0.effectiveDay < $1.effectiveDay
    }
    return version?.days.first { $0.weekday == calendar.component(.weekday, from: date) }
  }

  func window(on date: Date) -> EatingWindow? {
    let day = calendar.startOfDay(for: date)
    let key = LocalDay.key(day, calendar: calendar)
    if let override = snapshot.overrides.first(where: {
      $0.dayKey == key && $0.timeZoneID == calendar.timeZone.identifier && $0.deleted != true
    }) {
      return override.window
    }
    guard let p = plan(on: day), p.opens != p.closes,
      let opening = p.opens.date(on: day, calendar: calendar),
      let closeDay = calendar.date(byAdding: .day, value: p.overnight ? 1 : 0, to: day),
      let closing = p.closes.date(on: closeDay, calendar: calendar), closing > opening
    else { return nil }
    return EatingWindow(
      dayKey: key, timeZoneID: calendar.timeZone.identifier, opening: opening, closing: closing,
      isOverride: false)
  }

  func windows(around now: Date, daysBefore: Int = 2, daysAfter: Int = 8) -> [EatingWindow] {
    var result = (-daysBefore...daysAfter).compactMap { offset -> EatingWindow? in
      guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { return nil }
      return window(on: day)
    }
    // A travel-day exception keeps its absolute bounds and replaces that local day's plan.
    for item in snapshot.overrides
    where item.timeZoneID != calendar.timeZone.identifier && item.deleted != true {
      guard item.closing > calendar.date(byAdding: .day, value: -daysBefore, to: now) ?? now,
        item.opening < calendar.date(byAdding: .day, value: daysAfter + 1, to: now) ?? now
      else { continue }
      let currentKey = LocalDay.key(item.window.opening, calendar: calendar)
      result.removeAll { $0.dayKey == currentKey || $0.dayKey == item.dayKey }
      result.append(item.window)
    }
    return result.sorted { $0.opening < $1.opening }
  }

  func state(at now: Date) -> ScheduleState? {
    let windows = windows(around: now)
    guard let next = windows.first(where: { $0.opening > now && $0.closing > $0.opening }) else {
      return nil
    }
    let active = windows.first { $0.contains(now) }
    let previousClose =
      windows.last(where: { $0.closing <= now })?.closing ?? calendar.startOfDay(for: now)
    let progress: Double
    if let active {
      let length = active.closing.timeIntervalSince(active.opening)
      progress = min(1, max(0, active.closing.timeIntervalSince(now) / length))
    } else {
      let length = next.opening.timeIntervalSince(previousClose)
      progress = min(1, max(0, length > 0 ? now.timeIntervalSince(previousClose) / length : 0))
    }
    return ScheduleState(
      active: active, next: next, previousClose: previousClose, progress: progress)
  }

  func settingEatingWindowOpen(_ isOpen: Bool, at now: Date, modifiedAt: Date) throws
    -> ScheduleSnapshot
  {
    try validate(near: now)
    guard let state = state(at: now) else { throw ScheduleError.invalidDate }
    guard state.isOpen != isOpen else { return snapshot }
    let window: EatingWindow
    if isOpen {
      // Reopening a window that was closed manually must not pull in the following day.
      window = snapshot.overrides.first {
        $0.deleted != true && $0.adjustedClosing != nil
          && $0.window.opening <= now && now < $0.closing
      }?.window ?? state.next
    } else if let active = state.active {
      window = active
    } else {
      throw ScheduleError.invalidDate
    }
    var item = snapshot.overrides.first {
      $0.dayKey == window.dayKey && $0.timeZoneID == window.timeZoneID && $0.deleted != true
    } ?? DayOverride(
      dayKey: window.dayKey, timeZoneID: window.timeZoneID,
      opening: window.opening, closing: window.closing)
    if isOpen {
      item.adjustedOpening = now
      item.adjustedClosing = nil
    } else {
      item.adjustedClosing = now
    }
    item.modifiedAt = modifiedAt
    var next = snapshot
    next.overrides.removeAll { $0.id == item.id }
    next.overrides.append(item)
    next.revision = modifiedAt
    try ScheduleEngine(snapshot: next, calendar: calendar).validate(near: now)
    return next
  }

  func earlyBreak(at now: Date) -> DayOverride? {
    snapshot.overrides.first {
      $0.deleted != true && $0.adjustedOpening.map { $0 <= now } == true && now < $0.opening
    }
  }

  func undoingEarlyBreak(at now: Date, modifiedAt: Date) throws -> ScheduleSnapshot {
    try validate(near: now)
    guard let item = earlyBreak(at: now),
      let index = snapshot.overrides.firstIndex(where: { $0.id == item.id })
    else { return snapshot }
    var next = snapshot
    // Restore the saved window, including any custom times for this day. Clearing a
    // subsequent early close also prevents the restored window from ending before it opens.
    next.overrides[index].adjustedOpening = nil
    next.overrides[index].adjustedClosing = nil
    var usual = self
    usual.snapshot.overrides.removeAll { $0.id == item.id }
    if item.timeZoneID == calendar.timeZone.identifier,
      let window = usual.window(on: item.opening),
      window.opening == item.opening, window.closing == item.closing
    {
      // Remove a redundant exception while retaining its deletion for offline sync.
      next.overrides[index].deleted = true
    }
    next.overrides[index].modifiedAt = modifiedAt
    next.revision = modifiedAt
    try ScheduleEngine(snapshot: next, calendar: calendar).validate(near: now)
    return next
  }

  func eligibleReflections(at now: Date) -> [EatingWindow] {
    windows(around: now, daysBefore: 2, daysAfter: 0).filter { window in
      let c = LocalDay.calendar(
        timeZone: TimeZone(identifier: window.timeZoneID) ?? calendar.timeZone)
      guard let origin = LocalDay.date(window.dayKey, calendar: c),
        let expires = c.date(byAdding: .day, value: 2, to: origin)
      else { return false }
      return window.opening < window.closing && window.closing <= now && now < expires
    }.sorted { $0.opening < $1.opening }
  }

  static func validate(days: [DayPlan]) throws {
    guard days.count == 7, Set(days.map(\.weekday)) == Set(1...7) else {
      throw ScheduleError.missingWeekdays
    }
    guard days.allSatisfy({ $0.opens.isValid && $0.closes.isValid && $0.opens != $0.closes }) else {
      throw ScheduleError.invalidTime
    }
    let sorted = days.sorted { $0.weekday < $1.weekday }
    for index in sorted.indices {
      let current = sorted[index]
      let next = sorted[(index + 1) % 7]
      if current.overnight && current.closes > next.opens { throw ScheduleError.overlappingWindows }
    }
  }

  func validate(near now: Date) throws {
    guard snapshot.schema == 1, snapshot.revision.timeIntervalSince1970.isFinite,
      snapshot.versions.count <= 10000, snapshot.overrides.count <= 10000
    else { throw ScheduleError.incompatibleData }
    if snapshot.versions.isEmpty {
      guard snapshot.overrides.isEmpty else { throw ScheduleError.incompatibleData }
      return
    }
    guard Set(snapshot.versions.map(\.effectiveDay)).count == snapshot.versions.count,
      Set(snapshot.overrides.map(\.id)).count == snapshot.overrides.count
    else { throw ScheduleError.incompatibleData }
    for version in snapshot.versions {
      guard LocalDay.date(version.effectiveDay, calendar: calendar) != nil else {
        throw ScheduleError.invalidDate
      }
      try Self.validate(days: version.days)
    }
    for item in snapshot.overrides {
      guard let zone = TimeZone(identifier: item.timeZoneID) else {
        throw ScheduleError.invalidDate
      }
      let c = LocalDay.calendar(timeZone: zone)
      guard let day = LocalDay.date(item.dayKey, calendar: c),
        LocalDay.key(item.opening, calendar: c) == item.dayKey,
        item.closing > item.opening,
        let end = c.date(byAdding: .day, value: 2, to: day), item.closing < end
      else { throw ScheduleError.invalidTime }
      // An early break may bring the next day's opening into the preceding evening.
      // The original bounds remain valid, and the effective window cannot exceed them
      // by more than that one calendar day or end before it starts.
      guard let earliest = c.date(byAdding: .day, value: -1, to: day),
        item.window.opening.timeIntervalSince1970.isFinite,
        item.window.closing.timeIntervalSince1970.isFinite,
        item.window.opening >= earliest, item.window.opening < item.closing,
        item.window.closing >= item.window.opening, item.window.closing <= item.closing
      else { throw ScheduleError.invalidTime }
    }
    let dates =
      [now] + snapshot.versions.compactMap { LocalDay.date($0.effectiveDay, calendar: calendar) }
      + snapshot.overrides.map(\.opening)
    for date in dates {
      let ws = windows(around: date)
      for (a, b) in zip(ws, ws.dropFirst()) where a.closing > b.opening {
        throw ScheduleError.overlappingWindows
      }
    }
  }
}
