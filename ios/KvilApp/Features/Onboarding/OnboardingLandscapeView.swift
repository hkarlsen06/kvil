import SwiftUI

struct OnboardingLandscapeView: View {
  var height: CGFloat
  private let extensionHeight: CGFloat = 120
  private let overlap: CGFloat = 48
  private let blurRadius: CGFloat = 28

  var body: some View {
    Color.clear.frame(height: height)
      .overlay(alignment: .top) {
        extendedLandscape
          .drawingGroup()
          .layerEffect(
            ShaderLibrary.progressiveLandscapeBlur(
              .boundingRect, .float(height - 90), .float(height + extensionHeight), .float(blurRadius),
              .float2(1, 0)),
            maxSampleOffset: CGSize(width: blurRadius, height: 0))
          .layerEffect(
            ShaderLibrary.progressiveLandscapeBlur(
              .boundingRect, .float(height - 90), .float(height + extensionHeight), .float(blurRadius),
              .float2(0, 1)),
            maxSampleOffset: CGSize(width: 0, height: blurRadius))
          .overlay(alignment: .bottom) {
            LinearGradient(
              stops: [
                .init(color: .kvilCanvas.opacity(0), location: 0),
                .init(color: .kvilCanvas.opacity(0.18), location: 0.30),
                .init(color: .kvilCanvas.opacity(0.75), location: 0.65),
                .init(color: .kvilCanvas, location: 1),
              ], startPoint: .top, endPoint: .bottom
            ).frame(height: extensionHeight + overlap)
          }
          .clipped()
      }
      .allowsHitTesting(false)
      .accessibilityHidden(true)
  }

  private var extendedLandscape: some View {
    Color.clear.frame(height: height + extensionHeight)
      .overlay(alignment: .top) {
        LandscapeView(height: height)
      }
      .overlay(alignment: .bottom) {
        // Preserve the image's crop and scale in the copy flipped on both axes.
        LandscapeView(height: height)
          .scaleEffect(x: -1, y: -1)
          .frame(height: extensionHeight + overlap, alignment: .top)
          .clipped()
          .mask {
            LinearGradient(
              stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: overlap / (extensionHeight + overlap)),
              ], startPoint: .top, endPoint: .bottom)
          }
      }
  }
}
