import SwiftUI

/// A wall-clock map of a planned window, independent of elapsed time and DST day length.
struct KvilWindowTimeline: View {
  var opens: WallTime
  var closes: WallTime
  var showsGrip = false

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Capsule().fill(Color.kvilTrack).frame(height: showsGrip ? 8 : geometry.size.height)
        if opens != closes {
          if closes < opens {
            segment(from: opens.minute, to: 1440, width: geometry.size.width)
            segment(from: 0, to: closes.minute, width: geometry.size.width)
          } else {
            segment(from: opens.minute, to: closes.minute, width: geometry.size.width)
          }
        }
      }.clipShape(Capsule())
    }.accessibilityHidden(true)
      .environment(\.layoutDirection, .leftToRight)
  }

  private func segment(from start: Int, to end: Int, width: CGFloat) -> some View {
    Capsule().fill(Color.kvilAccent)
      .frame(width: width * CGFloat(end - start) / 1440)
      .overlay {
        if showsGrip && width * CGFloat(end - start) / 1440 >= 24 {
          HStack(spacing: 3) {
            Capsule().frame(width: 2, height: 10)
            Capsule().frame(width: 2, height: 10)
          }.foregroundStyle(Color.kvilInverse)
        }
      }
      .offset(x: width * CGFloat(start) / 1440)
  }
}

struct KvilDayAxis: View {
  @Environment(\.locale) private var locale
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    HStack(spacing: 0) {
      hourLabel(0)
      Spacer(minLength: 0)
      hourLabel(24)
    }.overlay {
      if !typeSize.isAccessibilitySize { hourLabel(12) }
    }.overlay {
      if typeSize < .xxLarge {
        GeometryReader { geometry in
          hourLabel(6).position(x: geometry.size.width / 4, y: geometry.size.height / 2)
          hourLabel(18).position(x: geometry.size.width * 3 / 4, y: geometry.size.height / 2)
        }
      }
    }.font(.caption2).monospacedDigit().foregroundStyle(Color.kvilSecondary)
      .accessibilityHidden(true)
      .environment(\.layoutDirection, .leftToRight)
  }

  private func hourLabel(_ hour: Int) -> some View {
    Text(
      verbatim: Date(timeIntervalSinceReferenceDate: TimeInterval(hour * 3600)).formatted(
        Date.FormatStyle(locale: locale, timeZone: .gmt)
          .hour(.defaultDigits(amPM: .abbreviated)))
    ).fixedSize()
  }
}
