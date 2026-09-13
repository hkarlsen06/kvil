import SwiftUI

struct OnboardingView: View {
  @Environment(AppModel.self) private var model
  @State private var page = 0
  @State private var opens = WallTime(hour: 10).date(on: Date(), calendar: .current) ?? Date()
  @State private var closes = WallTime(hour: 18).date(on: Date(), calendar: .current) ?? Date()
  @State private var enableReminders = true
  @State private var busy = false
  var body: some View {
    GeometryReader { geometry in
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          KvilWordmark().padding(.horizontal, 28).padding(.top, 28)
          if page == 0 {
            OnboardingLandscapeView(
              height: max(210, geometry.size.height * 0.37)
            ).padding(.top, 24)
            VStack(alignment: .leading, spacing: 16) {
              Text(L10n.onboardingTitle).font(.system(.largeTitle, design: .serif)).fixedSize(
                horizontal: false, vertical: true)
              Text(L10n.onboardingBody).foregroundStyle(Color.kvilSecondary).lineSpacing(4)
              Text(L10n.onboardingSafety).font(.footnote).foregroundStyle(Color.kvilSecondary)
                .padding(.top, 2)
            }.padding(28)
            Button(L10n.findMyRhythm) { page = 1 }.buttonStyle(KvilPrimaryButtonStyle()).padding(
              .horizontal, 28
            ).accessibilityIdentifier("beginSetup")
          } else {
            VStack(alignment: .leading, spacing: 24) {
              Text(L10n.yourDailyWindow).font(KvilStyle.title)
              Text(L10n.setupWindowHelp).foregroundStyle(Color.kvilSecondary)
              VStack(spacing: 18) {
                DatePicker(L10n.windowOpens, selection: $opens, displayedComponents: .hourAndMinute)
                Divider()
                DatePicker(
                  L10n.windowCloses, selection: $closes, displayedComponents: .hourAndMinute)
              }.padding(20).background(Color.kvilSurface, in: RoundedRectangle(cornerRadius: 24))
              Toggle(L10n.gentleReminders, isOn: $enableReminders)
              Text(L10n.setupReminderHelp).font(.footnote).foregroundStyle(Color.kvilSecondary)
              Text(L10n.localStorageNotice).font(.footnote).foregroundStyle(Color.kvilSecondary)
              Button {
                Task { await finish() }
              } label: {
                if busy { ProgressView().tint(Color.kvilInverse) } else { Text(L10n.makeSpace) }
              }.buttonStyle(KvilPrimaryButtonStyle()).disabled(busy).accessibilityIdentifier(
                "finishSetup")
              Button(L10n.back) { page = 0 }.frame(maxWidth: .infinity, minHeight: 44)
            }.padding(28)
          }
          Spacer(minLength: 24)
        }.frame(minHeight: geometry.size.height, alignment: .top)
      }.scrollIndicators(.hidden)
    }.background(Color.kvilCanvas)
  }
  private func finish() async {
    busy = true
    defer { busy = false }
    let c = model.calendar
    let opening = WallTime(
      hour: c.component(.hour, from: opens), minute: c.component(.minute, from: opens))
    let closing = WallTime(
      hour: c.component(.hour, from: closes), minute: c.component(.minute, from: closes))
    let days = (1...7).map { DayPlan(weekday: $0, opens: opening, closes: closing) }
    guard model.configure(days: days) else { return }
    if enableReminders {
      await model.setReminder(opening: true, enabled: true)
      if model.data.preferences.openingReminder {
        await model.setReminder(opening: false, enabled: true)
      }
    }
  }
}
