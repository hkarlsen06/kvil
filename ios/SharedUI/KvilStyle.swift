import SwiftUI

extension Color {
  #if os(watchOS)
    // Keep the native Watch interface in the night palette.
    static let kvilCanvas = Color(red: 0.078431, green: 0.176471, blue: 0.160784)
    static let kvilSurface = Color(red: 0.125490, green: 0.231373, blue: 0.203922)
    static let kvilInk = Color(red: 0.945098, green: 0.941176, blue: 0.894118)
    static let kvilSecondary = Color(red: 0.717647, green: 0.780392, blue: 0.725490)
    static let kvilAccent = Color(red: 0.654902, green: 0.760784, blue: 0.615686)
    static let kvilTrack = Color(red: 0.203922, green: 0.309804, blue: 0.266667)
    static let kvilLine = Color(red: 0.219608, green: 0.317647, blue: 0.282353)
    static let kvilInverse = Color(red: 0.094118, green: 0.196078, blue: 0.152941)
    static let kvilWarning = Color(red: 0.909804, green: 0.733333, blue: 0.552941)
  #else
    static let kvilCanvas = Color("Canvas")
    static let kvilSurface = Color("Surface")
    static let kvilInk = Color("Ink")
    static let kvilSecondary = Color("SecondaryInk")
    static let kvilAccent = Color("Accent")
    static let kvilTrack = Color("Track")
    static let kvilLine = Color("Line")
    static let kvilInverse = Color("Inverse")
    static let kvilWarning = Color("Warning")
  #endif
}

enum KvilStyle {
  static let page: CGFloat = 24
  static let section: CGFloat = 28
  static let related: CGFloat = 8
  static let content: CGFloat = 16
  static let cardPadding: CGFloat = 20
  static let corner: CGFloat = 24
  static let title: Font = .system(.largeTitle, design: .serif, weight: .regular)
  static let heading: Font = .system(.title2, design: .serif)
}

struct OpenArc: Shape {
  var progress: Double = 1
  var gapAngle: Angle = .degrees(90)
  var animatableData: Double {
    get { progress }
    set { progress = newValue }
  }
  func path(in rect: CGRect) -> Path {
    var path = Path()
    guard progress > 0 else { return path }
    let start = 90 + gapAngle.degrees / 2
    path.addArc(
      center: CGPoint(x: rect.midX, y: rect.midY), radius: min(rect.width, rect.height) / 2,
      startAngle: .degrees(start),
      endAngle: .degrees(start + (360 - gapAngle.degrees) * min(1, progress)),
      clockwise: false)
    return path
  }
}

struct KvilWordmark: View {
  var body: some View {
    HStack(spacing: 8) {
      OpenArc().stroke(Color.kvilInk, style: StrokeStyle(lineWidth: 1.8, lineCap: .round)).frame(
        width: 18, height: 18)
      Text(verbatim: "kvil").font(.system(.title2, design: .serif, weight: .medium)).tracking(0.5)
    }.foregroundStyle(Color.kvilInk).accessibilityElement(children: .ignore).accessibilityLabel(
      Text(verbatim: "Kvil"))
  }
}

struct LandscapeView: View {
  var height: CGFloat = 230
  var body: some View {
    Color.clear.frame(height: height)
      .overlay { Image("Landscape").resizable().scaledToFill() }
      .clipped()
      .accessibilityHidden(true)
  }
}

struct KvilPrimaryButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(.headline).frame(maxWidth: .infinity).padding(.vertical, 17)
      .foregroundStyle(Color.kvilInverse).background(
        Color.kvilAccent.opacity(configuration.isPressed ? 0.8 : 1), in: Capsule()
      )
      .contentShape(Capsule())
  }
}

extension DayFeeling {
  var title: LocalizedStringResource {
    switch self {
    case .comfortable: .comfortable
    case .mixed: .mixed
    case .difficult: .difficult
    }
  }
  var symbol: String {
    switch self {
    case .comfortable: "sun.max"
    case .mixed: "cloud.sun"
    case .difficult: "cloud.rain"
    }
  }
}

struct WindowTimeLabel: View {
  @Environment(\.dynamicTypeSize) private var typeSize
  var window: EatingWindow
  var stacksForAccessibility = true
  var body: some View {
    Group {
      if typeSize.isAccessibilitySize && stacksForAccessibility {
        verticalRange
      } else {
        ViewThatFits(in: .horizontal) {
          HStack(spacing: 4) {
            Text(window.opening, format: .dateTime.hour().minute())
            Text(verbatim: "–")
            Text(window.closing, format: .dateTime.hour().minute())
            overnightLabel
          }.fixedSize()
          verticalRange
        }
      }
    }.monospacedDigit().accessibilityElement(children: .combine)
  }
  private var verticalRange: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(window.opening, format: .dateTime.hour().minute()).fixedSize()
      Text(verbatim: "–").font(.caption).fixedSize()
      Text(window.closing, format: .dateTime.hour().minute()).fixedSize()
      overnightLabel
    }
  }
  @ViewBuilder private var overnightLabel: some View {
    if !Calendar.current.isDate(window.opening, inSameDayAs: window.closing) {
      Text(.nextDayShort).font(.caption)
    }
  }
}
