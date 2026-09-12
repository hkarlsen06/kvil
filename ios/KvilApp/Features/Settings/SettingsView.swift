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
    .accessibilityLabel(L10n.settings).accessibilityIdentifier("settings")
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
            L10n.openingReminder,
            isOn: Binding(
              get: { model.data.preferences.openingReminder },
              set: { enabled in Task { await model.setReminder(opening: true, enabled: enabled) } })
          )
          Toggle(
            L10n.closingReminder,
            isOn: Binding(
              get: { model.data.preferences.closingReminder },
              set: { enabled in Task { await model.setReminder(opening: false, enabled: enabled) } }
            ))
          if model.notificationStatus == .denied {
            Button(L10n.openSystemSettings) {
              if let url = URL(string: "app-settings:") { openURL(url) }
            }
            Text(L10n.remindersDenied).font(.footnote).foregroundStyle(Color.kvilSecondary)
          }
          if let through = model.remindersThrough {
            LabeledContent {
              Text(through, format: .dateTime.month(.abbreviated).day())
            } label: {
              Text(L10n.scheduledThrough)
            }
          }
        } header: {
          Text(L10n.reminders)
        } footer: {
          Text(L10n.reminderHorizonHelp)
        }
        Section {
          Toggle(L10n.showWeight, isOn: binding(\.weightEnabled))
          if model.data.preferences.weightEnabled {
            Picker(
              L10n.weightUnit,
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
              L10n.saveToHealth,
              isOn: Binding(
                get: { model.data.preferences.healthWritesEnabled },
                set: { enabled in
                  if enabled {
                    Task { await model.connectHealth(write: true) }
                  } else {
                    model.preferences { $0.healthWritesEnabled = false }
                  }
                }))
            Button(L10n.stopReadingHealth) {
              model.preferences {
                $0.healthEnabled = false
                $0.healthWritesEnabled = false
              }
            }
          } else {
            Button(L10n.connectHealth) { Task { await model.connectHealth(write: false) } }
              .disabled(!model.health.available)
          }
        } header: {
          Text(L10n.weightAndHealth)
        } footer: {
          Text(L10n.healthSettingsHelp)
        }
        Section {
          NavigationLink {
            DeviceHelpView()
          } label: {
            Label(L10n.watchAndWidgets, systemImage: "applewatch")
          }
        }
        Section {
          Button {
            showingPurchase = true
          } label: {
            Label(
              model.purchases.unlocked ? L10n.historyUnlocked : L10n.fullHistory,
              systemImage: "leaf")
          }
          Button(L10n.restorePurchases) {
            Task {
              await model.purchases.restore()
              model.message =
                model.purchases.error
                ?? String(localized: model.purchases.unlocked ? L10n.restored : L10n.noPurchases)
            }
          }.disabled(model.purchases.busy)
        }
        Section {
          Toggle(L10n.cloudSchedule, isOn: binding(\.cloudScheduleEnabled))
          if model.data.preferences.cloudScheduleEnabled {
            Text(
              model.cloud.status == .unavailable
                ? L10n.cloudUnavailable
                : model.cloud.status == .needsAttention
                  ? L10n.cloudNeedsAttention : L10n.cloudEnabled
            )
            .font(.footnote).foregroundStyle(Color.kvilSecondary)
          }
        } footer: {
          Text(L10n.cloudScheduleHelp)
        }
        Section {
          Button(L10n.exportData) { exporting = true }.accessibilityIdentifier("exportData")
          Button(L10n.importData) { importing = true }
          Button(L10n.eraseData, role: .destructive) { erase = true }
        } header: {
          Text(L10n.yourData)
        } footer: {
          Text(L10n.localStorageNotice)
        }
        Section {
          NavigationLink(L10n.privacy) { PrivacyView() }
          NavigationLink(L10n.aboutKvil) { AboutView() }
          LabeledContent(
            L10n.version,
            value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
        }
      }.scrollContentBackground(.hidden).background(Color.kvilCanvas).navigationTitle(L10n.settings)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L10n.done) { dismiss() } } }
        .sheet(isPresented: $showingPurchase) { PurchaseView() }
        .fileExporter(
          isPresented: $exporting, document: BackupDocument(data: model.data), contentType: .json,
          defaultFilename: "Kvil-backup"
        ) { result in
          if case .failure(let error) = result,
            (error as? CocoaError)?.code != .userCancelled
          {
            model.message = String(localized: L10n.exportFailed)
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
          } catch { model.message = String(localized: L10n.importInvalid) }
        }
        .alert(
          L10n.replaceData,
          isPresented: Binding(get: { imported != nil }, set: { if !$0 { imported = nil } })
        ) {
          Button(L10n.replace, role: .destructive) {
            if let imported, model.restore(imported) { dismiss() }
            imported = nil
          }
          Button(L10n.cancel, role: .cancel) { imported = nil }
        } message: {
          Text(L10n.replaceDataBody)
        }
        .alert(L10n.eraseData, isPresented: $erase) {
          Button(L10n.erase, role: .destructive) {
            Task { if await model.eraseLocalData() { dismiss() } }
          }
          Button(L10n.cancel, role: .cancel) {}
        } message: {
          Text(L10n.eraseDataBody)
        }
    }.tint(Color.kvilAccent).modifier(AppMessageModifier())
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
        Text(L10n.widgetHelp)
      } header: {
        Label(L10n.homeWidgets, systemImage: "square.grid.2x2")
      }
      Section {
        Text(L10n.lockWidgetHelp)
      } header: {
        Label(L10n.lockWidgets, systemImage: "lock")
      }
      Section {
        Text(L10n.watchHelp)
      } header: {
        Label(L10n.appleWatch, systemImage: "applewatch")
      }
    }.scrollContentBackground(.hidden).background(Color.kvilCanvas).navigationTitle(
      L10n.watchAndWidgets)
  }
}

struct PrivacyView: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        Text(L10n.privacyTitle).font(KvilStyle.title)
        Text(L10n.privacyLocal)
        Text(L10n.privacyHealth)
        Text(L10n.privacyDevices)
        Text(L10n.privacyPurchase)
        Text(L10n.privacyControl)
      }.padding(KvilStyle.page)
    }.background(Color.kvilCanvas).navigationTitle(L10n.privacy).navigationBarTitleDisplayMode(
      .inline)
  }
}
struct AboutView: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        KvilWordmark()
        Text(L10n.aboutBody).font(.title3)
        Text(L10n.onboardingSafety).foregroundStyle(Color.kvilSecondary)
        LandscapeView(height: 230).clipShape(RoundedRectangle(cornerRadius: 24))
        Text(L10n.supportBody).font(.subheadline).foregroundStyle(Color.kvilSecondary)
        Link(L10n.contactSupport, destination: URL(string: "mailto:hjalmar@hkarlsen06.dev")!)
      }.padding(KvilStyle.page)
    }.background(Color.kvilCanvas).navigationTitle(L10n.aboutKvil).navigationBarTitleDisplayMode(
      .inline)
  }
}
