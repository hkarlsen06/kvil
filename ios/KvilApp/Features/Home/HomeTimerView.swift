import SwiftUI

struct HomeTimerView: View {
  @Environment(\.locale) private var locale
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase
  let state: ScheduleState
  let now: Date
  @Binding var highlightPending: Bool
  let isSelected: Bool
  var compact = false
  var clockIsPaused = false
  var daylight: CGFloat = 0
  @State private var isVisible = false
  @State private var displayedProgress = 0.0
  @State private var motionCue = 0

  private struct PhaseUpdate: Equatable {
    var isOpen: Bool
    var isActive: Bool
    var highlightPending: Bool
  }

  private struct ProgressUpdate: Equatable {
    var progress: Double
    var isVisible: Bool
  }

  private var isPresented: Bool { isVisible && isSelected && scenePhase == .active }

  private var countdownAnimationDuration: TimeInterval { reduceMotion ? 0 : 0.2 }

  private func remaining(at date: Date) -> Duration {
    .seconds(max(0, state.next.opening.timeIntervalSince(date)))
  }

  private func countdown(at date: Date) -> AttributedString {
    var value = remaining(at: date).formatted(
      .time(pattern: .hourMinuteSecond(padHourToLength: 1, roundFractionalSeconds: .up))
        .locale(locale).attributed)
    // Keep the localized separator with the quieter seconds, on the same baseline.
    if let minutes = value.runs.first(where: {
      $0[AttributeScopes.FoundationAttributes.DurationFieldAttribute.self] == .minutes
    }) {
      let seconds = minutes.range.upperBound..<value.endIndex
      value[seconds][AttributeScopes.SwiftUIAttributes.FontAttribute.self] =
        typeSize.isAccessibilitySize
        ? .system(compact ? .title3 : .title2, design: .rounded, weight: .light)
        : .system(size: compact ? 24 : 28, weight: .light, design: .rounded)
      value[seconds][AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] =
        .kvilSecondary
    }
    return value
  }

  var body: some View {
    Group {
      if typeSize.isAccessibilitySize {
        timerContent.padding(compact ? 0 : 24)
      } else {
        ZStack {
          LabeledProgressRing(
            progress: displayedProgress,
            label: state.isOpen ? .yourWindow : .atYourPace,
            daylight: daylight
          )
          .phaseAnimator([false, true, false], trigger: motionCue) { ring, pulse in
            ring.scaleEffect(pulse && !reduceMotion ? 1.025 : 1)
          } animation: { _ in
            .easeInOut(duration: 0.45)
          }
          timerContent
        }.frame(width: compact ? 220 : 272, height: compact ? 220 : 272)
          .padding(.horizontal, 18).padding(.bottom, 12)
      }
    }
    .onAppear { isVisible = true }
    .onDisappear { isVisible = false }
    .task(id: ProgressUpdate(progress: state.progress, isVisible: isPresented)) {
      guard isPresented else { return }
      // Preserve the last visible fill until Home has rejoined the view hierarchy.
      await Task.yield()
      guard !Task.isCancelled else { return }
      withAnimation(reduceMotion ? nil : .spring(response: 0.95, dampingFraction: 0.86)) {
        displayedProgress = state.progress
      }
    }
    .onChange(
      of: PhaseUpdate(
        isOpen: state.isOpen, isActive: isPresented, highlightPending: highlightPending),
      initial: true
    ) { previous, current in
      guard current.isActive else { return }
      // Keep link and reminder highlights pending until Home is visible, then consume them once.
      let windowChanged = previous.isActive && previous.isOpen != current.isOpen
      guard current.highlightPending || windowChanged else { return }
      highlightPending = false
      motionCue += 1
    }
    .animation(KvilMotion.transition(reduceMotion: reduceMotion), value: state.isOpen)
  }

  private var timerContent: some View {
    VStack(spacing: 12) {
      if !compact || !typeSize.isAccessibilitySize {
        ZStack {
          Image(systemName: "moon").foregroundStyle(Color.kvilMoon).opacity(1 - daylight)
          Image(systemName: "sun.max").foregroundStyle(Color.kvilSun).opacity(daylight)
        }.font(.title3.weight(.light)).accessibilityHidden(true)
      }
      Group {
        if state.isOpen {
          Text(.windowOpen).font(.system(compact ? .title2 : .largeTitle, design: .serif))
            .multilineTextAlignment(.center)
        } else {
          VStack(spacing: 12) {
            countdownText
            Text(compact ? .untilOpening : .untilEatingWindow)
              .font(compact ? .caption : .subheadline)
              .multilineTextAlignment(.center).foregroundStyle(Color.kvilSecondary)
          }
        }
      }.id(state.isOpen)
        .transition(
          reduceMotion
            ? .opacity
            : .asymmetric(
              insertion: .offset(y: 10).combined(with: .scale(scale: 0.94)).combined(
                with: .opacity),
              removal: .offset(y: -8).combined(with: .opacity)))
    }.frame(maxWidth: .infinity).accessibilityElement(children: .combine)
  }

  private var countdownText: some View {
    // Preserve the opening's second boundary, including fractional-second overrides.
    let phase = state.next.opening.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1)
    // Start the digit transition early so it finishes on the countdown's next second.
    return TimelineView(
      .periodic(
        from: Date(timeIntervalSinceReferenceDate: phase - countdownAnimationDuration), by: 1)
    ) { _ in
      let current = clockIsPaused ? now : Date()
      let value = countdown(
        at: current.addingTimeInterval(clockIsPaused ? 0 : countdownAnimationDuration))
      Text(value)
        .font(
          typeSize.isAccessibilitySize
            ? .system(compact ? .title : .largeTitle, design: .rounded, weight: .light)
            : .system(size: compact ? 48 : 60, weight: .light, design: .rounded)
        ).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
        .contentTransition(reduceMotion ? .opacity : .numericText(countsDown: true))
        .animation(
          reduceMotion ? nil : .easeOut(duration: countdownAnimationDuration), value: value
        )
        .accessibilityLabel(.untilEatingWindow)
        .accessibilityValue(
          Text(
            remaining(at: current),
            format: .units(
              allowed: [.hours, .minutes, .seconds], width: .wide,
              fractionalPart: .hide(rounded: .up))))
    }
  }
}
