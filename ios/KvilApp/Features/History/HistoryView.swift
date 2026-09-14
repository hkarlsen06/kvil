import SwiftUI

struct HistoryView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dynamicTypeSize) private var typeSize
  @State private var days = 7
  @State private var showingPurchase = false
  @State private var addingWeight = false
  @State private var editing: Reflection?
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 28) {
        if !typeSize.isAccessibilitySize {
          VStack(alignment: .leading, spacing: 8) {
            Text(.aMomentToLookBack).font(KvilStyle.title)
            Text(.historyIntro).foregroundStyle(Color.kvilSecondary)
          }
        }
        if model.purchases.unlocked {
          Picker(.recapRange, selection: $days) {
            Text(.week).tag(7)
            Text(.month).tag(30)
            Text(.allTime).tag(36500)
          }.pickerStyle(.segmented)
        }
        recap
        if model.data.preferences.weightEnabled {
          weightHistory
        } else {
          Button {
            model.preferences { $0.weightEnabled = true }
          } label: {
            Label(.addWeightOptional, systemImage: "plus.circle").font(.subheadline)
          }
        }
        VStack(alignment: .leading, spacing: 8) {
          Text(.yourReflections).font(KvilStyle.heading)
          if visible.isEmpty {
            Image(systemName: "leaf").font(.largeTitle.weight(.ultraLight)).padding(.top, 16)
              .accessibilityHidden(true)
            Text(.reflectionsEmpty).foregroundStyle(Color.kvilSecondary).padding(.vertical, 8)
          } else {
            ForEach(visible) { reflection in
              Button {
                editing = reflection
              } label: {
                HStack(spacing: 14) {
                  Image(systemName: reflection.feeling?.symbol ?? "minus").frame(width: 28).font(
                    .title3)
                  VStack(alignment: .leading, spacing: 4) {
                    Text(
                      reflectionDate(reflection),
                      format: .dateTime.weekday(.wide).month(.abbreviated).day()
                    ).font(.subheadline.weight(.medium))
                    if let experience = reflection.planExperience {
                      Text(experience.title).font(.footnote).foregroundStyle(Color.kvilSecondary)
                    } else if reflection.wasDayOff == true {
                      Text(.dayOff).font(.footnote).foregroundStyle(Color.kvilSecondary)
                    }
                    Text(reflection.feeling?.title ?? .skipped).font(.footnote).foregroundStyle(
                      Color.kvilSecondary)
                    if let note = reflection.note, !note.isEmpty {
                      Text(note).font(.subheadline).lineLimit(2).foregroundStyle(Color.kvilInk)
                    }
                  }
                  Spacer()
                  Image(systemName: "chevron.right").font(.caption)
                }.padding(.vertical, 12).contentShape(Rectangle())
              }.buttonStyle(.plain)
              Divider().overlay(Color.kvilLine)
            }
          }
        }
        if !model.purchases.unlocked {
          VStack(alignment: .leading, spacing: 12) {
            Text(.keepTheBiggerPicture).font(KvilStyle.heading)
            Text(.freeHistoryExplanation).font(.subheadline).foregroundStyle(
              Color.kvilSecondary)
            Button(.exploreFullHistory) { showingPurchase = true }.font(
              .subheadline.weight(.semibold)
            ).frame(minHeight: 44)
              .accessibilityIdentifier("exploreHistory")
          }.padding(.vertical, 8)
        }
      }.padding(KvilStyle.page)
    }.background(Color.kvilCanvas).navigationTitle(.history).navigationBarTitleDisplayMode(
      .inline
    )
    .toolbar { ToolbarItem(placement: .topBarTrailing) { SettingsLink() } }
    .sheet(isPresented: $showingPurchase) { PurchaseView() }
    .sheet(isPresented: $addingWeight) { WeightEditor() }
    .sheet(item: $editing) { ReflectionEditor(reflection: $0) }
    .task(id: model.data.preferences.weightEnabled && model.data.preferences.healthEnabled) {
      if model.data.preferences.weightEnabled { await model.refreshHealth() }
    }
  }
  private var weightHistory: some View {
    let records = model.weightRecords
    return VStack(alignment: .leading, spacing: KvilStyle.related) {
      if records.count >= 2 {
        VStack(alignment: .leading, spacing: KvilStyle.content) {
          HStack {
            Text(.weight).font(KvilStyle.heading)
            Spacer()
            Button {
              addingWeight = true
            } label: {
              Image(systemName: "plus").frame(width: 44, height: 44)
            }
            .accessibilityLabel(.logWeight)
            .accessibilityIdentifier("historyAddWeight")
          }
          WeightChart(records: records, unit: model.data.preferences.weightUnit)
            .accessibilityLabel(.weightHistoryChart)
            .accessibilityIdentifier("historyWeightChart")
        }.padding(KvilStyle.cardPadding).background(
          Color.kvilSurface, in: RoundedRectangle(cornerRadius: KvilStyle.corner))
      }
      NavigationLink {
        WeightView()
      } label: {
        HStack {
          Label(.weight, systemImage: "chart.xyaxis.line")
          Spacer()
          Image(systemName: "chevron.right").font(.caption)
        }.padding(.vertical, 8).frame(minHeight: 44)
      }.accessibilityIdentifier("weightLog")
    }
  }
  private var visible: [Reflection] {
    Recap.recent(
      model.data.reflections, days: model.purchases.unlocked ? days : 7, now: model.now,
      calendar: model.calendar, includeToday: false
    ).reflections.sorted { $0.dayKey > $1.dayKey }
  }
  private func reflectionDate(_ item: Reflection) -> Date {
    LocalDay.date(
      item.dayKey,
      calendar: LocalDay.calendar(
        timeZone: TimeZone(identifier: item.timeZoneID) ?? model.calendar.timeZone)) ?? item.opening
  }
  private var recap: some View {
    let recap = Recap.recent(
      model.data.reflections, days: model.purchases.unlocked ? days : 7, now: model.now,
      calendar: model.calendar)
    return VStack(alignment: .leading, spacing: 20) {
      let layout =
        typeSize.isAccessibilitySize
        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout())
      layout {
        Text(.recentDays).font(KvilStyle.heading)
        if !typeSize.isAccessibilitySize { Spacer() }
        HStack {
          Text(recap.answerCount, format: .number).font(.title2).monospacedDigit()
          Text(.reflectionsLabel).font(.caption)
        }
      }
      if recap.answerCount == 0 {
        Text(.recapEmpty).font(.subheadline).foregroundStyle(Color.kvilSecondary)
      } else {
        ForEach(DayFeeling.allCases, id: \.self) { feeling in
          VStack(spacing: 8) {
            HStack {
              Label(feeling.title, systemImage: feeling.symbol).font(.subheadline)
              Spacer()
              Text(recap.count(feeling), format: .number).font(.subheadline.monospacedDigit())
            }
            GeometryReader { proxy in
              Capsule().fill(Color.kvilTrack)
              Capsule().fill(Color.kvilAccent).frame(
                width: proxy.size.width * Double(recap.count(feeling))
                  / Double(max(1, recap.feelingCount)))
            }.frame(height: 5).accessibilityHidden(true)
          }
        }
      }
      Text(.recapNote).font(.caption).foregroundStyle(Color.kvilSecondary)
    }.padding(20).background(
      Color.kvilSurface, in: RoundedRectangle(cornerRadius: KvilStyle.corner))
  }
}

