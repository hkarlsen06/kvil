import SwiftUI
import WidgetKit

@main struct KvilWidgets: WidgetBundle {
  var body: some Widget { KvilScheduleWidget() }
}
struct KvilScheduleWidget: Widget {
  let kind = "KvilSchedule"
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: KvilTimelineProvider()) { KvilWidgetView(entry: $0) }
      .configurationDisplayName(.yourEatingRhythm)
      .description(.widgetDescription)
      .supportedFamilies([
        .systemSmall, .systemMedium, .accessoryInline, .accessoryCircular, .accessoryRectangular,
      ])
  }
}
