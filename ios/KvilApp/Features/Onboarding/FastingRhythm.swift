import Foundation

enum FastingRhythm: String, CaseIterable, Identifiable {
  case twelve, fourteen, sixteen, custom
  var id: Self { self }

  var title: LocalizedStringResource {
    switch self {
    case .twelve: .setupTwelveTitle
    case .fourteen: .setupFourteenTitle
    case .sixteen: .setupSixteenTitle
    case .custom: .setupCustomTitle
    }
  }

  var summary: LocalizedStringResource {
    switch self {
    case .twelve: .setupTwelveSummary
    case .fourteen: .setupFourteenSummary
    case .sixteen: .setupSixteenSummary
    case .custom: .setupCustomSummary
    }
  }

  var mealHelp: LocalizedStringResource {
    switch self {
    case .twelve: .setupTwelveMeals
    case .fourteen: .setupFourteenMeals
    case .sixteen: .setupSixteenMeals
    case .custom: .setupCustomMeals
    }
  }

  var example: DayPlan? {
    switch self {
    case .twelve: DayPlan(weekday: 1, opens: .init(hour: 8), closes: .init(hour: 20))
    case .fourteen: DayPlan(weekday: 1, opens: .init(hour: 9), closes: .init(hour: 19))
    case .sixteen: DayPlan(weekday: 1, opens: .init(hour: 10), closes: .init(hour: 18))
    case .custom: nil
    }
  }
}
