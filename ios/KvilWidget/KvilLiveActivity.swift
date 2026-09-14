import ActivityKit
import SwiftUI
import WidgetKit

struct KvilLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: OpeningActivityAttributes.self) { context in
      HStack(spacing: 16) {
        Image(systemName: "leaf").font(.title2).accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 4) {
          Text(context.isStale ? .liveActivityRefresh : .untilEatingWindow).font(.subheadline)
          if !context.isStale {
            timer(context).font(.system(.title, design: .rounded, weight: .light))
            Text(context.state.opening, format: .dateTime.hour().minute()).font(.caption)
          }
        }
        Spacer(minLength: 0)
        Text(verbatim: "kvil").font(.system(.title3, design: .serif))
      }.padding(20)
        .activityBackgroundTint(Color.kvilCanvas)
        .activitySystemActionForegroundColor(Color.kvilAccent)
        .foregroundStyle(Color.kvilInk)
        .widgetURL(URL(string: "kvil://home"))
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Label(context.isStale ? .yourEatingRhythm : .untilEatingWindow, systemImage: "leaf")
            .font(.caption)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text(verbatim: "kvil").font(.system(.body, design: .serif))
        }
        DynamicIslandExpandedRegion(.bottom) {
          if context.isStale {
            Text(.liveActivityRefresh).font(.subheadline)
          } else {
            VStack(spacing: 4) {
              timer(context).font(.system(.largeTitle, design: .rounded, weight: .light))
              Text(context.state.opening, format: .dateTime.hour().minute()).font(.caption)
            }
          }
        }
      } compactLeading: {
        Image(systemName: "leaf").accessibilityLabel(.yourEatingRhythm)
      } compactTrailing: {
        if context.isStale {
          Image(systemName: "arrow.clockwise").accessibilityLabel(.liveActivityRefresh)
        } else {
          timer(context).font(.caption).frame(maxWidth: 60)
        }
      } minimal: {
        Image(systemName: "leaf").accessibilityLabel(.yourEatingRhythm)
      }
      .widgetURL(URL(string: "kvil://home"))
    }
  }

  private func timer(_ context: ActivityViewContext<OpeningActivityAttributes>) -> some View {
    let countdown = Text(
      timerInterval: context.attributes
        .startedAt...max(context.attributes.startedAt, context.state.opening),
      countsDown: true, showsHours: true
    )
    return countdown.monospacedDigit().accessibilityLabel(.untilEatingWindow)
      .accessibilityValue(countdown)
  }
}
