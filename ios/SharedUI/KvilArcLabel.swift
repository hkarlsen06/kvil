import SwiftUI

/// The same measured-letter drawing used by the timer ring, following a clockwise baseline.
struct KvilArcLabel: View, Animatable {
  @Environment(\.locale) private var locale
  var label: LocalizedStringResource
  var color: Color = .kvilSecondary
  var center: UnitPoint = .center
  nonisolated var radius: CGFloat
  nonisolated var angle: Double

  nonisolated var animatableData: AnimatablePair<CGFloat, Double> {
    get { AnimatablePair(radius, angle) }
    set {
      radius = newValue.first
      angle = newValue.second
    }
  }

  private var localizedLabel: LocalizedStringResource {
    var resource = label
    resource.locale = locale
    return resource
  }

  var body: some View {
    Canvas { context, size in
      guard radius > 0 else { return }
      let letters = String(localized: localizedLabel).map {
        context.resolve(Text(verbatim: String($0)).font(.caption).foregroundStyle(color))
      }
      let widths = letters.map { $0.measure(in: size).width }
      let tracking: CGFloat = 0.8
      let textWidth = widths.reduce(0, +) + tracking * CGFloat(max(0, letters.count - 1))
      // Keep even a longer label within a readable portion of the circumference.
      let scale = min(1, radius * .pi * 2 / 3 / max(1, textWidth))
      var offset = -textWidth / 2
      for (letter, width) in zip(letters, widths) {
        let position = angle + (offset + width / 2) * scale / radius
        var letterContext = context
        letterContext.translateBy(
          x: size.width * center.x + radius * cos(position),
          y: size.height * center.y + radius * sin(position))
        letterContext.rotate(by: .radians(position + .pi / 2))
        letterContext.scaleBy(x: scale, y: scale)
        letterContext.draw(letter, at: .zero, anchor: .center)
        offset += width + tracking
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(localizedLabel))
    .allowsHitTesting(false)
  }
}
