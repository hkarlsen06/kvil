import SwiftUI

enum OnboardingStep: Int, CaseIterable {
  case welcome, windows, meals, approach, preview
}

/// Shows the wall-clock pause between the selected window’s closing and its next opening.
struct OnboardingPauseView: View {
  @Environment(\.locale) private var locale
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @ScaledMetric(relativeTo: .caption) private var arcLabelSpace: CGFloat = 24
  var day: DayPlan
  @State private var appeared = false
  private let markerSize: CGFloat = 38

  private var pauseMinutes: Int { 1440 - day.windowMinutes }
  private var nextMealIsTomorrow: Bool { day.opens < day.closes }
  private var nextMealClock: String {
    clock(day.opens) + (nextMealIsTomorrow ? ", " + String(localized: .nextDayShort) : "")
  }

  private var duration: String {
    Duration.seconds(pauseMinutes * 60).formatted(
      .units(allowed: [.hours, .minutes], width: .abbreviated).locale(locale))
  }

  private var spokenDuration: String {
    Duration.seconds(pauseMinutes * 60).formatted(
      .units(allowed: [.hours, .minutes], width: .wide).locale(locale))
  }

  var body: some View {
    VStack(spacing: KvilStyle.content) {
      VStack(spacing: KvilStyle.related) {
        if typeSize.isAccessibilitySize {
          Text(.onboardingPauseCaption).font(.caption).foregroundStyle(Color.kvilSecondary)
        }
        night
        if typeSize.isAccessibilitySize {
          Text(.onboardingPauseDuration(duration)).font(KvilStyle.heading)
            .fixedSize(horizontal: false, vertical: true)
        }
        let timesLayout = typeSize.isAccessibilitySize
          ? AnyLayout(VStackLayout(spacing: KvilStyle.related))
          : AnyLayout(HStackLayout(alignment: .top))
        timesLayout {
          mealTime(day.closes, title: .onboardingLastMeal)
          if !typeSize.isAccessibilitySize { Spacer() }
          mealTime(day.opens, title: .onboardingNextMeal, nextDay: nextMealIsTomorrow)
        }.padding(.top, KvilStyle.content)
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(Text(.onboardingPauseCaption))
      .accessibilityValue(Text(.onboardingPauseSummary(clock(day.closes), nextMealClock, spokenDuration)))
      .accessibilityIdentifier("onboardingNightExplanation")

      Text(.onboardingListen).foregroundStyle(Color.kvilSecondary)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .onAppear {
      withAnimation(reduceMotion ? nil : .smooth(duration: 1.1)) { appeared = true }
    }
  }

  private var night: some View {
    let labelSpace = typeSize.isAccessibilitySize ? 0 : arcLabelSpace
    return GeometryReader { geometry in
      let radius = min(geometry.size.width / 2, geometry.size.height - labelSpace) - markerSize / 2
      let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height - markerSize / 2)
      ZStack(alignment: .top) {
        OnboardingNightArc(markerRadius: markerSize / 2, labelSpace: labelSpace)
          .stroke(Color.kvilTrack, style: StrokeStyle(lineWidth: 7, lineCap: .round))
        OnboardingNightArc(markerRadius: markerSize / 2, labelSpace: labelSpace)
          .trim(from: 0, to: appeared ? 1 : 0)
          .stroke(Color.kvilMoon.gradient, style: StrokeStyle(lineWidth: 7, lineCap: .round))
        if !typeSize.isAccessibilitySize {
          KvilArcLabel(
            label: .onboardingPauseCaption,
            center: UnitPoint(x: 0.5, y: center.y / geometry.size.height),
            radius: radius + labelSpace / 2 + 2, angle: -.pi / 2)
        }
        VStack(spacing: KvilStyle.related) {
          let midpoint = (day.closes.minute + pauseMinutes / 2) % 1440
          Image(systemName: (360..<1080).contains(midpoint) ? "sun.max" : "moon.stars")
            .font(.system(size: 30, weight: .light))
            .foregroundStyle(Color.kvilMoon)
          if !typeSize.isAccessibilitySize {
            Text(.onboardingPauseDuration(duration))
              .font(.system(size: 28, weight: .light, design: .rounded))
              .monospacedDigit()
              .lineLimit(1).minimumScaleFactor(0.75).frame(maxWidth: radius * 1.5)
          }
        }.padding(.top, 35 + labelSpace).frame(maxWidth: .infinity).opacity(appeared ? 1 : 0)
        mealSymbol("fork.knife")
          .position(x: center.x - radius, y: center.y)
        mealSymbol((6..<18).contains(day.opens.hour) ? "sun.max" : "moon")
          .position(x: center.x + radius, y: center.y)
      }
    }
    // Include each whole marker in layout before placing the time labels below it.
    .frame(height: 128 + markerSize / 2 + labelSpace)
    .environment(\.layoutDirection, .leftToRight)
  }

  private func mealSymbol(_ symbol: String) -> some View {
    Image(systemName: symbol).font(.system(size: 19, weight: .light))
      .foregroundStyle(Color.kvilAccent)
      .frame(width: markerSize, height: markerSize)
      .background(Color.kvilCanvas, in: Circle())
      .overlay { Circle().strokeBorder(Color.kvilLine, lineWidth: 1) }
  }

  private func mealTime(_ time: WallTime, title: LocalizedStringResource, nextDay: Bool = false) -> some View {
    VStack(spacing: 4) {
      Text(verbatim: clock(time)).font(KvilStyle.heading).monospacedDigit()
      Text(title).font(.caption).foregroundStyle(Color.kvilSecondary)
      if nextDay {
        Text(.nextDayShort).font(.caption).foregroundStyle(Color.kvilSecondary)
      }
    }.fixedSize(horizontal: false, vertical: true)
  }

  private func clock(_ time: WallTime) -> String {
    Date(timeIntervalSinceReferenceDate: TimeInterval(time.minute * 60))
      .formatted(Date.FormatStyle(locale: locale, timeZone: .gmt).hour().minute())
  }
}

private struct OnboardingNightArc: Shape {
  var markerRadius: CGFloat
  var labelSpace: CGFloat

  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.addArc(
      center: CGPoint(x: rect.midX, y: rect.maxY - markerRadius),
      radius: min(rect.width / 2, rect.height - labelSpace) - markerRadius,
      startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
    return path
  }
}

struct OnboardingProgressView: View {
  var step: OnboardingStep

