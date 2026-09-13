import SwiftUI

enum KvilMotion {
  static func transition(reduceMotion: Bool) -> Animation {
    reduceMotion ? .easeOut(duration: 0.18) : .spring(response: 0.55, dampingFraction: 0.86)
  }
}

struct KvilWindowActionButtonStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .background(
        configuration.isPressed ? Color.kvilAccent.opacity(0.2) : Color.kvilSurface,
        in: Capsule()
      )
      .contentShape(Capsule())
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.95 : 1)
      .animation(
        reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.3, dampingFraction: 0.65),
        value: configuration.isPressed)
  }
}
