import SwiftUI

/// A simple cartoon boat, in a 160-point space around the waterline.
enum KvilPicnicBoat {
  static func draw(in context: GraphicsContext, night: Bool) {
    let shade: Color = night ? .kvilCanvas : .kvilInk
    let highlight: Color = night ? .kvilInk : .kvilCanvas
    let timber = Color.kvilBoatHull
    let rimColor = timber.mix(with: highlight, by: 0.35)

    context.fill(
      Path(ellipseIn: CGRect(x: -67, y: 24, width: 130, height: 13)),
      with: .color(.kvilAccent.opacity(0.15)))
    var ripples = Path()
    ripples.move(to: CGPoint(x: -94, y: 23))
    ripples.addQuadCurve(to: CGPoint(x: -68, y: 24), control: CGPoint(x: -81, y: 26))
    ripples.move(to: CGPoint(x: 69, y: 19))
    ripples.addQuadCurve(to: CGPoint(x: 93, y: 17), control: CGPoint(x: 83, y: 22))
    ripples.move(to: CGPoint(x: -42, y: 42))
    ripples.addQuadCurve(to: CGPoint(x: 28, y: 43), control: CGPoint(x: -4, y: 47))
    context.stroke(
      ripples, with: .color(.kvilAccent.opacity(0.28)),
      style: StrokeStyle(lineWidth: 1.7, lineCap: .round))

    // A shallow opening keeps the boat upright, viewed from near the water's surface.
    var farRim = Path()
    farRim.move(to: CGPoint(x: -78, y: -10))
    farRim.addCurve(
      to: CGPoint(x: 78, y: -10), control1: CGPoint(x: -34, y: -16),
      control2: CGPoint(x: 34, y: -16))
    var well = farRim
    well.addCurve(
      to: CGPoint(x: -78, y: -10), control1: CGPoint(x: 32, y: -2),
      control2: CGPoint(x: -32, y: -2))
    well.closeSubpath()
    context.fill(
      well,
      with: .linearGradient(
        Gradient(colors: [timber.mix(with: shade, by: 0.42), timber.mix(with: shade, by: 0.16)]),
        startPoint: CGPoint(x: 0, y: -15), endPoint: CGPoint(x: 0, y: -3)))
    context.stroke(
      farRim, with: .color(rimColor),
      style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

    var interior = context
    interior.clip(to: well)
    interior.fill(
      Path(ellipseIn: CGRect(x: -41, y: -9, width: 48, height: 6)),
      with: .color(shade.opacity(0.24)))

    // The apple rests below the rim, with its lower half covered by the near hull.
    var apple = Path()
    apple.move(to: CGPoint(x: -16, y: -23))
    apple.addCurve(
      to: CGPoint(x: -36, y: -16), control1: CGPoint(x: -29, y: -31),
      control2: CGPoint(x: -36, y: -27))
    apple.addCurve(
      to: CGPoint(x: -27, y: 17), control1: CGPoint(x: -40, y: -4),
      control2: CGPoint(x: -34, y: 14))
    apple.addCurve(
      to: CGPoint(x: -16, y: 16), control1: CGPoint(x: -23, y: 20),
      control2: CGPoint(x: -20, y: 14))
    apple.addCurve(
      to: CGPoint(x: -6, y: 17), control1: CGPoint(x: -12, y: 14),
      control2: CGPoint(x: -10, y: 20))
    apple.addCurve(
      to: CGPoint(x: 4, y: -15), control1: CGPoint(x: 2, y: 12),
      control2: CGPoint(x: 7, y: -4))
    apple.addCurve(
      to: CGPoint(x: -16, y: -23), control1: CGPoint(x: 4, y: -29),
      control2: CGPoint(x: -7, y: -31))
    context.fill(apple, with: .color(.kvilSun))

    var stem = Path()
    stem.move(to: CGPoint(x: -16, y: -23))
    stem.addQuadCurve(to: CGPoint(x: -13, y: -35), control: CGPoint(x: -18, y: -30))
    context.stroke(
      stem, with: .color(timber.mix(with: shade, by: 0.4)),
      style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
    var leaf = Path()
    leaf.move(to: CGPoint(x: -15, y: -31))
    leaf.addCurve(
      to: CGPoint(x: -1, y: -40), control1: CGPoint(x: -14, y: -41),
      control2: CGPoint(x: -7, y: -42))
    leaf.addCurve(
      to: CGPoint(x: -15, y: -31), control1: CGPoint(x: -1, y: -32),
      control2: CGPoint(x: -5, y: -28))
    context.fill(leaf, with: .color(.kvilAccent))
    var shine = Path()
    shine.move(to: CGPoint(x: -28, y: -19))
    shine.addQuadCurve(to: CGPoint(x: -31, y: -10), control: CGPoint(x: -32, y: -16))
    context.stroke(
      shine, with: .color(highlight.opacity(0.42)),
      style: StrokeStyle(lineWidth: 2, lineCap: .round))

    // Draw the continuous front side after the cargo, including the apple's contact point.
    var nearRim = Path()
    nearRim.move(to: CGPoint(x: -78, y: -10))
    nearRim.addCurve(
      to: CGPoint(x: 78, y: -10), control1: CGPoint(x: -32, y: -2),
      control2: CGPoint(x: 32, y: -2))
    var hull = nearRim
    hull.addCurve(
      to: CGPoint(x: 40, y: 28), control1: CGPoint(x: 66, y: 12),
      control2: CGPoint(x: 61, y: 26))
    hull.addCurve(
      to: CGPoint(x: -40, y: 28), control1: CGPoint(x: 22, y: 34),
      control2: CGPoint(x: -22, y: 34))
    hull.addCurve(
      to: CGPoint(x: -78, y: -10), control1: CGPoint(x: -61, y: 26),
      control2: CGPoint(x: -66, y: 12))
    hull.closeSubpath()
    context.fill(
      hull,
      with: .linearGradient(
        Gradient(colors: [timber, timber.mix(with: shade, by: 0.2)]),
        startPoint: CGPoint(x: 0, y: -5), endPoint: CGPoint(x: 0, y: 33)))
    context.stroke(
      nearRim, with: .color(rimColor),
      style: StrokeStyle(lineWidth: 3, lineCap: .round))

    // One oar rests on the rim, with its blade reaching the water.
    var oar = Path()
    oar.move(to: CGPoint(x: 6, y: -11))
    oar.addLine(to: CGPoint(x: 58, y: 31))
    context.stroke(
      oar, with: .color(rimColor),
      style: StrokeStyle(lineWidth: 3, lineCap: .round))
    var blade = Path()
    blade.move(to: CGPoint(x: 50, y: 27))
    blade.addQuadCurve(to: CGPoint(x: 60, y: 26), control: CGPoint(x: 54, y: 22))
    blade.addLine(to: CGPoint(x: 78, y: 38))
    blade.addQuadCurve(to: CGPoint(x: 78, y: 43), control: CGPoint(x: 82, y: 40))
    blade.addLine(to: CGPoint(x: 74, y: 48))
    blade.addQuadCurve(to: CGPoint(x: 69, y: 48), control: CGPoint(x: 72, y: 51))
    blade.addLine(to: CGPoint(x: 52, y: 33))
    blade.addQuadCurve(to: CGPoint(x: 50, y: 27), control: CGPoint(x: 49, y: 31))
    context.fill(blade, with: .color(timber.mix(with: highlight, by: 0.15)))
  }
}
