import BackgroundTasks
import SwiftUI

@main struct KvilApp: App {
  @State private var model: AppModel?
  @State private var storageFailure = false
  @Environment(\.scenePhase) private var scenePhase
  init() {
    BGTaskScheduler.shared.register(forTaskWithIdentifier: ReminderService.backgroundID, using: nil)
    { task in
      let work = Task { @MainActor in
        do {
          let store = try LocalStore()
          let data = try store.load()
          let service = ReminderService()
          _ = try await service.reconcile(snapshot: data.schedule, preferences: data.preferences)
          await service.scheduleRefresh()
          task.setTaskCompleted(success: true)
        } catch { task.setTaskCompleted(success: false) }
      }
      task.expirationHandler = { work.cancel() }
    }
  }
  var body: some Scene {
    WindowGroup {
      Group {
        if let model {
          RootView().environment(model)
        } else if storageFailure {
          ContentUnavailableView {
            Label(L10n.storageUnavailable, systemImage: "externaldrive.badge.exclamationmark")
          } description: {
            Text(L10n.storageUnavailableBody)
          } actions: {
            Button(L10n.tryAgain) { load() }
          }
          .background(Color.kvilCanvas)
        } else {
          KvilLaunchView()
        }
      }.tint(Color.kvilAccent).foregroundStyle(Color.kvilInk)
        .task { if model == nil { load() } }
        .onChange(of: scenePhase) { _, phase in
          if phase == .active { Task { await model?.refresh() } }
        }
    }
  }
  private func load() {
    do {
      var scenario: String?
      #if DEBUG
        scenario = ProcessInfo.processInfo.environment["KVIL_SCENARIO"]
        if scenario == nil
          && ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        {
          scenario = "onboarding"
        }
      #endif
      let store = try LocalStore(inMemory: scenario != nil)
      model = try AppModel(store: store, scenario: scenario)
      storageFailure = false
    } catch { storageFailure = true }
  }
}

struct RootView: View {
  @Environment(AppModel.self) private var model
  var body: some View {
    @Bindable var model = model
    Group {
      if model.isConfigured {
        TabView(selection: $model.selectedTab) {
          Tab(L10n.home, systemImage: "sun.horizon", value: 0) { NavigationStack { HomeView() } }
          Tab(L10n.schedule, systemImage: "calendar", value: 1) {
            NavigationStack { ScheduleView() }
          }
          Tab(L10n.history, systemImage: "leaf", value: 2) { NavigationStack { HistoryView() } }
        }
      } else {
        OnboardingView()
      }
    }.background(Color.kvilCanvas).modifier(AppMessageModifier())
      .task {
        await model.refresh()
        await model.purchases.load()
      }
      .onOpenURL { url in
        guard url.scheme == "kvil" else { return }
        model.selectedTab = url.host == "schedule" ? 1 : 0
      }
      .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
        model.updateSurfaces()
      }
      .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
        model.updateSurfaces()
      }
  }
}

struct AppMessageModifier: ViewModifier {
  @Environment(AppModel.self) private var model
  func body(content: Content) -> some View {
    content.safeAreaInset(edge: .top, spacing: 0) {
      if let message = model.message {
        HStack(alignment: .top) {
          Text(message).font(.subheadline).fixedSize(horizontal: false, vertical: true)
          Spacer(minLength: 8)
          Button {
            model.message = nil
          } label: {
            Image(systemName: "xmark").frame(width: 44, height: 44)
          }.accessibilityLabel(L10n.dismiss)
        }.padding(.leading, 20).padding(.vertical, 8)
          .foregroundStyle(Color.kvilInk).background(Color.kvilSurface)
          .accessibilityElement(children: .contain)
      }
    }
  }
}
