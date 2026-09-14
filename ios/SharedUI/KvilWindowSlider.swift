#if os(iOS)
  import SwiftUI
  import UIKit

  struct KvilWindowSlider: View {
    var day: DayPlan
    var title: String
    var value: String
    var onMove: (DayPlan, DayPlan) -> Void
    var onEdit: (() -> Void)? = nil
    var onPreview: (DayPlan?) -> Void
    @State private var origin: DayPlan?
    @State private var preview: DayPlan?

    var body: some View {
      GeometryReader { geometry in
        let shown = preview ?? day
        KvilWindowTimeline(opens: shown.opens, closes: shown.closes, showsGrip: true)
          .frame(height: 24).frame(height: 44)
          .contentShape(Rectangle())
          .gesture(
            WindowPan { state, translation in
              switch state {
              case .began, .changed:
                if origin == nil { origin = day }
                let steps = Int((translation / max(1, geometry.size.width) * 1440 / 15).rounded())
                preview = origin?.shifted(by: steps * 15)
                onPreview(preview)
              case .ended:
                if let origin {
                  let steps = Int((translation / max(1, geometry.size.width) * 1440 / 15).rounded())
                  onMove(origin, origin.shifted(by: steps * 15))
                }
                origin = nil
                preview = nil
                onPreview(nil)
              default:
                origin = nil
                preview = nil
                onPreview(nil)
              }
            }
          )
      }.frame(height: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityValue(Text(verbatim: value))
        .accessibilityHint(.moveWindowHint)
        .accessibilityAdjustableAction { direction in
          switch direction {
          case .increment: onMove(day, day.shifted(by: 15))
          case .decrement: onMove(day, day.shifted(by: -15))
          @unknown default: break
          }
        }
        .accessibilityActions {
          if let onEdit { Button(.editWindowTimes, action: onEdit) }
        }
        .sensoryFeedback(.selection, trigger: preview?.opens.minute)
    }
  }

  /// A vertical swipe fails this recognizer, leaving the surrounding ScrollView free to scroll.
  private struct WindowPan: UIGestureRecognizerRepresentable {
    var onChange: (UIGestureRecognizer.State, CGFloat) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> WindowPanRecognizer {
      let pan = WindowPanRecognizer()
      pan.maximumNumberOfTouches = 1
      pan.delegate = context.coordinator
      return pan
    }

    func handleUIGestureRecognizerAction(_ pan: WindowPanRecognizer, context: Context) {
      onChange(pan.state, pan.translationFromTouchDown)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
      func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
        let velocity = pan.velocity(in: pan.view)
        return abs(velocity.x) > abs(velocity.y)
      }
    }
  }

  private final class WindowPanRecognizer: UIPanGestureRecognizer {
    private var initialLocation: CGPoint?

    // Include movement before the pan is recognized so the window follows the finger precisely.
    var translationFromTouchDown: CGFloat {
      location(in: view).x - (initialLocation?.x ?? location(in: view).x)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
      if initialLocation == nil { initialLocation = touches.first?.location(in: view) }
      super.touchesBegan(touches, with: event)
    }

    override func reset() {
      super.reset()
      initialLocation = nil
    }
  }
#endif
