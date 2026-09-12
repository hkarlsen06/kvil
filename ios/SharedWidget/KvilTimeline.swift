import SwiftUI
import WidgetKit

struct KvilEntry: TimelineEntry {
  var date: Date
  var state: ScheduleState?
  var isPreview = false
}

struct KvilTimelineProvider: TimelineProvider {
  func placeholder(in context: Context) -> KvilEntry { preview() }
  func getSnapshot(in context: Context, completion: @escaping (KvilEntry) -> Void) {
    completion(context.isPreview ? preview() : entry(at: Date()))
  }
  func getTimeline(in context: Context, completion: @escaping (Timeline<KvilEntry>) -> Void) {
    let now = Date()
    guard let snapshot = SnapshotStore().read(), !snapshot.versions.isEmpty else {
      completion(
        Timeline(entries: [KvilEntry(date: now)], policy: .after(now.addingTimeInterval(3600))))
      return
    }
    let engine = ScheduleEngine(snapshot: snapshot, calendar: LocalDay.calendar())
    let end = now.addingTimeInterval(48 * 3600)
    var dates = Set(
      stride(from: 0, through: 48 * 3600, by: 1800).map { now.addingTimeInterval(Double($0)) })
    for window in engine.windows(around: now, daysBefore: 1, daysAfter: 3) {
      for date in [window.opening, window.closing] where date > now && date <= end {
        dates.insert(date)
      }
    }
    completion(
      Timeline(
        entries: dates.sorted().map { KvilEntry(date: $0, state: engine.state(at: $0)) },
        policy: .after(now.addingTimeInterval(24 * 3600))))
  }
  private func entry(at date: Date) -> KvilEntry {
    KvilEntry(
      date: date,
      state: SnapshotStore().read().flatMap {
        ScheduleEngine(snapshot: $0, calendar: LocalDay.calendar()).state(at: date)
      })
  }
  private func preview() -> KvilEntry {
    let now = Date()
    let opening = now.addingTimeInterval(3 * 3600 + 45 * 60)
    let window = EatingWindow(
      dayKey: LocalDay.key(now, calendar: .current), timeZoneID: TimeZone.current.identifier,
      opening: opening, closing: opening.addingTimeInterval(8 * 3600), isOverride: false)
    return KvilEntry(
      date: now,
      state: ScheduleState(
        next: window, previousClose: now.addingTimeInterval(-12 * 3600), progress: 0.76),
      isPreview: true)
  }
}

struct KvilWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: KvilEntry
  var body: some View {
    Group {
      if let state = entry.state {
        switch family {
        case .accessoryInline:
          if state.isOpen {
            Text(L10n.windowOpen)
          } else {
            Text(
              verbatim: String(localized: L10n.opensAtPrefix)
                + state.next.opening.formatted(.dateTime.hour().minute()))
          }
        case .accessoryCircular:
          ZStack {
            AccessoryWidgetBackground()
            OpenArc(progress: state.progress).stroke(
              .primary, style: StrokeStyle(lineWidth: 3, lineCap: .round)
            ).padding(5)
            VStack(spacing: 0) {
              Image(systemName: state.isOpen ? "sun.max" : "leaf").font(.caption2)
              if state.isOpen {
                Text(L10n.openShort).font(.caption2)
              } else {
                countdown(state).font(.system(.caption, design: .rounded)).minimumScaleFactor(0.7)
              }
            }.padding(8)
          }
        case .accessoryRectangular:
          VStack(alignment: .leading, spacing: 4) {
            Label(
              state.isOpen ? L10n.windowOpen : L10n.nextWindow,
              systemImage: state.isOpen ? "sun.max" : "leaf"
            ).font(.headline)
            if let active = state.active {
              WindowTimeLabel(window: active).font(.caption)
            } else {
              countdown(state).font(.system(.title2, design: .rounded))
              Text(state.next.opening, format: .dateTime.hour().minute()).font(.caption)
            }
          }
        default:
          HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
              HStack(spacing: 5) {
                Image(systemName: state.isOpen ? "sun.max" : "leaf")
                Text(verbatim: "kvil").font(.system(.subheadline, design: .serif))
              }.font(.caption).foregroundStyle(Color.kvilSecondary)
              if state.isOpen {
                Text(L10n.windowOpen).font(.system(.title2, design: .serif))
              } else {
                countdown(state).font(.system(.largeTitle, design: .rounded, weight: .light))
                  .minimumScaleFactor(0.75)
              }
              if let active = state.active {
                WindowTimeLabel(window: active).font(.caption)
              } else {
                Text(L10n.untilEatingWindow).font(.caption).foregroundStyle(Color.kvilSecondary)
                Text(state.next.opening, format: .dateTime.hour().minute()).font(.caption)
              }
            }.frame(maxWidth: .infinity, alignment: .leading)
            if isMedium {
              Image("Landscape").resizable().scaledToFill().frame(width: 118).clipped().clipShape(
                RoundedRectangle(cornerRadius: 18)
              ).accessibilityHidden(true)
            }
          }.foregroundStyle(Color.kvilInk)
        }
      } else {
        if family == .accessoryInline {
          Text(L10n.openKvilToSetUp)
        } else {
          VStack(spacing: 6) {
            Image(systemName: "leaf")
            Text(L10n.openKvilToSetUp).font(.caption).multilineTextAlignment(.center)
          }
        }
      }
    }.containerBackground(for: .widget) { Color.kvilCanvas }
      .widgetURL(URL(string: "kvil://home"))
  }
  private var isMedium: Bool {
    #if os(iOS)
      family == .systemMedium
    #else
      false
    #endif
  }
  private func countdown(_ state: ScheduleState) -> some View {
    Text(
      timerInterval: entry.date...max(entry.date, state.next.opening), countsDown: true,
      showsHours: true
    ).monospacedDigit()
  }
}
