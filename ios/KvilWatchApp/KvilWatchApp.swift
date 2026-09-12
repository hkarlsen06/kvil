import SwiftUI

@main struct KvilWatchApp: App {
  @State private var bridge = WatchBridge()
  @State private var snapshot = SnapshotStore().read()
  @Environment(\.scenePhase) private var scenePhase
  var body: some Scene {
    WindowGroup {
      NavigationStack {
        TimelineView(.periodic(from: .now, by: 30)) { context in
          let state = snapshot.flatMap {
            ScheduleEngine(snapshot: $0, calendar: LocalDay.calendar()).state(at: context.date)
          }
          ScrollView {
            VStack(spacing: 12) {
              if let state {
                ZStack {
                  OpenArc().stroke(
                    Color.kvilTrack, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                  OpenArc(progress: state.progress).stroke(
                    Color.kvilAccent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                  VStack(spacing: 6) {
                    Image(systemName: state.isOpen ? "sun.max" : "leaf").foregroundStyle(
                      Color.kvilAccent)
                    if state.isOpen {
                      Text(L10n.windowOpen).font(.system(.title3, design: .serif))
                        .multilineTextAlignment(.center)
                    } else {
                      Text(
                        Duration.seconds(
                          max(0, state.next.opening.timeIntervalSince(context.date))),
                        format: .time(pattern: .hourMinute)
                      ).font(.system(.title, design: .rounded)).monospacedDigit()
                    }
                  }.padding(12)
                }.frame(width: 122, height: 122)
                if let active = state.active {
                  WindowTimeLabel(window: active).font(.caption)
                } else {
                  HStack(spacing: 2) {
                    Text(L10n.opensAtPrefix)
                    Text(state.next.opening, format: .dateTime.hour().minute())
                  }.font(.caption).accessibilityElement(children: .combine)
                }
                Text(bridge.reachable ? L10n.watchConnected : L10n.watchOffline).font(.caption2)
                  .foregroundStyle(Color.kvilSecondary).multilineTextAlignment(.center)
                Button {
                  bridge.refresh()
                } label: {
                  Label(L10n.refresh, systemImage: "arrow.clockwise")
                }.disabled(!bridge.reachable)
                if let snapshot {
                  Text(
                    snapshot.revision, format: .dateTime.month(.abbreviated).day().hour().minute()
                  ).font(.caption2).foregroundStyle(Color.kvilSecondary)
                }
              } else {
                Image(systemName: "leaf").font(.largeTitle).padding()
                Text(L10n.openKvilOnPhone).multilineTextAlignment(.center)
                Button(L10n.refresh) { bridge.refresh() }.disabled(!bridge.reachable)
              }
              if bridge.error {
                Text(L10n.watchRefreshFailed).font(.caption).foregroundStyle(Color.kvilWarning)
              }
            }.padding(.horizontal, 4)
          }
        }.navigationTitle(Text(verbatim: "kvil")).background(Color.kvilCanvas)
      }.environment(\.colorScheme, .dark).tint(Color.kvilAccent).foregroundStyle(Color.kvilInk)
        .onAppear {
          bridge.onSnapshot = { snapshot = $0 }
          bridge.refresh()
        }
        .onChange(of: scenePhase) { _, phase in
          if phase == .active {
            snapshot = SnapshotStore().read()
            bridge.refresh()
          }
        }
    }
  }
}
