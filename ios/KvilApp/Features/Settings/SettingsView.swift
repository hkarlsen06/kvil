import ActivityKit
import AppIntents
import SwiftUI
import UserNotifications

struct SettingsLink: View {
  @State private var showing = false
  var body: some View {
    Button {
      showing = true
    } label: {
      Image(systemName: "gearshape").font(.body.weight(.regular))
    }
    .accessibilityLabel(.settings).accessibilityIdentifier("settings")
    .sheet(isPresented: $showing) { SettingsView() }
  }
}

struct SettingsView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL
  @State private var showingPurchase = false
  @State private var exporting = false
  @State private var importing = false
  @State private var imported: LocalData?
  @State private var erase = false
  var body: some View {
    NavigationStack {
      Form {
        Section {
          Toggle(
            .openingReminder,
            isOn: Binding(
              get: { model.data.preferences.openingReminder },
              set: { enabled in Task { await model.setReminder(opening: true, enabled: enabled) } })
          )
          if model.data.preferences.openingReminder {
            reminderTiming(opening: true)
          }
          Toggle(
            .closingReminder,
            isOn: Binding(
              get: { model.data.preferences.closingReminder },
              set: { enabled in Task { await model.setReminder(opening: false, enabled: enabled) } }
            ))
          if model.data.preferences.closingReminder {
            reminderTiming(opening: false)
          }
          if model.notificationStatus == .denied {
            Button(.openSystemSettings) {
              if let url = URL(string: "app-settings:") { openURL(url) }
            }
            Text(.remindersDenied).font(.footnote).foregroundStyle(Color.kvilSecondary)
          }
          if let through = model.remindersThrough {
            LabeledContent {
              Text(through, format: .dateTime.month(.abbreviated).day())
            } label: {
              Text(.scheduledThrough)
            }
          }
        } header: {
          Text(.reminders)
        } footer: {
          Text(.reminderHorizonHelp)
        }
        Section {
          Toggle(
            .liveActivities,
            isOn: Binding(
              get: { model.data.preferences.liveActivitiesEnabled == true },
              set: { enabled in model.preferences { $0.liveActivitiesEnabled = enabled } })
          )
          .accessibilityIdentifier("liveActivities")
          if model.data.preferences.liveActivitiesEnabled == true,
            !ActivityAuthorizationInfo().areActivitiesEnabled
          {
            Text(.liveActivitiesDisabled).font(.footnote).foregroundStyle(Color.kvilSecondary)
            Button(.openSystemSettings) {
              if let url = URL(string: "app-settings:") { openURL(url) }
            }
          }
        } footer: {
          Text(.liveActivitiesHelp)
        }
        Section {
          Toggle(.showWeight, isOn: binding(\.weightEnabled))
          if model.data.preferences.weightEnabled {
            Picker(
              .weightUnit,
              selection: Binding(
                get: { model.data.preferences.weightUnit },
                set: { unit in model.preferences { $0.weightUnit = unit } })
            ) {
              Text(verbatim: "kg").tag(WeightUnit.kg)
              Text(verbatim: "lb").tag(WeightUnit.lb)
            }
          }
          if model.data.preferences.healthEnabled {
            Toggle(
              .saveToHealth,
              isOn: Binding(
                get: { model.data.preferences.healthWritesEnabled },
                set: { enabled in
                  if enabled {
                    Task { await model.connectHealth() }
                  } else {
                    model.preferences { $0.healthWritesEnabled = false }
                  }
                }))
            Button(.stopReadingHealth) {
              model.preferences {
                $0.healthEnabled = false
                $0.healthWritesEnabled = false
              }
            }
          } else {
            Button(.connectHealth) { Task { await model.connectHealth() } }
              .disabled(!model.health.available)
          }
        } header: {
          Text(.weightAndHealth)
        } footer: {
          Text(.healthSettingsHelp)
        }
        Section {
          NavigationLink(.fastingGuide) { FastingGuideView() }
          NavigationLink {
            DeviceHelpView()
          } label: {
            Label(.watchAndWidgets, systemImage: "applewatch")
          }
        }
        Section {
          Button {
            showingPurchase = true
          } label: {
            Label(
              model.purchases.unlocked ? .historyUnlocked : .fullHistory,
              systemImage: "leaf")
          }
          Button(.restorePurchases) {
            Task {
              await model.purchases.restore()
              model.message =
                model.purchases.error
                ?? String(localized: model.purchases.unlocked ? .restored : .noPurchases)
            }
          }.disabled(model.purchases.busy)
        }
        Section {
          Toggle(.cloudSchedule, isOn: binding(\.cloudScheduleEnabled))
          if model.data.preferences.cloudScheduleEnabled {
            Text(
              model.cloud.status == .unavailable
                ? .cloudUnavailable
                : model.cloud.status == .needsAttention
                  ? .cloudNeedsAttention : .cloudEnabled
            )
            .font(.footnote).foregroundStyle(Color.kvilSecondary)
          }
        } footer: {
          Text(.cloudScheduleHelp)
        }
        Section {
          Button(.exportData) { exporting = true }.accessibilityIdentifier("exportData")
          Button(.importData) { importing = true }
          Button(.eraseData, role: .destructive) { erase = true }
        } header: {
          Text(.yourData)
        } footer: {
          Text(.localStorageNotice)
        }
        Section {
          NavigationLink(.privacy) { PrivacyView() }
          NavigationLink(.aboutKvil) { AboutView() }
          LabeledContent(
            .version,
            value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
        }
      }.scrollContentBackground(.hidden).background(Color.kvilCanvas).navigationTitle(.settings)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button(.done) { dismiss() } } }
        .sheet(isPresented: $showingPurchase) { PurchaseView() }
        .fileExporter(
          isPresented: $exporting, document: BackupDocument(data: model.data), contentType: .json,
          defaultFilename: "Kvil-backup"
        ) { result in
          if case .failure(let error) = result,
            (error as? CocoaError)?.code != .userCancelled
          {
            model.message = String(localized: .exportFailed)
          }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
          do {
            let url = try result.get()
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 10_000_000 else { throw CocoaError(.fileReadTooLarge) }
            let bytes = try Data(contentsOf: url)
            guard bytes.count <= 10_000_000 else { throw CocoaError(.fileReadTooLarge) }
            imported = try JSONDecoder().decode(LocalData.self, from: bytes).validated()
          } catch let error as CocoaError where error.code == .userCancelled {
          } catch { model.message = String(localized: .importInvalid) }
        }
        .alert(
          .replaceData,
          isPresented: Binding(get: { imported != nil }, set: { if !$0 { imported = nil } })
        ) {
          Button(.replace, role: .destructive) {
            if let imported, model.restore(imported) { dismiss() }
            imported = nil
          }
          Button(.cancel, role: .cancel) { imported = nil }
        } message: {
          Text(.replaceDataBody)
        }
        .alert(.eraseData, isPresented: $erase) {
          Button(.erase, role: .destructive) {
            Task { if await model.eraseLocalData() { dismiss() } }
          }
          Button(.cancel, role: .cancel) {}
        } message: {
          Text(.eraseDataBody)
        }
    }.tint(Color.kvilAccent).modifier(AppMessageModifier())
  }
  private func reminderTiming(opening: Bool) -> some View {
    let title: LocalizedStringResource = opening ? .openingReminderTiming : .closingReminderTiming
    let selection = Binding(
      get: {
        opening
          ? model.data.preferences.openingReminderLead
          : model.data.preferences.closingReminderLead
      },
      set: { minutes in
        model.preferences {
          if opening {
            $0.openingReminderLeadMinutes = minutes
          } else {
            $0.closingReminderLeadMinutes = minutes
          }
        }
      })
    let value: LocalizedStringResource =
      switch selection.wrappedValue {
      case 15: .reminderFifteenBefore
      case 30: .reminderThirtyBefore
      default: .reminderAtTime
      }
    return KvilControlRow(title: title) {
      Menu {
        Picker(title, selection: selection) {
          Text(.reminderAtTime).tag(0)
          Text(.reminderFifteenBefore).tag(15)
          Text(.reminderThirtyBefore).tag(30)
        }
      } label: {
        HStack(spacing: 6) {
          Text(value).fixedSize(horizontal: false, vertical: true)
          Image(systemName: "chevron.up.chevron.down").imageScale(.small)
        }.multilineTextAlignment(.leading).frame(minHeight: 44)
      }
      .accessibilityLabel(title).accessibilityValue(Text(value))
      .accessibilityIdentifier(opening ? "openingReminderTiming" : "closingReminderTiming")
    }
  }
  private func binding(_ key: WritableKeyPath<Preferences, Bool>) -> Binding<Bool> {
    Binding(
      get: { model.data.preferences[keyPath: key] },
      set: { new in model.preferences { $0[keyPath: key] = new } })
  }
}

