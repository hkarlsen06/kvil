import SwiftUI

struct LabeledProgressRing: View, Animatable {
  @Environment(\.locale) private var locale
  nonisolated var progress: Double
  var label: LocalizedStringResource
  nonisolated var daylight: CGFloat = 0

  nonisolated var animatableData: AnimatablePair<Double, CGFloat> {
    get { AnimatablePair(progress, daylight) }
    set {
      progress = newValue.first
      daylight = newValue.second
    }
  }

  private var localizedLabel: LocalizedStringResource {
    var resource = label
    resource.locale = locale
    return resource
  }

  var body: some View {
    Canvas { context, size in
      let center = CGPoint(x: size.width / 2, y: size.height / 2)
      let radius = min(size.width, size.height) / 2 - 22
      guard radius > 0 else { return }
      let day = min(1, max(0, daylight))
      let tint = Color.kvilMoon.mix(with: .kvilSun, by: Double(day))
      let glyphs = String(localized: localizedLabel).map {
        context.resolve(
          Text(verbatim: String($0)).font(.caption).foregroundStyle(Color.kvilSecondary))
      }
      let widths = glyphs.map { $0.measure(in: size).width }
      let tracking: CGFloat = 1.1
      let textWidth = widths.reduce(0, +) + tracking * CGFloat(max(0, glyphs.count - 1))
      // Leave room for the round caps while keeping larger captions within the bottom quarter.
      let scale = min(1, max(0, radius * .pi / 2 - 24) / max(1, textWidth))
      let gap = Angle.radians((textWidth * scale + 24) / radius)
      let rect = CGRect(
        x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
      let stroke = StrokeStyle(lineWidth: 5, lineCap: .round)
      let progressArc = OpenArc(progress: progress, gapAngle: gap).path(in: rect)
      // Blur only the filled arc, so its glow ends with the visible progress.
      if day > 0 && progress > 0 {
        context.drawLayer { glow in
          glow.addFilter(.blur(radius: 6))
          glow.stroke(
            progressArc, with: .color(.kvilSun.opacity(0.28 * day)),
            style: StrokeStyle(lineWidth: 12, lineCap: .round))
        }
      }
      context.stroke(
        OpenArc(gapAngle: gap).path(in: rect), with: .color(tint.opacity(0.22)), style: stroke)
      // Mostly silver moonlight, with a faint warm-to-cool sheen along the progress arc.
      let titanium = Gradient(
        colors: [
          Color.kvilTitaniumBronze, .kvilTitaniumViolet, .kvilTitaniumBlue,
          .kvilTitaniumViolet.mix(with: .white, by: 0.1),
          .kvilTitaniumBronze,
        ].map { $0.mix(with: .kvilSun, by: Double(day)) })
      context.stroke(
        progressArc,
        with: .conicGradient(titanium, center: center, angle: .degrees(90 + gap.degrees / 2)),
        style: stroke)

      var offset = -textWidth / 2
      for (glyph, width) in zip(glyphs, widths) {
        let angle = (offset + width / 2) * scale / radius
        var letterContext = context
        letterContext.translateBy(
          x: center.x + radius * sin(angle), y: center.y + radius * cos(angle))
        letterContext.rotate(by: .radians(-angle))
        letterContext.scaleBy(x: scale, y: scale)
        letterContext.draw(glyph, at: .zero, anchor: .center)
        offset += width + tracking
      }
    }
    // Let the glow fade out beyond the ring without changing the timer's layout footprint.
    .padding(-18)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(localizedLabel))
  }

}
