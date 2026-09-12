import Charts
import SwiftUI

struct DisplayWeight: Identifiable {
  var id: String
  var kg: Double
  var date: Date
  var source: String
  var local: WeightEntry?
}

struct WeightView: View {
  @Environment(AppModel.self) private var model
  @State private var adding = false
  @State private var deleting: WeightEntry?
  @State private var editing: WeightEntry?
  private var records: [DisplayWeight] {
    let allLocalIDs = Set(model.data.weights.map(\.id))
    let local = model.data.weights.filter { !$0.pendingDeletion }.map {
      DisplayWeight(
        id: $0.id.uuidString, kg: $0.kilograms, date: $0.date,
        source: $0.saveToHealth && ($0.healthSampleID == nil || $0.healthNeedsUpdate)
          ? String(localized: L10n.healthPending) : "Kvil", local: $0)
    }
    let external = (model.data.preferences.healthEnabled ? model.healthWeights : []).filter {
      $0.localID.map { !allLocalIDs.contains($0) } ?? true
    }.map {
      DisplayWeight(
        id: $0.id.uuidString, kg: $0.kilograms, date: $0.date, source: $0.source, local: nil)
    }
    return (local + external).sorted { $0.date > $1.date }
  }
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        Text(L10n.weightIntro).foregroundStyle(Color.kvilSecondary)
        if records.isEmpty {
          ContentUnavailableView {
            Label(L10n.noWeights, systemImage: "chart.xyaxis.line")
          } description: {
            Text(L10n.noWeightsBody)
          }
        } else {
          let recent = records.filter {
            $0.date >= model.calendar.date(byAdding: .day, value: -30, to: model.now) ?? model.now
          }
          if recent.count >= 2 {
            Chart(recent) { record in
              LineMark(
                x: .value(String(localized: L10n.date), record.date),
                y: .value(
                  model.data.preferences.weightUnit.rawValue,
                  model.data.preferences.weightUnit.display(record.kg))
              )
              .foregroundStyle(Color.kvilAccent).interpolationMethod(.linear)
              PointMark(
                x: .value(String(localized: L10n.date), record.date),
                y: .value(
                  model.data.preferences.weightUnit.rawValue,
                  model.data.preferences.weightUnit.display(record.kg))
              ).foregroundStyle(Color.kvilAccent)
            }.chartYScale(domain: .automatic(includesZero: false)).frame(height: 170)
              .accessibilityLabel(L10n.recentWeightChart)
          }
          ForEach(records) { record in
            HStack(spacing: 12) {
              VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                  Text(
                    model.data.preferences.weightUnit.display(record.kg),
                    format: .number.precision(.fractionLength(1))
                  ).font(.title3.monospacedDigit())
                  Text(verbatim: model.data.preferences.weightUnit.rawValue).font(.subheadline)
                }
                Text(record.date, format: .dateTime.month(.abbreviated).day().hour().minute()).font(
                  .caption
                ).foregroundStyle(Color.kvilSecondary)
                Text(record.source).font(.caption).foregroundStyle(Color.kvilSecondary)
              }
              Spacer()
              if let local = record.local {
                Menu {
                  Button(L10n.edit) { editing = local }
                  Button(L10n.deleteWeight, role: .destructive) { deleting = local }
                } label: {
                  Image(systemName: "ellipsis").frame(width: 44, height: 44)
                }.accessibilityLabel(L10n.weightActions)
              } else {
                Image(systemName: "heart").foregroundStyle(Color.kvilSecondary).accessibilityLabel(
                  L10n.fromHealth)
              }
            }.padding(.vertical, 8)
            Divider()
          }
        }
        if model.data.preferences.healthEnabled {
          Text(L10n.healthReadNote).font(.footnote).foregroundStyle(Color.kvilSecondary)
          if model.data.weights.contains(where: {
            $0.pendingDeletion
              || ($0.saveToHealth && ($0.healthSampleID == nil || $0.healthNeedsUpdate))
          }) {
            Button(L10n.retryHealth) { Task { await model.refreshHealth() } }.disabled(
              model.healthBusy)
          }
        } else {
          Button(L10n.connectHealth) { Task { await model.connectHealth(write: false) } }
            .buttonStyle(.bordered)
        }
        Text(L10n.externalWeightHelp).font(.footnote).foregroundStyle(Color.kvilSecondary)
      }.padding(KvilStyle.page)
    }.background(Color.kvilCanvas).navigationTitle(L10n.weight)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            adding = true
          } label: {
            Image(systemName: "plus")
          }.accessibilityLabel(L10n.logWeight)
        }
      }
      .task { await model.refreshHealth() }
      .refreshable { await model.refreshHealth() }
      .sheet(isPresented: $adding) { WeightEditor() }
      .sheet(item: $editing) { WeightEditor(entry: $0) }
      .alert(
        L10n.deleteWeight,
        isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
      ) {
        Button(L10n.delete, role: .destructive) {
          if let deleting { Task { await model.deleteWeight(deleting) } }
          deleting = nil
        }
        Button(L10n.cancel, role: .cancel) { deleting = nil }
      } message: {
        Text(deleting?.saveToHealth == true ? L10n.deleteWeightHealthBody : L10n.deleteWeightBody)
      }
  }
}

struct WeightEditor: View {
  var entry: WeightEntry? = nil
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @State private var amount = ""
  @State private var date = Date()
  @State private var busy = false
  @State private var invalid = false
  @FocusState private var focused: Bool
  var body: some View {
    NavigationStack {
      Form {
        Section {
          HStack {
            TextField(L10n.weight, text: $amount).keyboardType(.decimalPad).focused($focused)
              .accessibilityIdentifier("weightAmount")
            Text(verbatim: model.data.preferences.weightUnit.rawValue)
          }
          DatePicker(L10n.date, selection: $date, in: ...model.now)
        } footer: {
          Text(L10n.weightNoTarget)
        }
        if invalid { Text(L10n.invalidWeight).foregroundStyle(Color.kvilWarning) }
        if model.data.preferences.healthWritesEnabled {
          Label(L10n.willSaveToHealth, systemImage: "heart").font(.footnote)
        }
      }.scrollContentBackground(.hidden).background(Color.kvilCanvas).navigationTitle(
        L10n.logWeight
      ).navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button(L10n.cancel) { dismiss() } }
          ToolbarItem(placement: .confirmationAction) {
            Button(L10n.save) { Task { await save() } }.disabled(busy || amount.isEmpty)
              .accessibilityIdentifier("saveWeight")
          }
        }.onAppear {
          date = entry?.date ?? model.now
          if let entry {
            amount = model.data.preferences.weightUnit.display(entry.kilograms).formatted(
              .number.precision(.fractionLength(1)))
          }
          focused = true
        }
    }.tint(Color.kvilAccent).modifier(AppMessageModifier())
  }
  private func save() async {
    guard let value = try? Double(amount, format: .number.locale(.current)),
      value.isFinite && value > 0
    else {
      invalid = true
      return
    }
    busy = true
    defer { busy = false }
    let saved: Bool
    if let entry {
      saved = await model.updateWeight(entry, value: value, date: date)
    } else {
      saved = await model.addWeight(value: value, date: date)
    }
    if saved { dismiss() }
  }
}
