import Foundation

enum DayFeeling: String, Codable, CaseIterable, Sendable { case comfortable, mixed, difficult }
enum PlanExperience: String, Codable, CaseIterable, Sendable { case asPlanned, changed, unsure }

struct Reflection: Codable, Equatable, Sendable, Identifiable {
  var id: String { dayKey + "@" + timeZoneID }
  var dayKey: String
  var timeZoneID: String
  var feeling: DayFeeling?
  var opening: Date
  var closing: Date
  var updatedAt: Date
  // These are reported answers. Planned bounds never stand in for actual meal times.
  var planExperience: PlanExperience? = nil
  var firstMeal: Date? = nil
  var lastMeal: Date? = nil
  var note: String? = nil
  var wasDayOff: Bool? = nil

  var hasAnswer: Bool {
    feeling != nil || planExperience != nil || firstMeal != nil || note?.isEmpty == false
  }

  var isValid: Bool {
    guard let zone = TimeZone(identifier: timeZoneID) else { return false }
    let calendar = LocalDay.calendar(timeZone: zone)
    guard let day = LocalDay.date(dayKey, calendar: calendar),
      let nextDay = calendar.date(byAdding: .day, value: 1, to: day),
      let end = calendar.date(byAdding: .day, value: 2, to: day),
      opening.timeIntervalSince1970.isFinite, closing.timeIntervalSince1970.isFinite,
      closing > opening, updatedAt.timeIntervalSince1970.isFinite,
      (note?.count ?? 0) <= 1000,
      wasDayOff != true || planExperience == nil
    else { return false }
    switch (firstMeal, lastMeal) {
    case (nil, nil): return true
    case (.some(let first), .some(let last)):
      return planExperience != .asPlanned
        && first.timeIntervalSince1970.isFinite && last.timeIntervalSince1970.isFinite
        && first >= day && first < nextDay && last >= first && last < end && last <= updatedAt
    default: return false
    }
  }
}

struct Recap: Equatable, Sendable {
  let reflections: [Reflection]
  var answerCount: Int { reflections.filter(\.hasAnswer).count }
  var feelingCount: Int { reflections.filter { $0.feeling != nil }.count }
  func count(_ feeling: DayFeeling) -> Int { reflections.filter { $0.feeling == feeling }.count }
  static func recent(
    _ records: [Reflection], days: Int, now: Date, calendar: Calendar, includeToday: Bool = false
  ) -> Recap {
    let end = calendar.startOfDay(for: now)
    let start =
      calendar.date(byAdding: .day, value: -(includeToday ? days - 1 : days), to: end) ?? end
    let low = LocalDay.key(start, calendar: calendar)
    let high = LocalDay.key(end, calendar: calendar)
    return Recap(
      reflections: records.filter {
        $0.dayKey >= low && (includeToday ? $0.dayKey <= high : $0.dayKey < high)
      })
  }
}

struct WeightEntry: Codable, Equatable, Identifiable, Sendable {
  var id = UUID()
  var kilograms: Double
  var date: Date
  var healthSampleID: UUID?
  var saveToHealth: Bool = false
  var healthVersion: Int = 1
  var pendingDeletion: Bool = false
  var healthNeedsUpdate: Bool = false
  var isValid: Bool {
    kilograms.isFinite && kilograms > 0 && kilograms <= 1000 && date.timeIntervalSince1970.isFinite
  }
}

enum WeightUnit: String, Codable, CaseIterable, Sendable {
  case kg, lb
  func display(_ kg: Double) -> Double { self == .kg ? kg : kg * 2.2046226218 }
  func kilograms(_ value: Double) -> Double { self == .kg ? value : value / 2.2046226218 }
}

struct Preferences: Codable, Equatable, Sendable {
  var cloudScheduleEnabled = true
  var openingReminder = false
  var closingReminder = false
  var openingReminderLeadMinutes: Int? = nil
  var closingReminderLeadMinutes: Int? = nil
  var liveActivitiesEnabled: Bool? = nil
  var weightEnabled = false
  var healthEnabled = false
  var healthWritesEnabled = false
  var weightUnit: WeightUnit = Locale.current.measurementSystem == .us ? .lb : .kg
}
