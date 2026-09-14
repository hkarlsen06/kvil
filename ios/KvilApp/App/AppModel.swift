import Foundation
import Observation
import UserNotifications
import WidgetKit

enum AppTab: Hashable {
  case home
  case schedule
  case history
}

@MainActor @Observable final class AppModel {
  private(set) var data: LocalData
  private(set) var healthWeights: [HealthWeight] = []
  private(set) var healthBusy = false
  private(set) var notificationStatus: UNAuthorizationStatus = .notDetermined
  private(set) var remindersThrough: Date?
  var message: String?
  var selectedTab: AppTab = .home
  var homeHighlightPending = false
  private(set) var homePresentationID: UUID?
  let purchases: PurchaseService
  let watch: WatchBridge
  let reminders: ReminderService
  let health: any HealthAccess
  let cloud: ScheduleCloudService
  let store: LocalStore
  let scenario: String?
  let fixedNow: Date?
  private let deviceServicesEnabled: Bool
  private var derivedTask: Task<Void, Never>?
  var now: Date { fixedNow ?? Date() }
  var calendar: Calendar { LocalDay.calendar() }
  var engine: ScheduleEngine { ScheduleEngine(snapshot: data.schedule, calendar: calendar) }
  var isConfigured: Bool { !data.schedule.versions.isEmpty }

  func presentHome() {
    selectedTab = .home
    homeHighlightPending = true
    homePresentationID = UUID()
  }

  init(
    store: LocalStore, reminders: ReminderService = ReminderService(),
    health: any HealthAccess = HealthService(), scenario: String? = nil
  ) throws {
    self.store = store
    self.reminders = reminders
    self.health = health
    self.scenario = scenario
    deviceServicesEnabled = scenario == nil && !store.isInMemory
    #if DEBUG
    fixedNow =
      scenario != nil && scenario != "openingSoon" && scenario != "closingSoon"
      && scenario != "progressReturn"
      ? ISO8601DateFormatter().date(
        from: scenario == "open"
          ? "2026-09-12T12:00:00Z"
          : scenario == "reflection" ? "2026-09-12T18:00:00Z" : "2026-09-12T06:15:00Z") : nil
    #else
    fixedNow = nil
    #endif
    var isolatedPurchases = scenario != nil
    #if DEBUG
      if ProcessInfo.processInfo.environment["KVIL_STOREKIT_TESTING"] == "1" {
        isolatedPurchases = false
      }
    #endif
    purchases = PurchaseService(scenario: isolatedPurchases, unlocked: scenario == "history")
    watch = WatchBridge(enabled: deviceServicesEnabled)
    cloud = ScheduleCloudService(enabled: deviceServicesEnabled)
    data = try store.load()
    #if DEBUG
      if let scenario, scenario != "onboarding" {
        data = ScenarioData.make(
          now: fixedNow ?? Date(), calendar: LocalDay.calendar(), openingSoon: scenario == "openingSoon",
          closingSoon: scenario == "closingSoon", progressReturn: scenario == "progressReturn")
      }
    #endif
    cloud.onChange = { [weak self] in self?.updateSurfaces() }
    cloud.onAccountChange = { [weak self] in
      self?.preferences { $0.cloudScheduleEnabled = false }
      self?.message = String(localized: .cloudAccountChanged)
    }
  }

  @discardableResult func commit(_ next: LocalData, publish: Bool = false) -> Bool {
    do {
      let normalized = try next.validated()
      try store.save(normalized)
      data = normalized
      if publish { updateSurfaces() }
      return true
    } catch {
      message = String(localized: .saveFailed)
      return false
    }
  }
  func configure(days: [DayPlan]) -> Bool {
    do { try ScheduleEngine.validate(days: days) } catch {
      message = errorText(error)
      return false
    }
    var next = data
    let stamp = Date()
    let stamped = days.map { day in
      var d = day
      d.modifiedAt = stamp
      return d
    }
    next.schedule = ScheduleSnapshot(
      revision: stamp,
      versions: [
        ScheduleVersion(
          effectiveDay: LocalDay.key(now, calendar: calendar), days: stamped, modifiedAt: stamp)
      ], overrides: [], resetAt: data.schedule.resetAt)
    return commit(next, publish: true)
  }
  var usualDays: [DayPlan] {
    data.schedule.versions.max { $0.effectiveDay < $1.effectiveDay }?.days ?? DayPlan.initial
  }

