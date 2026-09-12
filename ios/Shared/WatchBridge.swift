import Foundation
import Observation
@preconcurrency import WatchConnectivity
import WidgetKit

@MainActor @Observable final class WatchBridge: NSObject, WCSessionDelegate {
  private(set) var reachable = false
  private(set) var receivedAt: Date?
  private(set) var error = false
  private let store: SnapshotStore
  private var current: ScheduleSnapshot?
  private let session: WCSession?
  var onSnapshot: ((ScheduleSnapshot) -> Void)?
  init(store: SnapshotStore = SnapshotStore(), enabled: Bool = true) {
    self.store = store
    self.session = enabled && WCSession.isSupported() ? WCSession.default : nil
    self.current = store.read()
    super.init()
    session?.delegate = self
    session?.activate()
  }
  func publish(_ snapshot: ScheduleSnapshot) {
    current = snapshot
    transmit()
  }
  private func transmit() {
    #if os(iOS)
      guard let session, session.activationState == .activated, let current,
        session.isPaired, session.isWatchAppInstalled
      else { return }
      do { try session.updateApplicationContext(["schedule": JSONEncoder().encode(current)]) } catch
      { self.error = true }
    #endif
  }
  func refresh() {
    guard let session, session.isReachable else {
      reachable = false
      return
    }
    session.sendMessage(
      ["refresh": true],
      replyHandler: { [weak self] reply in
        guard let data = reply["schedule"] as? Data else { return }
        Task { @MainActor in self?.receive(data) }
      }, errorHandler: { [weak self] _ in Task { @MainActor in self?.error = true } })
  }
  private func receive(_ data: Data) {
    guard data.count < 2_000_000,
      let snapshot = try? JSONDecoder().decode(ScheduleSnapshot.self, from: data),
      current == nil || snapshot.revision >= current!.revision
    else { return }
    do {
      try store.write(snapshot)
      current = snapshot
      receivedAt = Date()
      error = false
      WidgetCenter.shared.reloadAllTimelines()
      onSnapshot?(snapshot)
    } catch { self.error = true }
  }
  nonisolated func session(
    _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    let reachable = session.isReachable
    Task { @MainActor in
      self.reachable = reachable
      #if os(watchOS)
        self.refresh()
      #else
        self.transmit()
      #endif
    }
  }
  nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
    let reachable = session.isReachable
    Task { @MainActor in self.reachable = reachable }
  }
  nonisolated func session(
    _ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]
  ) {
    #if os(watchOS)
      guard let data = applicationContext["schedule"] as? Data else { return }
      Task { @MainActor in self.receive(data) }
    #endif
  }
  nonisolated func session(
    _ session: WCSession, didReceiveMessage message: [String: Any],
    replyHandler: @escaping ([String: Any]) -> Void
  ) {
    if message["refresh"] as? Bool == true, let snapshot = SnapshotStore().read(),
      let data = try? JSONEncoder().encode(snapshot)
    {
      replyHandler(["schedule": data])
    } else {
      replyHandler([:])
    }
  }
  #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
  #endif
}
