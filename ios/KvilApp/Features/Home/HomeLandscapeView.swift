import SwiftUI

/// Presentation stays local to Home; the schedule remains the source of the eating-window phase.
struct HomeLandscapeView: View {
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let isOpen: Bool
  let isSelected: Bool
  let presentationID: UUID?
  let boatArea: ClosedRange<CGFloat>
  @Binding var reveal: CGFloat
  @State private var isVisible = false
  @State private var wasPresented = false
  @State private var lastPresentationID: UUID?

  private struct Presentation: Equatable {
    var isOpen: Bool
    var isPresented: Bool
    var id: UUID?
    var reduceMotion: Bool
  }

  var body: some View {
    Group {
      if reduceMotion {
        // Preserve the visual cue without moving the camera or the mountains.
        ZStack {
          KvilLandscapeBackground(boatArea: boatArea).opacity(1 - reveal)
          KvilLandscapeBackground(eatingWindowReveal: 1, boatArea: boatArea).opacity(reveal)
        }
      } else {
        KvilLandscapeBackground(eatingWindowReveal: reveal, boatArea: boatArea)
      }
    }
    .onAppear { isVisible = true }
    .onDisappear { isVisible = false }
    .task(
      id: Presentation(
        isOpen: isOpen, isPresented: isVisible && isSelected && scenePhase == .active,
        id: presentationID, reduceMotion: reduceMotion)
    ) {
      let isPresented = isVisible && isSelected && scenePhase == .active
      let arriving = !wasPresented || lastPresentationID != presentationID
      wasPresented = isPresented
      guard isPresented else { return }
      lastPresentationID = presentationID

      if isOpen && arriving {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) { reveal = 0 }
        // Give the wide landscape a visible frame, including on a cold notification launch.
        do { try await Task.sleep(for: .milliseconds(180)) } catch { return }
      }
      guard !Task.isCancelled else { return }
      withAnimation(
        reduceMotion ? .easeInOut(duration: 0.25) : .smooth(duration: 1.8, extraBounce: 0)
      ) {
        reveal = isOpen ? 1 : 0
      }
    }
  }
}
