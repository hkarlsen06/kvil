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
                if state.isDayOff || state.upcomingDayOff != nil
                  || (state.active == nil && state.next == nil)
                {
                  Image(systemName: "sun.max").font(.largeTitle).foregroundStyle(Color.kvilAccent)
                    .padding(.top, 12).accessibilityHidden(true)
                  Text(state.upcomingDayOff == nil ? .dayOff : .daysOffStart)
                    .font(.system(.title2, design: .serif)).multilineTextAlignment(.center)
                  if let starts = state.upcomingDayOff {
                    Text(starts, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                      .font(.caption).multilineTextAlignment(.center)
                  } else if let resumes = state.resumesAt {
                    Text(.scheduleResumes).font(.caption)
                    Text(resumes, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                      .font(.caption).multilineTextAlignment(.center)
                  } else {
                    Text(.noWindowPlanned).font(.caption).multilineTextAlignment(.center)
                  }
                } else {
                  ZStack {
                    OpenArc().stroke(
                      Color.kvilTrack, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    OpenArc(progress: state.progress).stroke(
                      Color.kvilAccent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    VStack(spacing: 6) {
                      Image(systemName: state.isOpen ? "sun.max" : "leaf").foregroundStyle(
                        Color.kvilAccent)
                      if state.isOpen {
                        Text(.windowOpen).font(.system(.title3, design: .serif))
                          .multilineTextAlignment(.center)
                      } else if let next = state.next {
                        Text(
                          Duration.seconds(
                            max(0, next.opening.timeIntervalSince(context.date))),
                          format: .time(pattern: .hourMinute)
                        ).font(.system(.title, design: .rounded)).monospacedDigit()
                      }
                    }.padding(12)
                  }.frame(width: 122, height: 122)
                  if let active = state.active {
                    WindowTimeLabel(window: active).font(.caption)
                  } else if let next = state.next {
                    HStack(spacing: 2) {
                      Text(.opensAtPrefix)
                      Text(next.opening, format: .dateTime.hour().minute())
                    }.font(.caption).accessibilityElement(children: .combine)
                  }
                }
                Text(bridge.reachable ? .watchConnected : .watchOffline).font(.caption2)
                  .foregroundStyle(Color.kvilSecondary).multilineTextAlignment(.center)
                Button {
                  bridge.refresh()
                } label: {
                  Label(.refresh, systemImage: "arrow.clockwise")
                }.disabled(!bridge.reachable)
                if let snapshot {
                  Text(
                    snapshot.revision, format: .dateTime.month(.abbreviated).day().hour().minute()
                  ).font(.caption2).foregroundStyle(Color.kvilSecondary)
                }
              } else {
                Image(systemName: "leaf").font(.largeTitle).padding()
                Text(.openKvilOnPhone).multilineTextAlignment(.center)
                Button(.refresh) { bridge.refresh() }.disabled(!bridge.reachable)
              }
              if bridge.error {
                Text(.watchRefreshFailed).font(.caption).foregroundStyle(Color.kvilWarning)
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
