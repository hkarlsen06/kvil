import SwiftUI

/// A lake opening toward the foreground, with broad hills disappearing into distant mist.
struct KvilLandscapeBackground: View, Animatable {
  @Environment(\.colorScheme) private var colorScheme
  nonisolated var eatingWindowReveal: CGFloat = 0
  var boatArea: ClosedRange<CGFloat>?

  nonisolated var animatableData: CGFloat {
    get { eatingWindowReveal }
    set { eatingWindowReveal = newValue }
  }

  var body: some View {
    Canvas { context, size in
      let night = colorScheme == .dark
      let reveal = min(1, max(0, eatingWindowReveal))
      let sky: Color = boatArea == nil ? .kvilCanvas : .kvilSky(daylight: Double(reveal))
      func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x * size.width, y: y * size.height)
      }
      func land(_ day: Double, _ nightAmount: Double) -> Color {
        sky.mix(with: .kvilAccent, by: night ? nightAmount : day)
      }
      func layer(scale: CGFloat, x: CGFloat = 0, y: CGFloat = 0) -> GraphicsContext {
        var layer = context
        let anchor = point(0.52, 0.48)
        layer.translateBy(x: anchor.x + x * size.width, y: anchor.y + y * size.height)
        layer.scaleBy(x: scale, y: scale)
        layer.translateBy(x: -anchor.x, y: -anchor.y)
        return layer
      }

      // Open water shares the canvas at the horizon and gains color toward the viewer.
      context.fill(
        Path(CGRect(origin: .zero, size: size)),
        with: .linearGradient(
          Gradient(stops: [
            .init(color: sky, location: 0),
            .init(color: sky, location: 0.38),
            .init(color: .kvilTrack, location: 1),
          ]), startPoint: .zero, endPoint: point(0, 1)))

      // A sparse night sky parts with the landscape as daylight arrives.
      if let boatArea, boatArea.lowerBound < size.height * 0.52, reveal < 1 {
        let center = point(0.52, 0.48)
        let spread = 1 + 1.45 * reveal
        let stars: [(CGFloat, CGFloat, CGFloat)] = [
          (0.13, 0.27, 2.0), (0.36, 0.42, 2.8), (0.52, 0.44, 1.8),
          (0.68, 0.40, 2.3), (0.88, 0.25, 1.6),
        ]
        for (x, y, radius) in stars {
          var position = point(x, y)
          // Keep the central stars below the Home controls, including on compact screens.
          if x > 0.2 && x < 0.8 {
            position.y = max(position.y, boatArea.lowerBound + 8)
          }
          position.x = center.x + (position.x - center.x) * spread
          position.y = center.y + (position.y - center.y) * spread
          var star = Path()
          star.move(to: CGPoint(x: position.x, y: position.y - radius))
          star.addQuadCurve(
            to: CGPoint(x: position.x + radius, y: position.y), control: position)
          star.addQuadCurve(
            to: CGPoint(x: position.x, y: position.y + radius), control: position)
          star.addQuadCurve(
            to: CGPoint(x: position.x - radius, y: position.y), control: position)
          star.addQuadCurve(
            to: CGPoint(x: position.x, y: position.y - radius), control: position)
          context.fill(star, with: .color(.kvilMoon.opacity(0.7 * (1 - reveal))))
        }
      }

      // Low, uninterrupted ridgelines leave an open horizon around the controls.
      var mountains = Path()
      mountains.move(to: point(0, 0.36))
      mountains.addCurve(
        to: point(0.22, 0.38), control1: point(0.07, 0.32), control2: point(0.15, 0.32))
      mountains.addCurve(
        to: point(0.55, 0.52), control1: point(0.34, 0.48), control2: point(0.40, 0.52))
      mountains.addCurve(
        to: point(0.80, 0.43), control1: point(0.65, 0.52), control2: point(0.70, 0.45))
      mountains.addCurve(
        to: point(1, 0.39), control1: point(0.88, 0.414), control2: point(0.93, 0.37))
      mountains.addLine(to: point(1, 0.76))
      mountains.addLine(to: point(0, 0.76))
      mountains.closeSubpath()
      layer(scale: 1 + 0.38 * reveal).fill(
        mountains,
        with: .linearGradient(
          Gradient(stops: [
            .init(color: .kvilSecondary.opacity(night ? 0.02 : 0.025), location: 0),
            .init(
              color: .kvilSecondary.opacity((night ? 0.13 : 0.15) + 0.09 * reveal),
              location: 0.40),
            .init(color: .kvilSecondary.opacity(0), location: 1),
          ]), startPoint: point(0, 0.30), endPoint: point(0, 0.76)))