  var body: some View {
    HStack(spacing: KvilStyle.section) {
      KvilWordmark().frame(minHeight: 44)
      Spacer(minLength: 0)
      HStack(spacing: 5) {
        ForEach(OnboardingStep.allCases, id: \.rawValue) { item in
          Capsule()
            .fill(item.rawValue <= step.rawValue ? Color.kvilAccent : Color.kvilTrack)
            .frame(width: item == step ? 28 : 13, height: 4)
        }
      }
      .frame(height: 44)
      .contentShape(Rectangle())
      .accessibilityElement(children: .ignore)
      .accessibilityAddTraits(.isStaticText)
      .accessibilityLabel(Text(.onboardingProgress))
      .accessibilityValue(Text(.onboardingStep(step.rawValue + 1, OnboardingStep.allCases.count)))
      .accessibilityIdentifier("onboardingProgress")
    }
    .padding(.horizontal, KvilStyle.page).padding(.vertical, KvilStyle.related)
  }
}

/// Explains each rhythm while choosing the window used by the rest of setup.
struct OnboardingWindowsView: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var typeSize
  @ScaledMetric(relativeTo: .caption) private var arcLabelSpace: CGFloat = 18
  @Binding var rhythm: FastingRhythm
  var windowMinutes: Int
  @State private var appeared = false
  private let dialSize: CGFloat = 200

  private var fastingFraction: Double {
    Double(1440 - windowMinutes) / 1440
  }

