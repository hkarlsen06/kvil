import SwiftUI

struct ScheduleView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dynamicTypeSize) private var typeSize
  @State private var editor: ScheduleEditor.Mode?
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: KvilStyle.section) {
        if !typeSize.isAccessibilitySize {
          VStack(alignment: .leading, spacing: 8) {
            Text(L10n.aLittleStructure).font(KvilStyle.title)
            Text(L10n.scheduleIntro).foregroundStyle(Color.kvilSecondary)
          }
        }
        if let today = model.engine.window(on: model.now) {
          VStack(alignment: .leading, spacing: 14) {
            HStack {
              Label(L10n.today, systemImage: "sun.max")
              Spacer()
              if today.isOverride {
                Text(L10n.adjusted).font(.caption).foregroundStyle(Color.kvilSecondary)
              }
            }
            WindowTimeLabel(window: today).font(.title2).foregroundStyle(Color.kvilInk)
            Button(L10n.changeToday) { editor = .today }.font(.subheadline.weight(.medium))
          }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(
            Color.kvilSurface, in: RoundedRectangle(cornerRadius: KvilStyle.corner))
        }
        VStack(alignment: .leading, spacing: 12) {
          let headerLayout =
            typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout())
          headerLayout {
            Text(L10n.usualWeek).font(KvilStyle.heading).fixedSize(
              horizontal: false, vertical: true)
            if !typeSize.isAccessibilitySize { Spacer() }
            Button(L10n.edit) { editor = .week }.accessibilityIdentifier("editWeek")
          }
          let days =
            model.data.schedule.versions.max(by: { $0.effectiveDay < $1.effectiveDay })?.days
            ?? DayPlan.initial
          ForEach(ordered(days)) { day in
            let layout =
              typeSize.isAccessibilitySize
              ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout())
            layout {
              Text(weekday(day.weekday)).fontWeight(.medium).fixedSize(
                horizontal: false, vertical: true)
              if !typeSize.isAccessibilitySize { Spacer() }
              if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                  wallTime(day.opens)
                  wallTime(day.closes)
                }
              } else {
                HStack {
                  wallTime(day.opens)
                  Text(verbatim: "–")
                  wallTime(day.closes)
                }
              }
              if day.overnight { Text(L10n.nextDayShort).font(.caption2) }
            }.font(.subheadline).padding(.vertical, 13).accessibilityElement(children: .combine)
            if day.id != ordered(days).last?.id { Divider().overlay(Color.kvilLine) }
          }
          Text(L10n.weekEffectiveTomorrow).font(.footnote).foregroundStyle(Color.kvilSecondary)
        }
        Text(L10n.scheduleNoTracking).font(.footnote).foregroundStyle(Color.kvilSecondary)
      }.padding(KvilStyle.page)
    }.background(Color.kvilCanvas).navigationTitle(L10n.schedule).navigationBarTitleDisplayMode(
      .inline
    )
    .toolbar { ToolbarItem(placement: .topBarTrailing) { SettingsLink() } }
    .sheet(item: $editor) { ScheduleEditor(mode: $0) }
  }
  private func wallTime(_ time: WallTime) -> some View {
    Text(
      time.date(on: model.now, calendar: model.calendar) ?? model.now,
      format: .dateTime.hour().minute()
    ).monospacedDigit().fixedSize()
  }
  private func weekday(_ value: Int) -> String { model.calendar.weekdaySymbols[value - 1] }
  private func ordered(_ days: [DayPlan]) -> [DayPlan] {
    days.sorted {
      ($0.weekday - Calendar.current.firstWeekday + 7) % 7
        < ($1.weekday - Calendar.current.firstWeekday + 7) % 7
    }
  }
}