      // The boat approaches from the channel, behind the nearer hills as they part.
      if reveal > 0 {
        var boat = context
        boat.opacity = min(1, reveal * 2)
        let area = boatArea ?? (size.height * 0.45)...(size.height * 0.85)
        let width = min(170, size.width * 0.42, (area.upperBound - area.lowerBound) * 160 / 120)
        let scale = width / 160 * (0.24 + 0.76 * reveal)
        let waterline = (area.lowerBound + area.upperBound) / 2 + width * 6 / 160
        boat.translateBy(
          x: size.width * 0.52, y: size.height * 0.57 * (1 - reveal) + waterline * reveal)
        boat.scaleBy(x: scale, y: scale)
        boat.rotate(by: .degrees(-5 * (1 - reveal)))
        // Fade the assembled boat so the hull keeps occluding the apple.
        boat.drawLayer { layer in
          layer.opacity = 1
          KvilPicnicBoat.draw(in: layer, night: night)
        }
      }

      var leftSlope = Path()
      leftSlope.move(to: point(0, 0.48))
      leftSlope.addCurve(
        to: point(0.22, 0.52), control1: point(0.08, 0.45), control2: point(0.14, 0.48))
      leftSlope.addCurve(
        to: point(0.42, 0.61), control1: point(0.31, 0.57), control2: point(0.35, 0.58))
      leftSlope.addCurve(
        to: point(0.55, 0.655), control1: point(0.49, 0.635), control2: point(0.55, 0.64))
      leftSlope.addCurve(
        to: point(0.34, 0.695), control1: point(0.55, 0.674), control2: point(0.43, 0.68))
      leftSlope.addCurve(
        to: point(0, 0.75), control1: point(0.22, 0.715), control2: point(0.12, 0.72))
      leftSlope.closeSubpath()
      layer(scale: 1 + 0.22 * reveal, x: -0.52 * reveal, y: 0.05 * reveal).fill(
        leftSlope,
        with: .linearGradient(
          Gradient(colors: [
            land(0.10, 0.05),
            land(0.29, 0.24),
          ]), startPoint: point(0, 0.42), endPoint: point(0, 0.75)))

      var rightSlope = Path()
      rightSlope.move(to: point(1, 0.50))
      rightSlope.addCurve(
        to: point(0.83, 0.55), control1: point(0.94, 0.48), control2: point(0.88, 0.50))
      rightSlope.addCurve(
        to: point(0.65, 0.65), control1: point(0.77, 0.60), control2: point(0.71, 0.61))
      rightSlope.addCurve(
        to: point(0.585, 0.68), control1: point(0.61, 0.665), control2: point(0.585, 0.667))
      rightSlope.addCurve(
        to: point(0.72, 0.73), control1: point(0.585, 0.70), control2: point(0.65, 0.714))
      rightSlope.addCurve(
        to: point(1, 0.82), control1: point(0.85, 0.755), control2: point(0.94, 0.795))
      rightSlope.closeSubpath()
      layer(scale: 1 + 0.22 * reveal, x: 0.52 * reveal, y: 0.05 * reveal).fill(
        rightSlope,
        with: .linearGradient(
          Gradient(colors: [
            land(0.12, 0.07),
            land(0.36, 0.28),
          ]), startPoint: point(0, 0.46), endPoint: point(0, 0.82)))

      // Asymmetric banks frame the lake and run through the screen's bottom edge.
      var leftBank = Path()
      leftBank.move(to: point(0, 0.60))
      leftBank.addCurve(
        to: point(0.38, 0.78), control1: point(0.17, 0.62), control2: point(0.23, 0.74))
      leftBank.addQuadCurve(to: point(0.49, 0.81), control: point(0.44, 0.79))
      leftBank.addCurve(
        to: point(0.41, 0.85), control1: point(0.53, 0.83), control2: point(0.43, 0.84))
      leftBank.addCurve(
        to: point(0.19, 1), control1: point(0.24, 0.89), control2: point(0.15, 0.94))
      leftBank.addLine(to: point(0, 1))
      leftBank.closeSubpath()
      layer(scale: 1 + 0.38 * reveal, x: -0.62 * reveal, y: 0.16 * reveal).fill(
        leftBank,
        with: .linearGradient(
          Gradient(colors: [
            land(0.30, 0.15),
            land(0.62, 0.34),
          ]), startPoint: point(0, 0.60), endPoint: point(0, 1)))

      var rightBank = Path()
      rightBank.move(to: point(1, 0.70))
      rightBank.addCurve(
        to: point(0.66, 0.86), control1: point(0.85, 0.71), control2: point(0.84, 0.81))
      rightBank.addQuadCurve(to: point(0.56, 0.92), control: point(0.62, 0.88))
      rightBank.addQuadCurve(to: point(0.65, 1), control: point(0.61, 0.96))
      rightBank.addLine(to: point(1, 1))
      rightBank.closeSubpath()
      layer(scale: 1 + 0.38 * reveal, x: 0.62 * reveal, y: 0.16 * reveal).fill(
        rightBank,
        with: .linearGradient(
          Gradient(colors: [
            land(0.40, 0.20),
            land(0.76, 0.40),
          ]), startPoint: point(0, 0.70), endPoint: point(0, 1)))
    }
    .clipped()
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}