  func saveWeekDay(_ day: DayPlan, replacing original: DayPlan) -> Bool {
    var days = usualDays
    guard day.weekday == original.weekday,
      let index = days.firstIndex(where: { $0.weekday == original.weekday }),
      days[index].opens == original.opens, days[index].closes == original.closes
    else {
      message = String(localized: .scheduleChangedWhileEditing)
      return false
    }
    guard day.opens != original.opens || day.closes != original.closes else { return true }
    days[index] = day
    return saveWeek(days)
  }

  func setWindowLength(_ minutes: Int, weekday: Int? = nil) -> Bool {
    guard (1..<1440).contains(minutes),
      weekday == nil || usualDays.contains(where: { $0.weekday == weekday })
    else {
      message = String(localized: .invalidTime)
      return false
    }
    do {
      let days = try usualDays.map { day in
        weekday == nil || day.weekday == weekday ? try day.resized(to: minutes) : day
      }
      return days == usualDays || saveWeek(days)
    } catch {
      message = errorText(error)
      return false
    }
  }

  func saveWeek(_ days: [DayPlan]) -> Bool {
    guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else { return false }
    var next = data
    let key = LocalDay.key(tomorrow, calendar: calendar)
    next.schedule.versions.removeAll { $0.effectiveDay >= key }
    let stamp = Date()
    let previous = data.schedule.versions.max { $0.effectiveDay < $1.effectiveDay }?.days ?? []
    let stamped = days.map { day in
      var d = day
      if let old = previous.first(where: { $0.weekday == d.weekday }),
        old.opens == d.opens && old.closes == d.closes
      {
        d.modifiedAt = old.modifiedAt
      } else {
        d.modifiedAt = stamp
      }
      return d
    }
    next.schedule.versions.append(
      ScheduleVersion(effectiveDay: key, days: stamped, modifiedAt: stamp))
    next.schedule.revision = Date()
    do { try ScheduleEngine(snapshot: next.schedule, calendar: calendar).validate(near: now) } catch
    {
      message = errorText(error)
      return false
    }
    return commit(next, publish: true)
  }
  func saveToday(opens: WallTime, closes: WallTime, replacing original: EatingWindow? = nil) -> Bool {
    if let original, engine.window(on: now) != original {
      message = String(localized: .scheduleChangedWhileEditing)
      return false
    }
    guard opens != closes, let opening = opens.date(on: now, calendar: calendar),
      let closeDay = calendar.date(byAdding: .day, value: closes < opens ? 1 : 0, to: now),
      let closing = closes.date(on: closeDay, calendar: calendar)
    else {
      message = String(localized: .invalidTime)
      return false
    }
    var next = data
    let key = LocalDay.key(now, calendar: calendar)
    next.schedule.overrides.removeAll { $0.dayKey == key }
    next.schedule.overrides.append(
      DayOverride(
        dayKey: key, timeZoneID: calendar.timeZone.identifier, opening: opening, closing: closing,
        modifiedAt: Date()))
    next.schedule.revision = Date()
    do { try ScheduleEngine(snapshot: next.schedule, calendar: calendar).validate(near: now) } catch
    {
      message = errorText(error)
      return false
    }
    return commit(next, publish: true)
  }
  func removeTodayOverride() -> Bool {
    var next = data
    let key = LocalDay.key(now, calendar: calendar)
    for index in next.schedule.overrides.indices where next.schedule.overrides[index].dayKey == key
    {
      next.schedule.overrides[index].deleted = true
      next.schedule.overrides[index].modifiedAt = Date()
    }
    next.schedule.revision = Date()
    do { try ScheduleEngine(snapshot: next.schedule, calendar: calendar).validate(near: now) } catch
    {
      message = errorText(error)
      return false
    }
    return commit(next, publish: true)
  }
  @discardableResult func setEatingWindowOpen(_ isOpen: Bool) -> Bool {
    do {
      var next = data
      next.schedule = try engine.settingEatingWindowOpen(isOpen, at: now, modifiedAt: Date())
      return commit(next, publish: true)
    } catch {
      message = errorText(error)
      return false
    }
  }
  @discardableResult func undoEarlyBreak() -> Bool {
    do {
      var next = data
      next.schedule = try engine.undoingEarlyBreak(at: now, modifiedAt: Date())
      return commit(next, publish: true)
    } catch {
      message = errorText(error)
      return false
    }
  }
  @discardableResult func reflect(_ window: EatingWindow, feeling: DayFeeling?) -> Bool {
    let r = Reflection(
      dayKey: window.dayKey, timeZoneID: window.timeZoneID, feeling: feeling,
      opening: window.opening, closing: window.closing, updatedAt: now)
    var next = data
    next.reflections.removeAll { $0.id == r.id }
    next.reflections.append(r)
    return commit(next)
  }
  @discardableResult func editReflection(_ reflection: Reflection, feeling: DayFeeling) -> Bool {
    var next = data
    guard let index = next.reflections.firstIndex(where: { $0.id == reflection.id }) else {
      return false
    }
    next.reflections[index].feeling = feeling
    next.reflections[index].updatedAt = now
    return commit(next)
  }
  @discardableResult func deleteReflection(_ id: String) -> Bool {
    var next = data
    next.reflections.removeAll { $0.id == id }
    return commit(next)
  }
  func preferences(_ edit: (inout Preferences) -> Void) {
    var next = data
    edit(&next.preferences)
    commit(next, publish: true)
  }
  func setReminder(opening: Bool, enabled: Bool) async {
    if enabled && deviceServicesEnabled {
      do {
        guard try await reminders.requestAuthorization() else {
          notificationStatus = await reminders.status()
          message = String(localized: .remindersDenied)
          return
        }
      } catch {
        message = String(localized: .reminderFailure)
        return
      }
    }
    preferences {
      if opening { $0.openingReminder = enabled } else { $0.closingReminder = enabled }
    }
  }
  func refresh() async {
    if scenario == nil {
      notificationStatus = await reminders.status()
      await purchases.refreshEntitlements()
      updateSurfaces()
    }
  }
  func updateSurfaces() {
    guard deviceServicesEnabled else { return }
    do {
      let merged = try cloud.sync(data.schedule, enabled: data.preferences.cloudScheduleEnabled)
      if merged != data.schedule {
        var next = data
        next.schedule = merged
        guard commit(next) else { return }
      }
    } catch { message = String(localized: .cloudConflict) }
    let snapshot = data.schedule
    let preferences = data.preferences
    do {
      try SnapshotStore().write(snapshot.forDisplay(now: now, calendar: calendar))
      WidgetCenter.shared.reloadAllTimelines()
    } catch { message = String(localized: .widgetSaveFailed) }
    watch.publish(snapshot.forDisplay(now: now, calendar: calendar))
    let previous = derivedTask
    previous?.cancel()
    derivedTask = Task {
      await previous?.value
      guard !Task.isCancelled else { return }
      do {
        remindersThrough = try await reminders.reconcile(
          snapshot: snapshot, preferences: preferences)
        notificationStatus = await reminders.status()
      } catch { if !Task.isCancelled { message = String(localized: .reminderFailure) } }
      await reminders.scheduleRefresh()
    }
  }
  func connectHealth(write: Bool) async {
    guard scenario == nil else { return }
    do {
      try await health.authorize(write: write)
      preferences {
        $0.healthEnabled = true
        if write { $0.healthWritesEnabled = health.canWrite }
      }
      await refreshHealth()
    } catch { message = String(localized: .healthUnavailable) }
  }
  func addWeight(value: Double, date: Date) async -> Bool {
    let entry = WeightEntry(
      kilograms: data.preferences.weightUnit.kilograms(value), date: date,
      saveToHealth: data.preferences.healthWritesEnabled)
    guard entry.isValid, date <= now else {
      message = String(localized: .invalidWeight)
      return false
    }
    var next = data
    next.weights.append(entry)
    guard commit(next) else { return false }
    await refreshHealth()
    return true
  }
  func updateWeight(_ entry: WeightEntry, value: Double, date: Date) async -> Bool {
    guard let index = data.weights.firstIndex(where: { $0.id == entry.id }) else { return false }
    if entry.saveToHealth && (!data.preferences.healthWritesEnabled || !health.canWrite) {
      message = String(localized: .healthEditPermission)
      return false
    }
    var next = data
    next.weights[index].kilograms = data.preferences.weightUnit.kilograms(value)
    next.weights[index].date = date
    guard next.weights[index].isValid, date <= now else {
      message = String(localized: .invalidWeight)
      return false
    }
    next.weights[index].healthVersion += 1
    next.weights[index].healthNeedsUpdate = entry.saveToHealth
    guard commit(next) else { return false }
    await refreshHealth()
    return true
  }
  func deleteWeight(_ entry: WeightEntry) async {
    var next = data
    if entry.saveToHealth {
      guard let index = next.weights.firstIndex(where: { $0.id == entry.id }) else { return }
      next.weights[index].pendingDeletion = true
    } else {
      next.weights.removeAll { $0.id == entry.id }
    }
    if commit(next) { await refreshHealth() }
  }
  func refreshHealth() async {
    guard data.preferences.healthEnabled, !healthBusy, scenario == nil else { return }
    healthBusy = true
    defer { healthBusy = false }
    do {
      for entry in data.weights
      where entry.saveToHealth
        && (entry.healthSampleID == nil || entry.healthNeedsUpdate || entry.pendingDeletion)
      {
        if entry.pendingDeletion {
          try await health.delete(entry)
          var next = data
          next.weights.removeAll { $0.id == entry.id }
          guard commit(next) else { return }
        } else if data.preferences.healthWritesEnabled {
          let sampleID = try await health.save(entry)
          var next = data
          if let index = next.weights.firstIndex(where: { $0.id == entry.id }) {
            next.weights[index].healthSampleID = sampleID
            next.weights[index].healthNeedsUpdate = false
          }
          guard commit(next) else { return }
        }
      }
      let changes = try await health.changes(since: data.healthAnchor)
      let measurements = try await health.read()
      var next = data
      next.weights = WeightReconciliation.applying(changes.deletions, to: next.weights)
      next.healthAnchor = changes.anchor
      guard commit(next) else { return }
      healthWeights = measurements
    } catch { message = String(localized: .healthSyncFailed) }
  }
  func restore(_ imported: LocalData) -> Bool {
    do {
      var next = try imported.validated(now: now)
      next.schedule.revision = Date()
      next.schedule.resetAt = Date()
      let importedStamp = Date().addingTimeInterval(0.001)
      for index in next.schedule.versions.indices {
        next.schedule.versions[index].modifiedAt = importedStamp
        for day in next.schedule.versions[index].days.indices {
          next.schedule.versions[index].days[day].modifiedAt = importedStamp
        }
      }
      for index in next.schedule.overrides.indices {
        next.schedule.overrides[index].modifiedAt = importedStamp
      }
      next.healthAnchor = nil
      next.preferences.healthEnabled = false
      next.preferences.healthWritesEnabled = false
      next.preferences.openingReminder = false
      next.preferences.closingReminder = false
      // Recovery never automatically writes historical entries into Health.
      for index in next.weights.indices {
        next.weights[index].saveToHealth = false
        next.weights[index].pendingDeletion = false
        next.weights[index].healthNeedsUpdate = false
      }
      return commit(next, publish: true)
    } catch {
      message = String(localized: .importInvalid)
      return false
    }
  }
  func eraseLocalData() async -> Bool {
    var empty = LocalData()
    empty.schedule.revision = Date()
    empty.schedule.resetAt = empty.schedule.revision
    empty.preferences.cloudScheduleEnabled = data.preferences.cloudScheduleEnabled
    guard commit(empty, publish: true) else { return false }
    healthWeights = []
    await reminders.clear()
    selectedTab = .home
    return true
  }
  func errorText(_ error: Error) -> String {
    String(
      localized: (error as? ScheduleError) == .overlappingWindows
        ? .overlappingWindows : .invalidTime)
  }
}
