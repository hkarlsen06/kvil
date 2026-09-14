import SwiftUI

struct OnboardingView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.locale) private var locale
  @Environment(\.dynamicTypeSize) private var typeSize
  @ScaledMetric(relativeTo: .caption) private var nextDayLabelHeight: CGFloat = 16
  @State private var page = 0
  @State private var rhythm = FastingRhythm.twelve
  @State private var opens = WallTime(hour: 8)
  @State private var closes = WallTime(hour: 20)
  @State private var days = (1...7).map {
    DayPlan(weekday: $0, opens: .init(hour: 8), closes: .init(hour: 20))
  }
  @State private var slidingWindow: DayPlan?
  @State private var slidingDay: DayPlan?
  @State private var enableReminders = true
  @State private var showingGuide = false
  @State private var busy = false
  @AccessibilityFocusState private var headingFocused: Bool

  var body: some View {
    Group {
      switch page {
      case 0: welcomePage
      case 1: rhythmPage
      case 2: mealTimesPage
      default: previewPage
      }
    }
    .onChange(of: page) { headingFocused = true }
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
          KvilWordmark().padding(.horizontal, KvilStyle.page).padding(.top, KvilStyle.page)
          OnboardingLandscapeView(
            height: max(210, geometry.size.height * 0.58)
          ).padding(.top, KvilStyle.section)
          VStack(alignment: .leading, spacing: KvilStyle.content) {
            Text(.onboardingTitle).font(KvilStyle.title).fixedSize(
              horizontal: false, vertical: true)
            Text(.onboardingBody).foregroundStyle(Color.kvilSecondary).lineSpacing(4)
            Text(.onboardingSafety).font(.footnote).foregroundStyle(Color.kvilSecondary)
              .padding(.top, 2)
          }.padding(KvilStyle.page)
        }
      }.scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
          KvilBottomActions {
            Button(.findMyRhythm) { page = 1 }.buttonStyle(KvilPrimaryButtonStyle())
              .accessibilityIdentifier("beginSetup")
          }
        }
    }.background(Color.kvilCanvas)
  }

  private var rhythmPage: some View {
    KvilActionPage {
      KvilWordmark()
      pageHeading(.setupRhythmTitle, help: .setupRhythmHelp)
      VStack(spacing: KvilStyle.related) {
        ForEach(FastingRhythm.allCases) { option in
          Button {
            rhythm = option
            if let day = option.example {
              setWindow(day)
            }
          } label: {
            HStack(spacing: KvilStyle.content) {
              VStack(alignment: .leading, spacing: 5) {
                Text(option.title).font(.headline)
                Text(option.summary).font(.subheadline).foregroundStyle(Color.kvilSecondary)
                  .fixedSize(horizontal: false, vertical: true)
              }
              Spacer(minLength: 0)
              Image(systemName: rhythm == option ? "checkmark.circle.fill" : "circle")
                .font(.title3).foregroundStyle(Color.kvilAccent).accessibilityHidden(true)
            }.padding(KvilStyle.cardPadding).frame(maxWidth: .infinity, alignment: .leading)
              .background(Color.kvilSurface, in: RoundedRectangle(cornerRadius: KvilStyle.corner))
              .contentShape(RoundedRectangle(cornerRadius: KvilStyle.corner))
          }.buttonStyle(.plain)
            .accessibilityAddTraits(rhythm == option ? .isSelected : [])
            .accessibilityIdentifier("setupRhythm.\(option.rawValue)")
        }
      }
      Text(.setupRhythmFlexibleHelp).font(.footnote).foregroundStyle(Color.kvilSecondary)
        .fixedSize(horizontal: false, vertical: true)
      Button(.fastingGuide, systemImage: "book") { showingGuide = true }
        .frame(minHeight: 44).accessibilityIdentifier("setupGuide")
    } actions: {
      Button(.setupChooseMealTimes) { page = 2 }.buttonStyle(KvilPrimaryButtonStyle())
        .accessibilityIdentifier("chooseMealTimes")
      backButton(to: 0)
    }
  }

  private var mealTimesPage: some View {
    let day = DayPlan(weekday: 1, opens: opens, closes: closes)
    let shown = slidingWindow ?? day
    return KvilActionPage {
      KvilWordmark()
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
      Button(.setupPreviewWeek) { page = 3 }.buttonStyle(KvilPrimaryButtonStyle())
        .disabled(opens == closes).accessibilityIdentifier("previewSetup")
      backButton(to: 1)
    }
  }

  private var previewPage: some View {
    KvilActionPage {
      KvilWordmark()
      pageHeading(.setupWeekTitle, help: .setupWeekHelp)
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
      Text(.setupStorageHelp).font(.footnote).foregroundStyle(Color.kvilSecondary)
        .fixedSize(horizontal: false, vertical: true)
    } actions: {
      Button {
        Task { await finish() }
      } label: {
        if busy { ProgressView().tint(Color.kvilInverse) } else { Text(.makeSpace) }
      }.buttonStyle(KvilPrimaryButtonStyle()).disabled(busy).accessibilityIdentifier("finishSetup")
      backButton(to: 2).disabled(busy)
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

  private func backButton(to page: Int) -> some View {
    Button(.back) { self.page = page }.frame(maxWidth: .infinity, minHeight: 44)
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
    (0..<7).compactMap { model.calendar.date(byAdding: .day, value: $0, to: model.now) }
  }

  private func finish() async {
    busy = true
    defer { busy = false }
    guard model.configure(days: days) else { return }
    if enableReminders {
      await model.setReminder(opening: true, enabled: true)
      if model.data.preferences.openingReminder {
        await model.setReminder(opening: false, enabled: true)
      }
    }
  }
}