struct ReflectionEditor: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  var reflection: Reflection
  @State private var confirmDelete = false
  @State private var editing = false
  private var current: Reflection {
    model.data.reflections.first { $0.id == reflection.id } ?? reflection
  }
  private var calendar: Calendar {
    LocalDay.calendar(timeZone: TimeZone(identifier: current.timeZoneID) ?? .current)
  }
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: KvilStyle.section) {
          Text(
            LocalDay.date(current.dayKey, calendar: calendar) ?? current.opening,
            format: .dateTime.weekday(.wide).month(.wide).day().year()
          )
          .font(KvilStyle.title)
          if current.wasDayOff == true {
            Label(.dayOff, systemImage: "leaf").font(KvilStyle.heading)
          } else {
            VStack(alignment: .leading, spacing: KvilStyle.related) {
              Text(.plannedEatingWindow).font(.footnote).foregroundStyle(Color.kvilSecondary)
              ReflectionTimeRange(opening: current.opening, closing: current.closing)
                .font(.title3).monospacedDigit()
            }
          }
          if let experience = current.planExperience {
            VStack(alignment: .leading, spacing: KvilStyle.related) {
              Text(.yourReportedAnswer).font(.footnote).foregroundStyle(Color.kvilSecondary)
              Text(experience.title).font(KvilStyle.heading)
            }
          }
          if let first = current.firstMeal, let last = current.lastMeal {
            VStack(alignment: .leading, spacing: KvilStyle.related) {
              Text(.approximateMealTimes).font(.footnote).foregroundStyle(Color.kvilSecondary)
              ReflectionTimeRange(opening: first, closing: last).font(.title3).monospacedDigit()
              Text(.mealTimesAreEstimates).font(.caption).foregroundStyle(Color.kvilSecondary)
            }
          }
          if let feeling = current.feeling {
            Label(feeling.title, systemImage: feeling.symbol).font(KvilStyle.heading)
          }
          if let note = current.note {
            Text(note).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
          }
          Button(.editReflection) { editing = true }.buttonStyle(KvilPrimaryButtonStyle())
            .accessibilityIdentifier("editReflection")
          Button(.deleteReflection, role: .destructive) { confirmDelete = true }.frame(
            minHeight: 44)
        }.padding(KvilStyle.page)
      }.background(Color.kvilCanvas).navigationTitle(.yourReflections)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button(.done) { dismiss() } } }
        .sheet(isPresented: $editing) { ReflectionFlowView(reflection: current) }
        .alert(.deleteReflection, isPresented: $confirmDelete) {
          Button(.delete, role: .destructive) {
            if model.deleteReflection(current.id) { dismiss() }
          }
          Button(.cancel, role: .cancel) {}
        } message: {
          Text(.deleteReflectionBody)
        }
    }.tint(Color.kvilAccent).environment(\.timeZone, calendar.timeZone)
      .modifier(AppMessageModifier())
  }
}