  var body: some View {
    let optionsLayout =
      typeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(spacing: KvilStyle.related))
      : AnyLayout(HStackLayout(spacing: KvilStyle.related))
    VStack(spacing: KvilStyle.related) {
      VStack(spacing: KvilStyle.related) {
        labeledDial
          .frame(maxWidth: .infinity)
          .accessibilityElement(children: .ignore)
          .accessibilityLabel(Text(rhythm.summary))
          .accessibilityIdentifier("onboardingWindowExplanation")
        if typeSize.isAccessibilitySize {
          Text(rhythm.summary).font(.body).foregroundStyle(Color.kvilSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      VStack(spacing: KvilStyle.related) {
        optionsLayout {
          ForEach([FastingRhythm.twelve, .fourteen, .sixteen]) { option in
            rhythmButton(option)
          }
        }
        rhythmButton(.custom)
      }
    }
    .onAppear {
      withAnimation(reduceMotion ? nil : .smooth(duration: 1.1)) { appeared = true }
    }
  }

  private var labeledDial: some View {
    let labelSpace = typeSize.isAccessibilitySize ? 0 : arcLabelSpace
    let radius = dialSize / 2 + labelSpace / 2 + 1
    return ZStack {
      dial.frame(width: dialSize, height: dialSize)
      if !typeSize.isAccessibilitySize {
        KvilArcLabel(
          label: .onboardingFasting, color: .kvilMoon,
          radius: radius, angle: -.pi / 2 - .pi * fastingFraction)
        KvilArcLabel(
          label: .onboardingMeals, color: .kvilAccent,
          radius: radius, angle: .pi / 2 - .pi * fastingFraction)
      }
    }.frame(width: dialSize + labelSpace * 2, height: dialSize + labelSpace * 2)
  }

  private func rhythmButton(_ option: FastingRhythm) -> some View {
    Button {
      withAnimation(reduceMotion ? nil : .spring(duration: 0.65, bounce: 0.12)) {
        rhythm = option
      }
    } label: {
      Text(option.title).font(.subheadline.weight(.medium)).monospacedDigit()
        .lineLimit(option == .custom ? nil : 1)
        .frame(maxWidth: .infinity, minHeight: 44)
        .padding(.vertical, typeSize.isAccessibilitySize ? KvilStyle.related : 0)
        .background(rhythm == option ? Color.kvilSurface : .clear, in: Capsule())
        .overlay {
          Capsule().strokeBorder(
            rhythm == option ? Color.kvilAccent : Color.kvilLine, lineWidth: 1)
        }
        .contentShape(Capsule())
    }.buttonStyle(.plain)
      .accessibilityLabel(Text(option.summary))
      .accessibilityAddTraits(rhythm == option ? .isSelected : [])
      .accessibilityIdentifier("setupRhythm.\(option.rawValue)")
  }

  private var dial: some View {
    ZStack {
      Circle().fill(Color.kvilSurface.opacity(0.65)).padding(20)
      ForEach(0..<24) { hour in
        Capsule().fill(Color.kvilSecondary.opacity(hour.isMultiple(of: 6) ? 0.5 : 0.18))
          .frame(width: 1, height: hour.isMultiple(of: 6) ? 7 : 3)
          .offset(y: 22 - dialSize / 2).rotationEffect(.degrees(Double(hour) * 15))
      }
      Circle().trim(from: 0.012, to: appeared ? fastingFraction - 0.012 : 0.012)
        .stroke(
          Color.kvilMoon.gradient,
          style: StrokeStyle(lineWidth: 9, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .scaleEffect(x: -1, y: 1)
      Circle().trim(from: fastingFraction + 0.012, to: appeared ? 0.988 : fastingFraction + 0.012)
        .stroke(
          Color.kvilAccent.gradient,
          style: StrokeStyle(lineWidth: 9, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .scaleEffect(x: -1, y: 1)
      Group {
        if rhythm == .custom {
          Image(systemName: "slider.horizontal.3").font(.largeTitle)
        } else {
          Text(rhythm.title).font(.system(size: 46, weight: .light, design: .rounded))
            .monospacedDigit().contentTransition(.numericText())
            .overlay(alignment: .top) {
              Text(.onboardingHours).font(.caption).foregroundStyle(Color.kvilSecondary)
                .alignmentGuide(.top) { $0[.bottom] + 12 }
            }
        }
      }
      .opacity(appeared ? 1 : 0)
      .offset(y: appeared || reduceMotion ? 0 : 10)
    }
    .padding(5)
    .environment(\.layoutDirection, .leftToRight)
  }
}
