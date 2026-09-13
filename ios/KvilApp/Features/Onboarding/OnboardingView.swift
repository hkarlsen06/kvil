import SwiftUI

struct OnboardingView: View {
  @Environment(AppModel.self) private var model
  @State private var page = 0
  @State private var opens = WallTime(hour: 10).date(on: Date(), calendar: .current) ?? Date()
  @State private var closes = WallTime(hour: 18).date(on: Date(), calendar: .current) ?? Date()
  @State private var enableReminders = true
  @State private var busy = false
  var body: some View {
    if page == 0 {
      welcomePage
    } else {
      setupPage
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
          Button(.findMyRhythm) { page = 1 }.buttonStyle(KvilPrimaryButtonStyle()).padding(
            .horizontal, KvilStyle.page
          ).accessibilityIdentifier("beginSetup")
          Spacer(minLength: KvilStyle.page)
        }.frame(minHeight: geometry.size.height, alignment: .top)
      }.scrollIndicators(.hidden)
    }.background(Color.kvilCanvas)
  }

  private var setupPage: some View {
    KvilActionPage {
      KvilWordmark()
      VStack(alignment: .leading, spacing: KvilStyle.content) {
        Text(.yourDailyWindow).font(KvilStyle.title)
          .fixedSize(horizontal: false, vertical: true)
        Text(.setupWindowHelp).foregroundStyle(Color.kvilSecondary)
      }
      VStack(spacing: KvilStyle.content) {
        KvilControlRow(title: .windowOpens) {
          DatePicker(.windowOpens, selection: $opens, displayedComponents: .hourAndMinute)
            .labelsHidden()
        }
        Divider()
        KvilControlRow(title: .windowCloses) {
          DatePicker(.windowCloses, selection: $closes, displayedComponents: .hourAndMinute)
            .labelsHidden()
        }
      }.padding(KvilStyle.cardPadding)
        .background(Color.kvilSurface, in: RoundedRectangle(cornerRadius: KvilStyle.corner))
      KvilDescribedToggle(
        title: .gentleReminders, description: .setupReminderHelp, isOn: $enableReminders)
      Text(.setupStorageHelp).font(.footnote).foregroundStyle(Color.kvilSecondary)
    } actions: {
      Button {
        Task { await finish() }
      } label: {
        if busy { ProgressView().tint(Color.kvilInverse) } else { Text(.makeSpace) }
      }.buttonStyle(KvilPrimaryButtonStyle()).disabled(busy).accessibilityIdentifier("finishSetup")
      Button(.back) { page = 0 }.frame(maxWidth: .infinity, minHeight: 44)
    }
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