struct DeviceHelpView: View {
  var body: some View {
    List {
      Section {
        Text(.widgetHelp)
      } header: {
        Label(.homeWidgets, systemImage: "square.grid.2x2")
      }
      Section {
        Text(.lockWidgetHelp)
      } header: {
        Label(.lockWidgets, systemImage: "lock")
      }
      Section {
        Text(.watchHelp)
      } header: {
        Label(.appleWatch, systemImage: "applewatch")
      }
      Section {
        Text(.shortcutsHelp)
        ShortcutsLink()
      } header: {
        Label(.siriAndShortcuts, systemImage: "waveform")
      }
    }.scrollContentBackground(.hidden).background(Color.kvilCanvas).navigationTitle(
      .watchAndWidgets)
  }
}

struct PrivacyView: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        Text(.privacyTitle).font(KvilStyle.title)
        Text(.privacyLocal)
        Text(.privacyHealth)
        Text(.privacyDevices)
        Text(.privacyPurchase)
        Text(.privacyControl)
      }.padding(KvilStyle.page)
    }.background(Color.kvilCanvas).navigationTitle(.privacy).navigationBarTitleDisplayMode(
      .inline)
  }
}
struct AboutView: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        KvilWordmark()
        Text(.aboutBody).font(.title3)
        Text(.onboardingSafety).foregroundStyle(Color.kvilSecondary)
        LandscapeView(height: 230).clipShape(RoundedRectangle(cornerRadius: 24))
        Text(.supportBody).font(.subheadline).foregroundStyle(Color.kvilSecondary)
        Link(.contactSupport, destination: URL(string: "mailto:hjalmar@hkarlsen06.dev")!)
      }.padding(KvilStyle.page)
    }.background(Color.kvilCanvas).navigationTitle(.aboutKvil).navigationBarTitleDisplayMode(
      .inline)
  }
}
