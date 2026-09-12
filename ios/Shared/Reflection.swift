import Foundation

enum DayFeeling: String, Codable, CaseIterable, Sendable { case comfortable, mixed, difficult }

struct Reflection: Codable, Equatable, Sendable, Identifiable {
  var id: String { dayKey + "@" + timeZoneID }
  var dayKey: String
  var timeZoneID: String
  var feeling: DayFeeling?
  var opening: Date
  var closing: Date
  var updatedAt: Date
}

struct Recap: Equatable, Sendable {
  let reflections: [Reflection]
  var answerCount: Int { reflections.filter { $0.feeling != nil }.count }
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
  var weightEnabled = false
  var healthEnabled = false
  var healthWritesEnabled = false
  var weightUnit: WeightUnit = Locale.current.measurementSystem == .us ? .lb : .kg
}
