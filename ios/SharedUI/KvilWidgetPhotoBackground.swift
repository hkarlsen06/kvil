import SwiftUI

extension Color {
  static let kvilOnPhoto = Color.white
  static let kvilOnPhotoSecondary = Color.white.opacity(0.85)
  static let kvilPhotoScrim = Color.black.opacity(0.60)
}

struct KvilWidgetPhotoBackground: View {
  var body: some View {
    Color.clear
      .overlay {
        // Keep the source pixels within WidgetKit's image limit, regardless of the view's size.
        Image("WidgetLandscape").resizable().scaledToFill()
      }
      .clipped()
      .overlay(Color.kvilPhotoScrim)
      .accessibilityHidden(true)
  }
}
