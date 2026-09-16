import SwiftUI
import UIKit

struct OnboardingView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.locale) private var locale
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @ScaledMetric(relativeTo: .caption) private var nextDayLabelHeight: CGFloat = 16
  @State private var page = OnboardingStep.welcome
  @State private var movingForward = true
  @State private var rhythm = FastingRhythm.twelve
  @State private var opens = WallTime(hour: 8)
  @State private var closes = WallTime(hour: 20)
  @State private var days = (1...7).map {
    DayPlan(weekday: $0, opens: .init(hour: 8), closes: .init(hour: 20))
  }
  @State private var slidingWindow: DayPlan?
  @State private var slidingDay: DayPlan?
  @State private var enableReminders = true
  @State private var cloudScheduleChoice: Bool?
  @State private var showingGuide = false
  @State private var busy = false
  @AccessibilityFocusState private var headingFocused: Bool

  var body: some View {
    VStack(spacing: 0) {
      OnboardingProgressView(step: page)
      ZStack {
        Group {
          switch page {
          case .welcome: welcomePage
          case .windows: windowsPage
          case .meals: mealTimesPage
          case .approach: approachPage
          case .preview: previewPage
          }
        }.id(page).transition(pageTransition)
      }
      .clipped()
    }
    .background(Color.kvilCanvas)
    .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: page)
    .sensoryFeedback(.selection, trigger: rhythm)
    .sensoryFeedback(.selection, trigger: enableReminders)
    .sheet(isPresented: $showingGuide) {
      NavigationStack {
        FastingGuideView()
          .toolbar {
            ToolbarItem(placement: .confirmationAction) {
              Button(.done) { showingGuide = false }
            }
          }
      }.tint(Color.kvilAccent)
    }
  }

  private var welcomePage: some View {
    GeometryReader { geometry in
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          OnboardingLandscapeView(
            height: max(210, geometry.size.height * 0.58)
          )
          VStack(alignment: .leading, spacing: KvilStyle.content) {
            Text(.onboardingTitle).font(KvilStyle.title).fixedSize(
              horizontal: false, vertical: true
            )
            .accessibilityAddTraits(.isHeader).accessibilityFocused($headingFocused)
            Text(.onboardingBody).foregroundStyle(Color.kvilSecondary).lineSpacing(4)
            Text(.onboardingSafety).font(.footnote).foregroundStyle(Color.kvilSecondary)
              .padding(.top, 2)
          }.padding(KvilStyle.page)
        }
      }.scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
          KvilBottomActions {
            Button(.onboardingBegin) { navigate(to: .windows) }.buttonStyle(
              KvilPrimaryButtonStyle()
            )
            .accessibilityIdentifier("beginSetup")
          }
        }
    }.background(Color.kvilCanvas)
  }

  private var windowsPage: some View {
    KvilActionPage {
      pageHeading(.onboardingWindowsTitle, help: .onboardingWindowsBody)
      OnboardingWindowsView(
        rhythm: rhythmSelection,
        windowMinutes: DayPlan(weekday: 1, opens: opens, closes: closes).windowMinutes)
    } actions: {
      Button(.onboardingUseRhythm) { navigate(to: .meals) }
        .buttonStyle(KvilPrimaryButtonStyle()).accessibilityIdentifier("continueWindows")
      backButton(to: .welcome)
    }
  }

  private var approachPage: some View {
    KvilActionPage {
      pageHeading(.onboardingApproachTitle, help: .onboardingApproachBody)
      OnboardingPauseView(day: DayPlan(weekday: 1, opens: opens, closes: closes))
      Button(.guideSuitabilityTitle, systemImage: "info.circle") { showingGuide = true }
        .frame(minHeight: 44).accessibilityIdentifier("onboardingSafetyGuide")
    } actions: {
      Button(.setupPreviewWeek) { navigate(to: .preview) }
        .buttonStyle(KvilPrimaryButtonStyle()).accessibilityIdentifier("previewSetup")
      backButton(to: .meals)
    }
  }

  private var rhythmSelection: Binding<FastingRhythm> {
    Binding {
      rhythm
    } set: { selection in
      guard rhythm != selection else { return }
      rhythm = selection
      if let day = selection.example { setWindow(day) }
    }
  }

  private var mealTimesPage: some View {
    let day = DayPlan(weekday: 1, opens: opens, closes: closes)
    let shown = slidingWindow ?? day
    return KvilActionPage {
      pageHeading(.setupMealsTitle, help: .setupMealsHelp)
      VStack(alignment: .leading, spacing: KvilStyle.content) {
        Text(rhythm.title).font(KvilStyle.heading).fixedSize(horizontal: false, vertical: true)
        Text(rhythm.mealHelp).font(.subheadline).foregroundStyle(Color.kvilSecondary)
          .fixedSize(horizontal: false, vertical: true)
        if rhythm == .custom {
          KvilControlRow(title: .windowLength) {
            KvilWindowLengthPicker(selected: day.windowMinutes) { minutes in
              if let updated = try? day.resized(to: minutes) { setWindow(updated) }
            }.labelsHidden().accessibilityIdentifier("setupWindowLength")
          }
        }
        ViewThatFits(in: .horizontal) {
          if !typeSize.isAccessibilitySize {
            HStack(alignment: .top, spacing: KvilStyle.content) {
              mealTime(shown.opens, title: .setupFirstMeal)
              Spacer(minLength: 0)
              mealTime(shown.closes, title: .setupLastMeal)
            }
          }
          VStack(alignment: .leading, spacing: KvilStyle.content) {
            mealTime(shown.opens, title: .setupFirstMeal)
            mealTime(shown.closes, title: .setupLastMeal)
          }
        }
        // Keep the bar steady across midnight without laying out an invisible text label.
        Color.clear.frame(height: nextDayLabelHeight).overlay(alignment: .leading) {
          if shown.overnight {
            Text(.nextDayShort).font(.caption).foregroundStyle(Color.kvilSecondary).fixedSize()
          }
        }
        KvilWindowSlider(
          day: day, title: String(localized: .eatingWindow), value: windowSummary(shown),
          onMove: { _, updated in setWindow(updated) }, onPreview: { slidingWindow = $0 }
        ).accessibilityIdentifier("setupWindowSlider")
        KvilDayAxis()
      }.padding(KvilStyle.cardPadding)
        .background(Color.kvilSurface, in: RoundedRectangle(cornerRadius: KvilStyle.corner))
      Text(.setupWindowHelp).font(.footnote).foregroundStyle(Color.kvilSecondary)
        .fixedSize(horizontal: false, vertical: true)
    } actions: {
      Button(.onboardingSeePause) { navigate(to: .approach) }.buttonStyle(KvilPrimaryButtonStyle())
        .disabled(opens == closes).accessibilityIdentifier("continueMealTimes")
      backButton(to: .windows)
    }
  }

  private var previewPage: some View {
    KvilActionPage {
      pageHeading(.setupWeekTitle, help: .setupWeekHelp)
      KvilDescribedToggle(
        title: .cloudSchedule, description: .setupStorageHelp, isOn: cloudScheduleSelection
      ).accessibilityIdentifier("setupCloudScheduleSync")
      VStack(alignment: .leading, spacing: KvilStyle.content) {
        ForEach(previewDates, id: \.self) { date in
          if let day = days.first(where: {
            $0.weekday == model.calendar.component(.weekday, from: date)
          }) {
            weekRow(day, date: date)
          }
        }
        KvilDayAxis()
        Label {
          Text(.eatingWindow).fixedSize(horizontal: false, vertical: true)
        } icon: {
          Capsule().fill(Color.kvilAccent).frame(width: 16, height: 6)
        }.font(.caption).foregroundStyle(Color.kvilSecondary)
      }.padding(KvilStyle.cardPadding)
        .background(Color.kvilSurface, in: RoundedRectangle(cornerRadius: KvilStyle.corner))
      KvilDescribedToggle(
        title: .gentleReminders, description: .setupReminderHelp, isOn: $enableReminders)
    } actions: {
      Button {
        Task { await finish() }
      } label: {
        if busy { ProgressView().tint(Color.kvilInverse) } else { Text(.makeSpace) }
      }.buttonStyle(KvilPrimaryButtonStyle()).disabled(busy).accessibilityIdentifier("finishSetup")
      backButton(to: .approach).disabled(busy)
    }
  }

  private var cloudScheduleSelection: Binding<Bool> {
    Binding {
      cloudScheduleChoice ?? model.data.preferences.cloudScheduleEnabled
    } set: {
      cloudScheduleChoice = $0
    }
  }

  private func pageHeading(_ title: LocalizedStringResource, help: LocalizedStringResource)
    -> some View
  {
    VStack(alignment: .leading, spacing: KvilStyle.content) {
      Text(title).font(KvilStyle.title).fixedSize(horizontal: false, vertical: true)
        .accessibilityAddTraits(.isHeader).accessibilityFocused($headingFocused)
      Text(help).foregroundStyle(Color.kvilSecondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var pageTransition: AnyTransition {
    if reduceMotion { return .opacity }
    return .asymmetric(
      insertion: .offset(x: movingForward ? 28 : -28).combined(with: .opacity),
      removal: .offset(x: movingForward ? -20 : 20).combined(with: .opacity))
  }

  private func navigate(to next: OnboardingStep) {
    movingForward = next.rawValue > page.rawValue
    headingFocused = false
    withAnimation(reduceMotion ? nil : .smooth(duration: 0.4)) {
      page = next
    } completion: {
      headingFocused = true
    }
  }

  private func backButton(to page: OnboardingStep) -> some View {
    Button(.back) { navigate(to: page) }.frame(maxWidth: .infinity, minHeight: 44)
      .accessibilityIdentifier("onboardingBack")
  }

  private func setWindow(_ day: DayPlan) {
    guard day.opens != opens || day.closes != closes else { return }
    opens = day.opens
    closes = day.closes
    days = (1...7).map { DayPlan(weekday: $0, opens: day.opens, closes: day.closes) }
  }

  private func weekRow(_ day: DayPlan, date: Date) -> some View {
    let shown = slidingDay?.weekday == day.weekday ? slidingDay ?? day : day
    let weekday = date.formatted(.dateTime.weekday(.wide).locale(locale))
    return VStack(alignment: .leading, spacing: 0) {
      Group {
        let title = Text(verbatim: weekday).font(.subheadline.weight(.medium))
          .fixedSize(horizontal: !typeSize.isAccessibilitySize, vertical: true)
        if typeSize.isAccessibilitySize {
          VStack(alignment: .leading, spacing: 4) {
            title
            weekTimes(shown)
          }
        } else {
          ViewThatFits(in: .horizontal) {
            HStack(spacing: KvilStyle.related) {
              title
              Spacer(minLength: 0)
              weekTimes(shown).fixedSize()
            }
            VStack(alignment: .leading, spacing: 4) {
              title
              weekTimes(shown)
            }
          }
        }
      }.accessibilityElement(children: .combine)
        .accessibilityIdentifier("setupDayTimes.\(day.weekday)")
      KvilWindowSlider(
        day: day, title: weekday, value: windowSummary(shown),
        onMove: { _, updated in
          if let index = days.firstIndex(where: { $0.weekday == updated.weekday }) {
            days[index] = updated
          }
        }, onPreview: { slidingDay = $0 }
      ).accessibilityIdentifier("setupWindowSlider.\(day.weekday)")
    }
  }

  private func weekTimes(_ day: DayPlan) -> some View {
    Group {
      if typeSize.isAccessibilitySize {
        VStack(alignment: .leading, spacing: 4) {
          Text(verbatim: wallTime(day.opens)).fixedSize()
          Text(verbatim: "–")
          Text(verbatim: wallTime(day.closes)).fixedSize()
          if day.overnight { Text(.nextDayShort).font(.caption) }
        }
      } else {
        Text(verbatim: windowTimes(day)).fixedSize()
      }
    }.font(.footnote).monospacedDigit().foregroundStyle(Color.kvilSecondary)
  }

  private func windowTimes(_ day: DayPlan) -> String {
    let nextDay = day.overnight ? ", " + String(localized: .nextDayShort) : ""
    return "\(wallTime(day.opens)) – \(wallTime(day.closes))\(nextDay)"
  }

  private func windowSummary(_ day: DayPlan) -> String {
    let duration = Duration.seconds(day.windowMinutes * 60).formatted(
      .units(allowed: [.hours, .minutes], width: .abbreviated).locale(locale))
    return "\(windowTimes(day)), \(duration)"
  }

  private func wallTime(_ time: WallTime) -> String {
    Date(timeIntervalSinceReferenceDate: TimeInterval(time.minute * 60))
      .formatted(Date.FormatStyle(locale: locale, timeZone: .gmt).hour().minute())
  }

  private func mealTime(_ time: WallTime, title: LocalizedStringResource) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(title).font(.caption).foregroundStyle(Color.kvilSecondary)
        .fixedSize(horizontal: false, vertical: true)
      Text(verbatim: wallTime(time)).font(KvilStyle.heading).monospacedDigit().fixedSize()
    }.accessibilityElement(children: .combine)
  }

  private var previewDates: [Date] {
    let calendar = model.calendar
    // Keep row identities stable when drag previews redraw with a live clock.
    let today = calendar.startOfDay(for: model.now)
    return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
  }

  private func finish() async {
    busy = true
    defer { busy = false }
    guard
      model.configure(days: days, cloudScheduleEnabled: cloudScheduleSelection.wrappedValue)
    else { return }
    UINotificationFeedbackGenerator().notificationOccurred(.success)
    if enableReminders {
      await model.setReminder(opening: true, enabled: true)
      if model.data.preferences.openingReminder {
        await model.setReminder(opening: false, enabled: true)
      }
    }
  }
}
