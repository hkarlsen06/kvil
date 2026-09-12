import SwiftUI

struct HomeView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dynamicTypeSize) private var typeSize
  @State private var editingToday = false
  var body: some View {
    TimelineView(.periodic(from: .now, by: 30)) { context in
      let now = model.fixedNow ?? context.date
      let state = model.engine.state(at: now)
      ScrollView {
        VStack(spacing: 0) {
          Text(now, format: .dateTime.weekday(.wide).month(.wide).day())
            .font(typeSize.isAccessibilitySize ? .caption : .subheadline).foregroundStyle(
              Color.kvilSecondary
            ).multilineTextAlignment(.center).padding(.horizontal, 24).padding(.top, 18).padding(
              .bottom, 26)
          if let state {
            timer(state: state, now: now)
            VStack(spacing: 10) {
              if !typeSize.isAccessibilitySize {
                Text(state.isOpen ? L10n.makeRoom : L10n.findYourRhythm)
                  .font(KvilStyle.heading).multilineTextAlignment(.center)
              }
              if let active = state.active {
                WindowTimeLabel(window: active).foregroundStyle(Color.kvilSecondary)
              } else {
                let layout =
                  typeSize.isAccessibilitySize
                  ? AnyLayout(VStackLayout(spacing: 5)) : AnyLayout(HStackLayout(spacing: 5))
                layout {
                  Text(
                    Calendar.current.isDate(state.next.opening, inSameDayAs: now)
                      ? L10n.opensToday : L10n.opensTomorrow)
                  Text(state.next.opening, format: .dateTime.hour().minute()).fontWeight(.medium)
                }.font(.subheadline).foregroundStyle(Color.kvilSecondary).multilineTextAlignment(
                  .center)
              }
            }.padding(.top, 4).padding(.horizontal, KvilStyle.page)
            Button {
              editingToday = true
            } label: {
              Label(L10n.changeToday, systemImage: "slider.horizontal.3").font(
                .subheadline.weight(.medium)
              ).padding(.horizontal, 22).padding(.vertical, 13)
            }.buttonStyle(.plain).background(Color.kvilSurface, in: Capsule()).padding(.top, 22)
              .accessibilityIdentifier("changeToday")
          } else {
            ContentUnavailableView {
              Label(L10n.scheduleUnavailable, systemImage: "calendar")
            } description: {
              Text(L10n.scheduleUnavailableBody)
            }
            Button(L10n.schedule) { model.selectedTab = 1 }.buttonStyle(.bordered)
          }
          let eligible = model.engine.eligibleReflections(at: now).first { w in
            !model.data.reflections.contains {
              $0.dayKey == w.dayKey && $0.timeZoneID == w.timeZoneID
            }
          }
          if let eligible {
            ReflectionPrompt(window: eligible).padding(.horizontal, KvilStyle.page).padding(
              .top, 28)
          }
          LandscapeView(height: eligible == nil ? 240 : 170).padding(.top, 16)
        }
      }.scrollIndicators(.hidden).background(Color.kvilCanvas)
    }.toolbar {
      ToolbarItem(placement: .topBarLeading) { KvilWordmark().fixedSize() }
        .sharedBackgroundVisibility(.hidden)
      ToolbarItem(placement: .topBarTrailing) { SettingsLink() }
    }.navigationBarTitleDisplayMode(.inline)
      .sheet(isPresented: $editingToday) { ScheduleEditor(mode: .today) }
  }
  @ViewBuilder private func timer(state: ScheduleState, now: Date) -> some View {
    if typeSize.isAccessibilitySize {
      timerContent(state: state, now: now).padding(24)
    } else {
      ZStack {
        OpenArc().stroke(Color.kvilTrack, style: StrokeStyle(lineWidth: 8, lineCap: .round))
        OpenArc(progress: state.progress).stroke(
          Color.kvilAccent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
        timerContent(state: state, now: now)
        Text(state.isOpen ? L10n.yourWindow : L10n.atYourPace).font(.caption).tracking(1.1)
          .foregroundStyle(Color.kvilSecondary).offset(y: 118)
      }.frame(width: 272, height: 272).padding(.horizontal, 18).padding(.bottom, 4)
    }
  }
  private func timerContent(state: ScheduleState, now: Date) -> some View {
    VStack(spacing: 12) {
      Image(systemName: state.isOpen ? "sun.max" : "leaf").font(.title3.weight(.light))
        .foregroundStyle(Color.kvilAccent).accessibilityHidden(true)
      if state.isOpen {
        Text(L10n.windowOpen).font(.system(.largeTitle, design: .serif)).multilineTextAlignment(
          .center)
      } else {
        Text(
          Duration.seconds(max(0, state.next.opening.timeIntervalSince(now))),
          format: .time(pattern: .hourMinute)
        )
        .font(
          typeSize.isAccessibilitySize
            ? .system(.largeTitle, design: .rounded, weight: .light)
            : .system(size: 60, weight: .light, design: .rounded)
        ).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
        .accessibilityLabel(L10n.untilEatingWindow).accessibilityValue(
          Text(state.next.opening, style: .relative))
        Text(L10n.untilEatingWindow).font(.subheadline).foregroundStyle(Color.kvilSecondary)
      }
    }.frame(maxWidth: .infinity).accessibilityElement(children: .combine)
  }
}

struct ReflectionPrompt: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dynamicTypeSize) private var typeSize
  var window: EatingWindow
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 5) {
          Text(
            Calendar.current.isDate(window.opening, inSameDayAs: model.now)
              ? L10n.howToday : L10n.howYesterday
          ).font(KvilStyle.heading)
          Text(L10n.reflectionHelp).font(.footnote).foregroundStyle(Color.kvilSecondary)
        }
        Spacer(minLength: 8)
        Button {
          model.reflect(window, feeling: nil)
        } label: {
          Image(systemName: "xmark").frame(width: 44, height: 44)
        }
        .buttonStyle(.plain).accessibilityLabel(L10n.dismissReflection)
      }
      if typeSize.isAccessibilitySize {
        VStack(alignment: .leading, spacing: 8) { feelingButtons }
      } else {
        HStack(spacing: 8) { feelingButtons }
      }
    }.padding(20).background(
      Color.kvilSurface, in: RoundedRectangle(cornerRadius: KvilStyle.corner))
  }
  @ViewBuilder var feelingButtons: some View {
    ForEach(DayFeeling.allCases, id: \.self) { feeling in
      Button {
        model.reflect(window, feeling: feeling)
      } label: {
        VStack(spacing: 8) {
          Image(systemName: feeling.symbol).font(.title3)
          Text(feeling.title).font(.caption)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10).padding(.horizontal, 4)
      }.buttonStyle(.plain).accessibilityIdentifier("feeling.\(feeling.rawValue)")
    }
  }
}
