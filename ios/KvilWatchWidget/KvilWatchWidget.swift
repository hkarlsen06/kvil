import SwiftUI
import WidgetKit

@main struct KvilWatchWidgets: WidgetBundle {
  var body: some Widget { KvilWatchComplication() }
}
struct KvilWatchComplication: Widget {
  let kind = "KvilWatchSchedule"
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: KvilTimelineProvider()) { KvilWidgetView(entry: $0) }
      .configurationDisplayName(.yourEatingRhythm)
      .description(.widgetDescription)
      .supportedFamilies([.accessoryCircular, .accessoryRectangular])
  }
}
