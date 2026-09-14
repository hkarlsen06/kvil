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
                    Text(reflection.feeling?.title ?? .skipped).font(.footnote).foregroundStyle(
                      Color.kvilSecondary)
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
      calendar: model.calendar, includeToday: true
    ).reflections.sorted { $0.dayKey > $1.dayKey }
  }
  private func reflectionDate(_ item: Reflection) -> Date {
    LocalDay.date(item.dayKey, calendar: model.calendar) ?? item.opening
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
                  / Double(max(1, recap.answerCount)))
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
  var body: some View {
    NavigationStack {
      List {
        Section {
          ForEach(DayFeeling.allCases, id: \.self) { feeling in
            Button {
              if model.editReflection(reflection, feeling: feeling) { dismiss() }
            } label: {
              HStack {
                Label(feeling.title, systemImage: feeling.symbol)
                Spacer()
                if feeling == reflection.feeling { Image(systemName: "checkmark") }
              }.padding(.vertical, 8)
            }
          }
        } header: {
          Text(.howDidItFeel)
        } footer: {
          Text(.reflectionHelp)
        }
        Section { Button(.deleteReflection, role: .destructive) { confirmDelete = true } }
      }.scrollContentBackground(.hidden).background(Color.kvilCanvas)
        .navigationTitle(Text(reflection.opening, format: .dateTime.month(.abbreviated).day()))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button(.done) { dismiss() } } }
        .alert(.deleteReflection, isPresented: $confirmDelete) {
          Button(.delete, role: .destructive) {
            if model.deleteReflection(reflection.id) { dismiss() }
          }
          Button(.cancel, role: .cancel) {}
        } message: {
          Text(.deleteReflectionBody)
        }
    }.tint(Color.kvilAccent).modifier(AppMessageModifier())
  }
}
