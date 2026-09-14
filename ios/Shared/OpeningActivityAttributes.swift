#if os(iOS)
  import ActivityKit
  import Foundation

  struct OpeningActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
      var opening: Date
    }

    var dayKey: String
    var timeZoneID: String
    var startedAt: Date
  }
#endif
