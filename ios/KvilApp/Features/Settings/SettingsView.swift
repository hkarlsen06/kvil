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
  @Environment(\.dynamicTypeSize) private var typeSize
  @State private var showingPurchase = false
  @State private var exporting = false
  @State private var importing = false
  @State private var imported: LocalData?
  @State private var erase = false
  @State private var lastVisibleTarget: SettingsScrollTarget?
  @State private var userIsScrolling = false
  var body: some View {
    NavigationStack {
      ScrollViewReader { proxy in
        ScrollView {
          // Keep row heights and scroll targets tied to the full text at every Dynamic Type size.
          VStack(alignment: .leading, spacing: 0) {
            ForEach(sections: settingsSections) { section in
              if !section.header.isEmpty {
                VStack(alignment: .leading, spacing: 0) { section.header }
                  .font(.headline).accessibilityAddTraits(.isHeader)
                  .padding(.horizontal, KvilStyle.content).padding(.bottom, KvilStyle.related)
                  .id(SettingsScrollTarget.header(section.id))
                  .onScrollVisibilityChange(threshold: 0.5) {
                    rememberVisibleTarget(.header(section.id), isVisible: $0)
                  }
              }
              VStack(spacing: 0) {
                ForEach(section.content) { row in
                  if row.id != section.content.first?.id {
                    Divider().padding(.horizontal, KvilStyle.content)
                  }
                  row.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(.horizontal, KvilStyle.content).padding(.vertical, 4)
                    .id(SettingsScrollTarget.row(row.id))
                    .onScrollVisibilityChange(threshold: 0.5) {
                      rememberVisibleTarget(.row(row.id), isVisible: $0)
                    }
                }
              }
              .buttonStyle(SettingsRowButtonStyle())
              .background(Color.kvilSurface, in: RoundedRectangle(cornerRadius: KvilStyle.corner))
              .padding(.bottom, section.footer.isEmpty ? KvilStyle.section : KvilStyle.related)
              if !section.footer.isEmpty {
                VStack(alignment: .leading, spacing: 0) { section.footer }
                  .font(.footnote).foregroundStyle(Color.kvilSecondary)
                  .fixedSize(horizontal: false, vertical: true)
                  .padding(.horizontal, KvilStyle.content).padding(.bottom, KvilStyle.section)
                  .id(SettingsScrollTarget.footer(section.id))
                  .onScrollVisibilityChange(threshold: 0.5) {
                    rememberVisibleTarget(.footer(section.id), isVisible: $0)
                  }
              }
            }
          }.padding(KvilStyle.content)
        }.onScrollPhaseChange { _, phase in
          userIsScrolling = phase == .interacting || phase == .decelerating
        }
        .onChange(of: typeSize) { _, _ in
          if let lastVisibleTarget { proxy.scrollTo(lastVisibleTarget, anchor: .center) }
        }
        .background(Color.kvilCanvas).navigationTitle(.settings)
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
      }
    }.tint(Color.kvilAccent).modifier(AppMessageModifier())
  }

  private func rememberVisibleTarget(_ target: SettingsScrollTarget, isVisible: Bool) {
    // Font reflow must not replace the position established by the user's scroll.
    if isVisible && userIsScrolling { lastVisibleTarget = target }
  }

  @ViewBuilder private var settingsSections: some View {
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
        KvilControlRow(title: .weightUnit) {
          Picker(
            .weightUnit,
            selection: Binding(
              get: { model.data.preferences.weightUnit },
              set: { unit in model.preferences { $0.weightUnit = unit } })
          ) {
            Text(verbatim: "kg").tag(WeightUnit.kg)
            Text(verbatim: "lb").tag(WeightUnit.lb)
          }.pickerStyle(.menu).labelsHidden().buttonStyle(.borderless).frame(minHeight: 44)
            .accessibilityLabel(.weightUnit).accessibilityIdentifier("weightUnit")
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
      NavigationLink {
        FastingGuideView()
      } label: {
        disclosureLabel(.fastingGuide)
      }
      NavigationLink {
        DeviceHelpView()
      } label: {
        disclosureLabel(.watchAndWidgets, systemImage: "applewatch")
      }
    }
    Section {
      Button {
        showingPurchase = true
      } label: {
        Label(
          model.purchases.unlocked ? .historyUnlocked : .fullHistory,
          systemImage: "leaf"
        )
        .labelStyle(.titleAndIcon)
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
        .accessibilityIdentifier("cloudScheduleSync")
      if model.data.preferences.cloudScheduleEnabled {
        Text(
          model.cloud.status == .unavailable
            ? .cloudUnavailable
            : model.cloud.status == .needsAttention
              ? .cloudNeedsAttention
              : model.cloud.status == .enabled ? .cloudEnabled : .cloudWaiting
        )
        .font(.footnote).foregroundStyle(Color.kvilSecondary)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("cloudSyncStatus")
      }
    } footer: {
      Text(.cloudScheduleHelp).fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("cloudSyncHelp")
    }
    Section {
      Button(.exportData) { exporting = true }.accessibilityIdentifier("exportData")
      Button(.importData) { importing = true }
      Button(role: .destructive) { erase = true } label: {
        Text(.eraseData).foregroundStyle(Color.red)
      }
    } header: {
      Text(.yourData)
    } footer: {
      Text(.localStorageNotice)
    }
    Section {
      NavigationLink {
        PrivacyView()
      } label: {
        disclosureLabel(.privacy)
      }
      NavigationLink {
        AboutView()
      } label: {
        disclosureLabel(.aboutKvil)
      }
      LabeledContent(
        .version,
        value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
    }
  }

  private func disclosureLabel(_ title: LocalizedStringResource, systemImage: String? = nil)
    -> some View
  {
    HStack {
      if let systemImage {
        Label(title, systemImage: systemImage).labelStyle(.titleAndIcon)
      } else {
        Text(title)
      }
      Spacer(minLength: KvilStyle.related)
      Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
        .foregroundStyle(Color.kvilSecondary).accessibilityHidden(true)
    }
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
    return VStack(alignment: .leading, spacing: KvilStyle.related) {
      Text(title).fixedSize(horizontal: false, vertical: true).accessibilityHidden(true)
      Menu {
        Picker(title, selection: selection) {
          Text(.reminderAtTime).tag(0)
          Text(.reminderFifteenBefore).tag(15)
          Text(.reminderThirtyBefore).tag(30)
        }
      } label: {
        Text(value).foregroundStyle(Color.kvilAccent)
          .fixedSize(horizontal: false, vertical: true)
          .multilineTextAlignment(.leading)
          .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
      }.buttonStyle(.borderless).menuIndicator(.visible)
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

private enum SettingsScrollTarget: Hashable {
  case header(SectionConfiguration.ID)
  case row(Subview.ID)
  case footer(SectionConfiguration.ID)
}

private struct SettingsRowButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
      .foregroundStyle(configuration.role == .destructive ? Color.red : Color.kvilInk)
      .contentShape(Rectangle())
      .opacity(!isEnabled ? 0.5 : configuration.isPressed ? 0.65 : 1)
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
        Text(.privacyLocal).accessibilityIdentifier("privacyStorage")
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
