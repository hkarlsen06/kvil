import AppIntents
import Foundation
import Observation

@MainActor @Observable final class KvilIntentNavigation {
  static let shared = KvilIntentNavigation()
  var showPlan = false
}

struct NextOpeningIntent: AppIntent {
  // App Intents' metadata extractor requires a literal initializer here. Keep these
  // existing catalog keys; runtime UI and dialogs use the generated symbols below.
  static var title: LocalizedStringResource {
    LocalizedStringResource("shortcutNextOpening", defaultValue: "Next opening")
  }
  static var description: IntentDescription {
    IntentDescription(
      LocalizedStringResource(
        "shortcutNextOpeningDescription", defaultValue: "Read the next opening in your eating plan."
      ))
  }

  func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
    let reply: LocalizedStringResource
    #if DEBUG
      if ProcessInfo.processInfo.environment["KVIL_SCENARIO"] != nil
        || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
      {
        return .result(
          value: String(localized: .shortcutSetUp), dialog: IntentDialog(.shortcutSetUp))
      }
    #endif
    if let snapshot = SnapshotStore().read() {
      reply = ScheduleQuery.reply(snapshot: snapshot, now: Date(), calendar: LocalDay.calendar())
    } else {
      reply = .shortcutSetUp
    }
    return .result(value: String(localized: reply), dialog: IntentDialog(reply))
  }
}

struct OpenPlanIntent: AppIntent {
  static var title: LocalizedStringResource {
    LocalizedStringResource("shortcutOpenPlan", defaultValue: "Open plan")
  }
  static var description: IntentDescription {
    IntentDescription(
      LocalizedStringResource(
        "shortcutOpenPlanDescription", defaultValue: "Open your weekly eating plan in Kvil."))
  }
  static var supportedModes: IntentModes { .foreground }

  @MainActor func perform() async throws -> some IntentResult {
    KvilIntentNavigation.shared.showPlan = true
    return .result()
  }
}

struct KvilShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: NextOpeningIntent(),
      phrases: ["When does my eating window open in \(.applicationName)"],
      shortTitle: LocalizedStringResource("shortcutNextOpening", defaultValue: "Next opening"),
      systemImageName: "sun.horizon")
    AppShortcut(
      intent: OpenPlanIntent(), phrases: ["Open my plan in \(.applicationName)"],
      shortTitle: LocalizedStringResource("shortcutOpenPlan", defaultValue: "Open plan"),
      systemImageName: "calendar")
  }
}

enum ScheduleQuery {
  static func reply(snapshot: ScheduleSnapshot, now: Date, calendar: Calendar)
    -> LocalizedStringResource
  {
    guard let state = ScheduleEngine(snapshot: snapshot, calendar: calendar).state(at: now) else {
      return .shortcutSetUp
    }
    guard let next = state.next else { return .shortcutNoWindow }
    let date = next.opening.formatted(
      Date.FormatStyle(
        date: .abbreviated, time: .shortened, calendar: calendar, timeZone: calendar.timeZone))
    if state.isDayOff { return .shortcutDayOffReply(date) }
    if state.isOpen { return .shortcutOpenReply(date) }
    return .shortcutNextOpeningReply(date)
  }
}
