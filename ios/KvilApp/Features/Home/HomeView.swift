import SwiftUI

struct HomeView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var actionFeedback = 0
  @State private var editingToday = false
  @State private var loggingWeight = false
  @State private var reflecting: Reflection?
  @State private var landscapeReveal: CGFloat = 0

  var body: some View {
    // Anchor ticks to whole clock seconds, independent of when Home appears.
    TimelineView(.periodic(from: Date(timeIntervalSinceReferenceDate: 0), by: 1)) { _ in
      let now = model.now
      let state = model.engine.state(at: now)
      let eligible = model.yesterdayReflection
      ViewThatFits(in: .vertical) {
        content(state: state, now: now, eligible: eligible, compact: false)
        content(state: state, now: now, eligible: eligible, compact: true)
      }
      .padding(.vertical, KvilStyle.content)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .backgroundPreferenceValue(HomeContentBoundsKey.self) { contentBounds in
        GeometryReader { safeGeometry in
          GeometryReader { geometry in
            let contentBottom =
              contentBounds.map { geometry[$0].maxY } ?? geometry.size.height * 0.55
            let spaceBelowContent = max(0, geometry.size.height - contentBottom)
            // The distant mist can sit behind controls; the foreground stays below them.
            let horizon = contentBottom - min(160, spaceBelowContent * 0.70)
            let boatTop = contentBottom - horizon + 12
            // Keep the boat above the tab bar, even when larger text leaves less water visible.
            let boatBottom = max(boatTop, safeGeometry.size.height - horizon - 12)
            HomeLandscapeView(
              isOpen: state?.isOpen == true || state?.isDayOff == true,
              isSelected: model.selectedTab == .home,
              presentationID: model.homePresentationID, boatArea: boatTop...boatBottom,
              reveal: $landscapeReveal
            )
            .frame(height: max(0, geometry.size.height - horizon))
            .frame(maxHeight: .infinity, alignment: .bottom)
          }
          .ignoresSafeArea(.container, edges: .bottom)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
      }
      .background(Color.kvilSky(daylight: Double(landscapeReveal)))
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
      .sheet(item: $reflecting) { ReflectionFlowView(reflection: $0) }
  }

  private func content(
    state: ScheduleState?, now: Date, eligible: Reflection?, compact: Bool
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
        if let state, !state.isDayOff {
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
      if let state, state.isDayOff {
        VStack(spacing: KvilStyle.content) {
          Image(systemName: "leaf").font(.system(size: compact ? 44 : 64, weight: .ultraLight))
            .foregroundStyle(Color.kvilAccent).accessibilityHidden(true)
          Text(.dayOff).font(KvilStyle.title)
          Text(.homeDayOffHelp).foregroundStyle(Color.kvilSecondary).multilineTextAlignment(.center)
          if let next = state.next {
            VStack(spacing: 4) {
              Text(.nextEatingWindow).font(.caption)
              Text(
                next.opening,
                format: .dateTime.weekday(.wide).month(.abbreviated).day().hour().minute()
              )
              .font(.subheadline).fixedSize(horizontal: false, vertical: true)
            }.multilineTextAlignment(.center).accessibilityElement(children: .combine)
          }
          Button(.schedule) { model.selectedTab = .schedule }.frame(minHeight: 44)
        }.padding(KvilStyle.page).accessibilityIdentifier("homeDayOff")
      } else if let state, let dayOff = state.upcomingDayOff {
        VStack(spacing: KvilStyle.content) {
          Image(systemName: "calendar").font(.system(size: compact ? 44 : 64, weight: .ultraLight))
            .foregroundStyle(Color.kvilAccent).accessibilityHidden(true)
          Text(.daysOffStart).font(KvilStyle.heading)
          Text(dayOff, format: .dateTime.weekday(.wide).month(.abbreviated).day())
            .font(KvilStyle.title).multilineTextAlignment(.center)
          if let next = state.next {
            VStack(spacing: 4) {
              Text(.nextEatingWindow)
              Text(
                next.opening,
                format: .dateTime.weekday(.wide).month(.abbreviated).day().hour().minute())
            }.font(.subheadline).foregroundStyle(Color.kvilSecondary)
              .multilineTextAlignment(.center).accessibilityElement(children: .combine)
          }
          Button(.schedule) { model.selectedTab = .schedule }.frame(minHeight: 44)
        }.padding(KvilStyle.page).accessibilityIdentifier("homeUpcomingDayOff")
      } else if let state {
        @Bindable var model = model
        HomeTimerView(
          state: state, now: now,
          highlightPending: $model.homeHighlightPending,
          isSelected: model.selectedTab == .home, compact: compact,
          clockIsPaused: model.fixedNow != nil, daylight: landscapeReveal)
        VStack(spacing: 10) {
          if !compact && !typeSize.isAccessibilitySize {
            Text(state.isOpen ? .makeRoom : .findYourRhythm)
              .font(KvilStyle.heading).multilineTextAlignment(.center)
              .foregroundStyle(Color.kvilInk)
          }
          if let active = state.active {
            WindowTimeLabel(window: active, stacksForAccessibility: !compact)
              .font(compact ? .caption : .body)
          } else if let next = state.next {
            let layout =
              typeSize.isAccessibilitySize
              ? AnyLayout(VStackLayout(spacing: 5)) : AnyLayout(HStackLayout(spacing: 5))
            layout {
              Text(
                Calendar.current.isDate(next.opening, inSameDayAs: now)
                  ? (compact ? .opensTodayCompact : .opensToday)
                  : (compact ? .opensTomorrowCompact : .opensTomorrow))
              Text(next.opening, format: .dateTime.hour().minute()).fontWeight(.medium)
            }.font(compact ? .caption : .subheadline).multilineTextAlignment(.center)
          }
        }.foregroundStyle(Color.kvilSecondary)
          .id(state.isOpen).transition(.opacity)
          .padding(.top, compact ? 8 : 4).padding(.horizontal, KvilStyle.page)
        HStack(spacing: 10) {
          Button {
            if model.setEatingWindowOpen(!state.isOpen) { actionFeedback += 1 }
          } label: {
            Label {
              Text(state.isOpen ? .startFastNow : .breakFastEarly)
                .fixedSize(horizontal: false, vertical: true)
            } icon: {
              if !typeSize.isAccessibilitySize {
                Image(systemName: state.isOpen ? "leaf" : "fork.knife")
              }
            }
            .font((compact ? Font.caption : .subheadline).weight(.medium))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 22).padding(.vertical, compact ? 0 : 13)
            .frame(minHeight: 44)
          }.accessibilityIdentifier("fastingAction")
          let canUndoStart = model.engine.earlyStart(at: now) != nil
          if canUndoStart || model.engine.earlyBreak(at: now) != nil {
            Button {
              if canUndoStart ? model.undoEarlyStart() : model.undoEarlyBreak() {
                actionFeedback += 1
              }
            } label: {
              Image(systemName: "arrow.uturn.backward")
                .font(.system(size: 17, weight: .medium)).frame(width: 44, height: 44)
            }.accessibilityLabel(canUndoStart ? .undoEarlyStart : .undoEarlyBreak)
              .accessibilityIdentifier(canUndoStart ? "undoEarlyStart" : "undoEarlyBreak")
          }
        }.buttonStyle(KvilWindowActionButtonStyle()).padding(.top, compact ? 4 : 22)
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
        Button {
          reflecting = eligible
        } label: {
          Label {
            Text(.howDidYesterdayGo).fixedSize(horizontal: false, vertical: true)
          } icon: {
            if !typeSize.isAccessibilitySize { Image(systemName: "text.bubble") }
          }
            .font((compact ? Font.caption : .subheadline).weight(.medium))
            .multilineTextAlignment(.center)
            .padding(.horizontal, KvilStyle.content).padding(.vertical, 12)
            .frame(minHeight: 44).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier("openReflection")
          .padding(.horizontal, KvilStyle.page).padding(.top, compact ? 8 : 20)
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
