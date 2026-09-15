import SwiftUI

struct ScheduleView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.locale) private var locale
  @Environment(\.dynamicTypeSize) private var typeSize
  @State private var editingToday = false
  @State private var planningBreak = false
  @State private var editingDay: DayPlan?
  @State private var slidingDay: DayPlan?
  @State private var slidingToday: DayPlan?
  @State private var todayDragOrigin: EatingWindow?
  @State private var copiedTimes: (opens: WallTime, closes: WallTime)?
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: KvilStyle.section) {
        if model.engine.isDayOff(on: model.now) {
          dayOffCard
        } else if let today = model.engine.window(on: model.now) {
          todayCard(today)
        }
        breaksSection
        usualWeek
        Text(.scheduleNoTracking).font(.footnote).foregroundStyle(Color.kvilSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }.padding(KvilStyle.page).frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
    }.background(Color.kvilCanvas).navigationTitle(.schedule).navigationBarTitleDisplayMode(
      .inline
    )
    .toolbar { ToolbarItem(placement: .topBarTrailing) { SettingsLink() } }
    .sheet(isPresented: $editingToday) { ScheduleEditor() }
    .sheet(item: $editingDay) { ScheduleEditor(day: $0) }
    .sheet(isPresented: $planningBreak) { ScheduleBreakEditor() }
  }

  private func todayCard(_ today: EatingWindow) -> some View {
    let day = DayPlan(
      weekday: model.calendar.component(.weekday, from: model.now),
      opens: wall(today.opening), closes: wall(today.closing))
    let shown = slidingToday ?? day
    return VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text(.today).font(KvilStyle.heading)
          Spacer(minLength: 12)
          Menu {
            windowLengthPicker(selected: day.windowMinutes) { minutes in
              if let updated = try? day.resized(to: minutes) {
                saveToday(updated, replacing: today)
              }
            }
            Button(.editWindowTimes, systemImage: "clock") { editingToday = true }
            Button(.takeTodayOff, systemImage: "sun.max") { model.takeTodayOff() }
            if today.isOverride {
              Button(.useUsualSchedule, systemImage: "arrow.uturn.backward") {
                _ = model.removeTodayOverride()
              }
            }
          } label: {
            Image(systemName: "ellipsis").font(.system(size: 17, weight: .medium))
              .frame(width: 44, height: 44)
              .background(Color.kvilCanvas, in: Circle())
          }.buttonStyle(.plain).foregroundStyle(Color.kvilAccent)
            .accessibilityLabel(.changeToday)
            .accessibilityIdentifier("todayMenu")
        }
        Label(.adjusted, systemImage: "slider.horizontal.3")
          .font(.caption).foregroundStyle(Color.kvilSecondary)
          .opacity(today.isOverride ? 1 : 0).accessibilityHidden(!today.isOverride)
      }
      VStack(alignment: .leading, spacing: 4) {
        Group {
          if typeSize.isAccessibilitySize {
            stackedTodayTimes(shown)
          } else {
            ViewThatFits(in: .horizontal) {
              HStack(alignment: .top, spacing: 4) {
                todayTime(shown.opens, title: .windowOpens)
                Spacer(minLength: 0)
                Image(systemName: "arrow.right").font(.subheadline)
                  .foregroundStyle(Color.kvilSecondary).padding(.top, 32)
                  .accessibilityHidden(true)
                Spacer(minLength: 0)
                todayTime(shown.closes, title: .windowCloses)
              }
              stackedTodayTimes(shown)
            }
          }
        }
        Text(.closesNextDay).font(.caption).foregroundStyle(Color.kvilSecondary)
          .fixedSize(horizontal: false, vertical: true)
          .opacity(shown.overnight ? 1 : 0).accessibilityHidden(!shown.overnight)
      }.accessibilityElement(children: .combine)
        .accessibilityIdentifier("todayWindow")
      VStack(alignment: .leading, spacing: 10) {
        KvilWindowSlider(
          day: day, title: String(localized: .today), value: windowSummary(shown),
          onMove: { _, updated in saveToday(updated, replacing: todayDragOrigin ?? today) },
          onEdit: { editingToday = true },
          onPreview: { preview in
            if preview != nil && todayDragOrigin == nil { todayDragOrigin = today }
            slidingToday = preview
            if preview == nil { todayDragOrigin = nil }
          }
        ).accessibilityIdentifier("todayWindowSlider")
        KvilDayAxis()
      }
      Text(.todayOnlyChanges).font(.footnote).foregroundStyle(Color.kvilSecondary)
        .fixedSize(horizontal: false, vertical: true)
    }.padding(KvilStyle.cardPadding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.kvilSurface, in: RoundedRectangle(cornerRadius: KvilStyle.corner))
  }

  private var dayOffCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(.today).font(KvilStyle.heading)
      Label(.dayOff, systemImage: "sun.max").font(.title3)
        .accessibilityIdentifier("scheduleDayOff")
      Text(.dayOffDescription).font(.subheadline).foregroundStyle(Color.kvilSecondary)
        .fixedSize(horizontal: false, vertical: true)
      if model.upcomingScheduleBreaks.contains(where: {
        $0.contains(LocalDay.key(model.now, calendar: model.calendar))
      }) {
        Button(.resumeScheduleToday) { model.resumeSchedule() }
          .frame(minHeight: 44)
          .accessibilityIdentifier("resumeScheduleToday")
      }
    }.padding(KvilStyle.cardPadding).frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.kvilSurface, in: RoundedRectangle(cornerRadius: KvilStyle.corner))
  }

  private var breaksSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      ForEach(model.upcomingScheduleBreaks) { item in
        if let starts = LocalDay.date(item.startDay, calendar: model.calendar),
          let resumes = LocalDay.date(item.resumeDay, calendar: model.calendar)
        {
          HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
              Label(.plannedBreak, systemImage: "calendar")
                .font(.subheadline.weight(.medium))
              if !item.contains(LocalDay.key(model.now, calendar: model.calendar)) {
                LabeledContent(.breakStarts) {
                  Text(starts, format: .dateTime.day().month(.abbreviated))
                }
              }
              LabeledContent(.scheduleResumes) {
                Text(resumes, format: .dateTime.day().month(.abbreviated))
              }
            }.font(.footnote).foregroundStyle(Color.kvilSecondary)
            Menu {
              Button(
                item.contains(LocalDay.key(model.now, calendar: model.calendar))
                  ? LocalizedStringResource.resumeScheduleToday : .cancelScheduleBreak,
                systemImage: "arrow.uturn.backward"
              ) { model.endScheduleBreak(item) }
            } label: {
              Image(systemName: "ellipsis").frame(width: 44, height: 44)
            }.accessibilityLabel(.scheduleBreakOptions)
          }.padding(KvilStyle.cardPadding)
            .background(Color.kvilSurface, in: RoundedRectangle(cornerRadius: KvilStyle.corner))
        }
      }
      Button(.planScheduleBreak, systemImage: "calendar.badge.plus") { planningBreak = true }
        .accessibilityIdentifier("planScheduleBreak")
    }
  }

  private func saveToday(_ day: DayPlan, replacing original: EatingWindow) {
    guard day.opens != wall(original.opening) || day.closes != wall(original.closing) else {
      return
    }
    _ = model.saveToday(opens: day.opens, closes: day.closes, replacing: original)
  }

  private func stackedTodayTimes(_ today: DayPlan) -> some View {
    VStack(alignment: .leading, spacing: 20) {
      todayTime(today.opens, title: .windowOpens)
      todayTime(today.closes, title: .windowCloses)
    }
  }

  private func todayTime(_ time: WallTime, title: LocalizedStringResource) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title).font(.subheadline).foregroundStyle(Color.kvilSecondary)
      ZStack(alignment: .leading) {
        // Reserve two-digit hours in both periods, so dragging cannot switch the time layout.
        Text(verbatim: wallTimeString(WallTime(hour: 10))).hidden().accessibilityHidden(true)
        Text(verbatim: wallTimeString(WallTime(hour: 22))).hidden().accessibilityHidden(true)
        Text(verbatim: wallTimeString(time))
      }.font(.system(.title, design: .serif)).monospacedDigit().fixedSize()
    }
  }

  private var usualWeek: some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text(.usualWeek).font(KvilStyle.heading)
            .fixedSize(horizontal: false, vertical: true)
          Spacer(minLength: 8)
          Menu {
            lengthPicker()
          } label: {
            Image(systemName: "slider.horizontal.3").font(.system(size: 17))
              .frame(width: 44, height: 44).contentShape(Rectangle())
          }.accessibilityLabel(.weekOptions).accessibilityIdentifier("weekOptions")
        }
        Text(.dragWindowHelp).font(.subheadline).foregroundStyle(Color.kvilSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      VStack(alignment: .leading, spacing: 0) {
        Label {
          Text(.eatingWindow).fixedSize(horizontal: false, vertical: true)
        } icon: {
          Capsule().fill(Color.kvilAccent).frame(width: 16, height: 6)
        }.font(.caption).foregroundStyle(Color.kvilSecondary).padding(.bottom, 16)
        KvilDayAxis().padding(.bottom, 8)
        let days = ordered(model.usualDays)
        ForEach(days) { day in
          weekRow(day)
          if day.id != days.last?.id { Divider().overlay(Color.kvilLine) }
        }
      }.padding(KvilStyle.cardPadding)
        .background(Color.kvilSurface, in: RoundedRectangle(cornerRadius: KvilStyle.corner))
      Text(.weekEffectiveTomorrow).font(.footnote).foregroundStyle(Color.kvilSecondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private func weekRow(_ day: DayPlan) -> some View {
    let shown = slidingDay?.weekday == day.weekday ? slidingDay ?? day : day
    return VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .top, spacing: 8) {
        let title = Text(weekday(day.weekday)).font(.subheadline.weight(.medium))
          .fixedSize(horizontal: !typeSize.isAccessibilitySize, vertical: true)
        let times = VStack(alignment: .leading, spacing: 4) {
          if shown.isDayOff {
            Text(.dayOff)
          } else if typeSize.isAccessibilitySize {
            stackedTimes(shown)
          } else {
            HStack(spacing: 3) {
              wallTime(shown.opens)
              Text(verbatim: "–")
              wallTime(shown.closes)
            }.fixedSize()
          }
          if !shown.isDayOff && shown.overnight { Text(.nextDayShort).font(.caption) }
        }.font(.footnote).foregroundStyle(Color.kvilSecondary)
        Group {
          if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
              title
              times
            }
          } else {
            ViewThatFits(in: .horizontal) {
              HStack(spacing: 8) {
                title
                Spacer(minLength: 0)
                times
              }
              VStack(alignment: .leading, spacing: 4) {
                title
                times
              }
            }
          }
        }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
          .accessibilityElement(children: .combine)
          .accessibilityIdentifier("dayTimes.\(day.weekday)")
        dayMenu(day)
      }
      if !day.isDayOff {
        KvilWindowSlider(
          day: day, title: weekday(day.weekday), value: windowSummary(shown),
          onMove: { original, updated in _ = model.saveWeekDay(updated, replacing: original) },
          onEdit: { editingDay = day }, onPreview: { slidingDay = $0 }
        ).accessibilityIdentifier("windowSlider.\(day.weekday)")
      }
    }.padding(.vertical, 8)
  }

  private func stackedTimes(_ day: DayPlan) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      wallTime(day.opens)
      Text(verbatim: "–")
      wallTime(day.closes)
    }
  }

  private func wall(_ date: Date) -> WallTime {
    WallTime(
      hour: model.calendar.component(.hour, from: date),
      minute: model.calendar.component(.minute, from: date))
  }
  private func dayMenu(_ day: DayPlan) -> some View {
    Menu {
      Button(
        day.isDayOff ? LocalizedStringResource.restorePlannedTimes : .makeDayOff,
        systemImage: day.isDayOff ? "clock" : "sun.max"
      ) {
        var updated = day
        updated.dayOff = !day.isDayOff
        _ = model.saveWeekDay(updated, replacing: day)
      }.accessibilityIdentifier("toggleDayOff.\(day.weekday)")
      if !day.isDayOff {
        lengthPicker(day)
        Button(.applyLengthToAllDays, systemImage: "calendar") {
          _ = model.setWindowLength(day.windowMinutes)
        }
        Button(.editWindowTimes, systemImage: "clock") { editingDay = day }
          .accessibilityIdentifier("editDay.\(day.weekday)")
        Divider()
        Button(.copyTimesToAllDays, systemImage: "calendar") {
          applyTimes(opens: day.opens, closes: day.closes)
        }
        Button(.copyTimes, systemImage: "doc.on.doc") {
          copiedTimes = (day.opens, day.closes)
        }
        if let copiedTimes {
          Button(.pasteTimes, systemImage: "doc.on.clipboard") {
            applyTimes(opens: copiedTimes.opens, closes: copiedTimes.closes, weekday: day.weekday)
          }
        }
      }
    } label: {
      Image(systemName: "ellipsis").font(.system(size: 17))
        .frame(width: 44, height: 44).contentShape(Rectangle())
    }.accessibilityLabel(
      Text(verbatim: "\(String(localized: .dayOptions)), \(weekday(day.weekday))")
    ).accessibilityIdentifier("dayMenu.\(day.weekday)")
  }

  private func lengthPicker(_ day: DayPlan? = nil) -> some View {
    let lengths = Set(model.usualDays.map(\.windowMinutes))
    let selected = day?.windowMinutes ?? (lengths.count == 1 ? lengths.first : nil)
    return windowLengthPicker(
      title: day == nil ? .windowLengthAllDays : .windowLength, selected: selected
    ) { minutes in
      _ = model.setWindowLength(minutes, weekday: day?.weekday)
    }
  }

  private func windowLengthPicker(
    title: LocalizedStringResource = .windowLength, selected: Int?,
    onSelect: @escaping (Int) -> Void
  ) -> some View {
    KvilWindowLengthPicker(title: title, selected: selected, onSelect: onSelect)
  }

  private func applyTimes(opens: WallTime, closes: WallTime, weekday: Int? = nil) {
    var days = model.usualDays
    for index in days.indices where weekday == nil || days[index].weekday == weekday {
      days[index].opens = opens
      days[index].closes = closes
    }
    _ = model.saveWeek(days)
  }

  private func duration(_ minutes: Int) -> String {
    Duration.seconds(minutes * 60).formatted(
      .units(allowed: [.hours, .minutes], width: .abbreviated).locale(locale))
  }

  private func windowSummary(_ day: DayPlan) -> String {
    let nextDay = day.overnight ? ", " + String(localized: .nextDayShort) : ""
    return
      "\(wallTimeString(day.opens)) – \(wallTimeString(day.closes))\(nextDay), \(duration(day.windowMinutes))"
  }

  private func wallTime(_ time: WallTime) -> some View {
    Text(verbatim: wallTimeString(time)).monospacedDigit().fixedSize()
  }
  private func wallTimeString(_ time: WallTime) -> String {
    Date(timeIntervalSinceReferenceDate: TimeInterval(time.minute * 60)).formatted(
      Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, timeZone: .gmt))
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
  var day: DayPlan? = nil
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @Environment(\.locale) private var locale
  @Environment(\.dynamicTypeSize) private var typeSize
  @State private var opens = WallTime(hour: 0)
  @State private var closes = WallTime(hour: 0)
  @State private var slidingWindow: DayPlan?
  @State private var validation: String?
  @State private var contentHeight: CGFloat = 0
  @State private var navigationHeight: CGFloat = 0

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: KvilStyle.content) {
          Text(day == nil ? LocalizedStringResource.todayEditorIntro : .dayEditorIntro)
            .foregroundStyle(Color.kvilSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
          VStack(alignment: .leading, spacing: KvilStyle.content) {
            if day == nil {
              windowControl
            } else {
              ViewThatFits(in: .horizontal) {
                if !typeSize.isAccessibilitySize {
                  HStack(spacing: 8) { timeWheels }.fixedSize(horizontal: true, vertical: false)
                }
                VStack(spacing: 8) { timeWheels }
              }.frame(maxWidth: .infinity)
              if closes < opens {
                Label(.closesNextDay, systemImage: "moon").font(.footnote).foregroundStyle(
                  Color.kvilSecondary)
              }
            }
          }.padding(KvilStyle.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.kvilSurface, in: RoundedRectangle(cornerRadius: KvilStyle.corner))
          if let validation {
            Text(validation).foregroundStyle(Color.kvilWarning)
              .fixedSize(horizontal: false, vertical: true)
              .accessibilityIdentifier("scheduleValidation")
          }
          if day == nil && model.engine.window(on: model.now)?.isOverride == true {
            Button(.useUsualSchedule) {
              if model.removeTodayOverride() {
                dismiss()
              } else {
                validation = model.message
                model.message = nil
              }
            }.frame(minHeight: 44)
          }
        }.padding(KvilStyle.page)
          .frame(maxWidth: .infinity, alignment: .leading)
          .onGeometryChange(for: CGFloat.self) {
            $0.size.height
          } action: {
            contentHeight = $0
          }
      }.scrollBounceBehavior(.basedOnSize).background(Color.kvilCanvas)
        .onGeometryChange(for: CGFloat.self) {
          $0.safeAreaInsets.top
        } action: {
          navigationHeight = $0
        }
        .navigationTitle(
          Text(
            verbatim: day.map { model.calendar.weekdaySymbols[$0.weekday - 1] }
              ?? String(localized: .changeToday))
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button(.cancel) { dismiss() } }
          ToolbarItem(placement: .confirmationAction) {
            Button(.save) { save() }.fontWeight(.semibold).accessibilityIdentifier(
              "saveSchedule")
          }
        }
        .onAppear { load() }
    }.tint(Color.kvilAccent)
      .presentationDetents(
        contentHeight > 0 ? [.height(contentHeight + navigationHeight)] : [.medium])
  }

  private var windowControl: some View {
    let window = DayPlan(
      weekday: model.calendar.component(.weekday, from: model.now), opens: opens, closes: closes)
    let shown = slidingWindow ?? window
    return VStack(alignment: .leading, spacing: KvilStyle.related) {
      ViewThatFits(in: .horizontal) {
        if !typeSize.isAccessibilitySize {
          HStack(alignment: .top, spacing: KvilStyle.content) {
            windowTime(shown.opens, title: .windowOpens, identifier: "openingTime")
            Spacer(minLength: 0)
            windowTime(shown.closes, title: .windowCloses, identifier: "closingTime")
          }
        }
        VStack(alignment: .leading, spacing: KvilStyle.related) {
          windowTime(shown.opens, title: .windowOpens, identifier: "openingTime")
          windowTime(shown.closes, title: .windowCloses, identifier: "closingTime")
        }
      }
      if shown.overnight {
        Text(.closesNextDay).font(.caption).foregroundStyle(Color.kvilSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      KvilWindowSlider(
        day: window, title: String(localized: .eatingWindow),
        value: "\(wallTimeString(shown.opens)) – \(wallTimeString(shown.closes))"
          + (shown.overnight ? ", " + String(localized: .closesNextDay) : ""),
        onMove: { _, updated in setWindow(updated) }, onPreview: { slidingWindow = $0 }
      ).accessibilityIdentifier("editorWindowSlider")
      KvilDayAxis()
      KvilControlRow(title: .windowLength) {
        KvilWindowLengthPicker(selected: window.windowMinutes) { minutes in
          if let updated = try? window.resized(to: minutes) { setWindow(updated) }
        }.labelsHidden().accessibilityIdentifier("editorWindowLength")
      }
    }
  }

  private func windowTime(_ time: WallTime, title: LocalizedStringResource, identifier: String)
    -> some View
  {
    VStack(alignment: .leading, spacing: 6) {
      Text(title).font(.subheadline).foregroundStyle(Color.kvilSecondary)
      Text(verbatim: wallTimeString(time))
        .font(.system(.title, design: .serif)).monospacedDigit().fixedSize()
    }.accessibilityElement(children: .combine).accessibilityIdentifier(identifier)
  }

  private func wallTimeString(_ time: WallTime) -> String {
    Date(timeIntervalSinceReferenceDate: TimeInterval(time.minute * 60)).formatted(
      Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, timeZone: .gmt))
  }

  private func setWindow(_ window: DayPlan) {
    opens = window.opens
    closes = window.closes
    validation = nil
  }

  @ViewBuilder private var timeWheels: some View {
    KvilTimeWheel(title: .windowOpens, time: $opens)
      .accessibilityIdentifier("openingTime")
    KvilTimeWheel(title: .windowCloses, time: $closes)
      .accessibilityIdentifier("closingTime")
  }
  private func wall(_ date: Date) -> WallTime {
    WallTime(
      hour: model.calendar.component(.hour, from: date),
      minute: model.calendar.component(.minute, from: date))
  }
  private func load() {
    if let day {
      opens = day.opens
      closes = day.closes
    } else if let w = model.engine.window(on: model.now) {
      opens = wall(w.opening)
      closes = wall(w.closing)
    }
  }
  private func save() {
    let saved: Bool
    if let day {
      var updated = day
      updated.opens = opens
      updated.closes = closes
      saved = model.saveWeekDay(updated, replacing: day)
    } else {
      saved = model.saveToday(opens: opens, closes: closes)
    }
    if saved {
      dismiss()
    } else {
      validation = model.message
      model.message = nil
    }
  }
}