struct ScheduleEditor: View {
  enum Mode: String, Identifiable {
    case today, week
    var id: String { rawValue }
  }
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  let mode: Mode
  @State private var days = DayPlan.initial
  @State private var selectedDay = Calendar.current.component(.weekday, from: Date())
  @State private var opens = Date()
  @State private var closes = Date()
  @State private var ready = false
  @State private var validation: String?

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Text(mode == .today ? L10n.todayEditorIntro : L10n.weekEditorIntro).foregroundStyle(
            Color.kvilSecondary)
        }.listRowBackground(Color.clear)
        if mode == .week {
          Section(L10n.chooseDay) {
            Picker(L10n.weekday, selection: $selectedDay) {
              ForEach(1...7, id: \.self) { value in
                Text(model.calendar.weekdaySymbols[value - 1]).tag(value)
              }
            }.pickerStyle(.menu)
          }
        }
        Section {
          DatePicker(L10n.windowOpens, selection: $opens, displayedComponents: .hourAndMinute)
            .accessibilityIdentifier("openingTime")
          DatePicker(L10n.windowCloses, selection: $closes, displayedComponents: .hourAndMinute)
            .accessibilityIdentifier("closingTime")
          if wall(closes) < wall(opens) {
            Label(L10n.closesNextDay, systemImage: "moon").font(.footnote).foregroundStyle(
              Color.kvilSecondary)
          }
        }
        if mode == .week {
          Section {
            Button(L10n.applyAllDays) {
              days = (1...7).map { DayPlan(weekday: $0, opens: wall(opens), closes: wall(closes)) }
            }
          } footer: {
            Text(L10n.weekEffectiveTomorrow)
          }
        }
        if let validation {
          Section {
            Text(validation).foregroundStyle(Color.kvilWarning).accessibilityIdentifier(
              "scheduleValidation")
          }
        }
        if mode == .today, model.engine.window(on: model.now)?.isOverride == true {
          Section {
            Button(L10n.useUsualSchedule) {
              if model.removeTodayOverride() {
                dismiss()
              } else {
                validation = model.message
                model.message = nil
              }
            }
          }
        }
      }.scrollContentBackground(.hidden).background(Color.kvilCanvas)
        .navigationTitle(mode == .today ? L10n.changeToday : L10n.editWeek)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button(L10n.cancel) { dismiss() } }
          ToolbarItem(placement: .confirmationAction) {
            Button(L10n.save) { save() }.fontWeight(.semibold).accessibilityIdentifier(
              "saveSchedule")
          }
        }
        .onAppear { load() }
        .onChange(of: selectedDay) { old, new in
          guard ready else { return }
          stash(day: old)
          setTimes(day: new)
        }
    }.tint(Color.kvilAccent)
  }
  private func wall(_ date: Date) -> WallTime {
    WallTime(
      hour: model.calendar.component(.hour, from: date),
      minute: model.calendar.component(.minute, from: date))
  }
  private func load() {
    days =
      model.data.schedule.versions.max(by: { $0.effectiveDay < $1.effectiveDay })?.days
      ?? DayPlan.initial
    selectedDay = model.calendar.component(.weekday, from: model.now)
    if mode == .today, let w = model.engine.window(on: model.now) {
      opens = w.opening
      closes = w.closing
    } else {
      setTimes(day: selectedDay)
    }
    ready = true
  }
  private func setTimes(day: Int) {
    if let plan = days.first(where: { $0.weekday == day }) {
      opens = plan.opens.date(on: model.now, calendar: model.calendar) ?? model.now
      closes = plan.closes.date(on: model.now, calendar: model.calendar) ?? model.now
    }
  }
  private func stash(day: Int) {
    if let index = days.firstIndex(where: { $0.weekday == day }) {
      days[index].opens = wall(opens)
      days[index].closes = wall(closes)
    }
  }
  private func save() {
    stash(day: selectedDay)
    if mode == .today
      ? model.saveToday(opens: wall(opens), closes: wall(closes)) : model.saveWeek(days)
    {
      dismiss()
    } else {
      validation = model.message
      model.message = nil
    }
  }
}
