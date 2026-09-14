import SwiftUI

struct HomeView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var actionFeedback = 0
  @State private var editingToday = false
  @State private var loggingWeight = false
  @State private var reflecting: EatingWindow?

  var body: some View {
    // Anchor ticks to whole clock seconds, independent of when Home appears.
    TimelineView(.periodic(from: Date(timeIntervalSinceReferenceDate: 0), by: 1)) { _ in
      let now = model.now
      let state = model.engine.state(at: now)
      let eligible = model.engine.eligibleReflections(at: now).first { window in
        !model.data.reflections.contains {
          $0.dayKey == window.dayKey && $0.timeZoneID == window.timeZoneID
        }
      }
      ViewThatFits(in: .vertical) {
        content(state: state, now: now, eligible: eligible, compact: false)
        content(state: state, now: now, eligible: eligible, compact: true)
      }
      .padding(.vertical, KvilStyle.content)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .backgroundPreferenceValue(HomeContentBoundsKey.self) { contentBounds in
        GeometryReader { geometry in
          let contentBottom =
            contentBounds.map { geometry[$0].maxY } ?? geometry.size.height * 0.55
          let spaceBelowContent = max(0, geometry.size.height - contentBottom)
          // The distant mist can sit behind controls; the foreground stays below them.
          let horizon = contentBottom - min(160, spaceBelowContent * 0.70)
          KvilLandscapeBackground()
            .frame(height: max(0, geometry.size.height - horizon))
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
      }
      .background(Color.kvilCanvas)
      .animation(KvilMotion.transition(reduceMotion: reduceMotion), value: state?.isOpen)
    }.toolbar {
      ToolbarItem(placement: .topBarLeading) { KvilWordmark().fixedSize() }
        .sharedBackgroundVisibility(.hidden)
      if model.data.preferences.weightEnabled {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            loggingWeight = true
          } label: {
            Label(.logWeight, systemImage: "scalemass")
          }.labelStyle(.iconOnly).accessibilityIdentifier("logWeight")
        }
      }
    }.navigationBarTitleDisplayMode(.inline)
      .sheet(isPresented: $editingToday) { ScheduleEditor() }
      .sheet(isPresented: $loggingWeight) { WeightEditor() }
      .sheet(item: $reflecting) { window in
        NavigationStack {
          ScrollView {
            ReflectionPrompt(window: window).padding(KvilStyle.page)
          }.background(Color.kvilCanvas)
            .navigationTitle(.yourReflections).navigationBarTitleDisplayMode(.inline)
            .toolbar {
              ToolbarItem(placement: .confirmationAction) {
                Button(.done) { reflecting = nil }
              }
            }
        }.modifier(AppMessageModifier())
          .onChange(of: model.data.reflections) { _, reflections in
            if reflections.contains(where: {
              $0.dayKey == window.dayKey && $0.timeZoneID == window.timeZoneID
            }) {
              reflecting = nil
            }
          }
      }
  }

  private func content(
    state: ScheduleState?, now: Date, eligible: EatingWindow?, compact: Bool
  ) -> some View {
    VStack(spacing: 0) {
      Text(
        now,
        format: compact
          ? .dateTime.month(.abbreviated).day()
          : .dateTime.weekday(.wide).month(.wide).day()
      )
      .font(typeSize.isAccessibilitySize ? .caption : .subheadline)
      .multilineTextAlignment(.center)
      .fixedSize(horizontal: false, vertical: true)
      .accessibilityIdentifier("homeDate")
      .overlay(alignment: .trailing) {
        if state != nil {
          Button {
            editingToday = true
          } label: {
            Image(systemName: "pencil").font(.subheadline)
              .padding(.leading, 4)
              .frame(width: 44, height: 44, alignment: .leading)
              .contentShape(Rectangle())
          }.buttonStyle(.plain).accessibilityLabel(.changeToday)
            .accessibilityIdentifier("changeToday").offset(x: 44)
        }
      }
      .foregroundStyle(Color.kvilSecondary)
      .padding(.horizontal, KvilStyle.page + 44)
      .padding(.bottom, compact ? 8 : 26)
      if let state {
        @Bindable var model = model
        HomeTimerView(
          state: state, now: now,
          highlightPending: $model.homeHighlightPending,
          isSelected: model.selectedTab == .home, compact: compact,
          clockIsPaused: model.fixedNow != nil)
        VStack(spacing: 10) {
          if !compact && !typeSize.isAccessibilitySize {
            Text(state.isOpen ? .makeRoom : .findYourRhythm)
              .font(KvilStyle.heading).multilineTextAlignment(.center)
              .foregroundStyle(Color.kvilInk)
          }
          if let active = state.active {
            WindowTimeLabel(window: active, stacksForAccessibility: !compact)
              .font(compact ? .caption : .body)
          } else {
            let layout =
              typeSize.isAccessibilitySize
              ? AnyLayout(VStackLayout(spacing: 5)) : AnyLayout(HStackLayout(spacing: 5))
            layout {
              Text(
                Calendar.current.isDate(state.next.opening, inSameDayAs: now)
                  ? (compact ? .opensTodayCompact : .opensToday)
                  : (compact ? .opensTomorrowCompact : .opensTomorrow))
              Text(state.next.opening, format: .dateTime.hour().minute()).fontWeight(.medium)
            }.font(compact ? .caption : .subheadline).multilineTextAlignment(.center)
          }
        }.foregroundStyle(Color.kvilSecondary)
          .id(state.isOpen).transition(.opacity)
          .padding(.top, compact ? 8 : 4).padding(.horizontal, KvilStyle.page)
        HStack(spacing: 10) {
          Button {
            if model.setEatingWindowOpen(!state.isOpen) { actionFeedback += 1 }
          } label: {
            Label(
              state.isOpen ? .startFastNow : .breakFastEarly,
              systemImage: state.isOpen ? "leaf" : "fork.knife"
            )
            .font(.subheadline.weight(.medium)).multilineTextAlignment(.center)
            .padding(.horizontal, 22).padding(.vertical, 13)
          }.accessibilityIdentifier("fastingAction")
          if model.engine.earlyBreak(at: now) != nil {
            Button {
              if model.undoEarlyBreak() { actionFeedback += 1 }
            } label: {
              Image(systemName: "arrow.uturn.backward")
                .font(.system(size: 17, weight: .medium)).frame(width: 44, height: 44)
            }.accessibilityLabel(.undoEarlyBreak).accessibilityIdentifier("undoEarlyBreak")
          }
        }.buttonStyle(KvilWindowActionButtonStyle()).padding(.top, compact ? 16 : 22)
          .sensoryFeedback(.impact(weight: .light, intensity: 0.5), trigger: actionFeedback)
          .padding(.horizontal, KvilStyle.page)
      } else {
        ContentUnavailableView {
          Label(.scheduleUnavailable, systemImage: "calendar")
        } description: {
          Text(.scheduleUnavailableBody)
        }
        Button(.schedule) { model.selectedTab = .schedule }.buttonStyle(.bordered)
      }
      if let eligible {
        Group {
          if compact {
            Button {
              reflecting = eligible
            } label: {
              Label(.reflectOnDay, systemImage: "text.bubble")
                .font(.caption.weight(.medium)).multilineTextAlignment(.center).frame(minHeight: 44)
            }.buttonStyle(.plain).accessibilityIdentifier("openReflection")
              .accessibilityHint(
                Text(
                  Calendar.current.isDate(eligible.opening, inSameDayAs: now)
                    ? .howToday : .howYesterday))
          } else {
            ReflectionPrompt(window: eligible)
          }
        }.padding(.horizontal, KvilStyle.page).padding(.top, compact ? 12 : 28)
      }
    }.fixedSize(horizontal: false, vertical: true)
      .accessibilityElement(children: .contain).accessibilityIdentifier("homeContent")
      .anchorPreference(key: HomeContentBoundsKey.self, value: .bounds) { $0 }
  }
}

private struct HomeContentBoundsKey: PreferenceKey {
  static var defaultValue: Anchor<CGRect>? { nil }

  static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
    value = nextValue() ?? value
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
              ? .howToday : .howYesterday
          ).font(KvilStyle.heading)
          Text(.reflectionHelp).font(.footnote).foregroundStyle(Color.kvilSecondary)
        }
        Spacer(minLength: 8)
        Button {
          model.reflect(window, feeling: nil)
        } label: {
          Image(systemName: "xmark").frame(width: 44, height: 44)
        }
        .buttonStyle(.plain).accessibilityLabel(.dismissReflection)
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
