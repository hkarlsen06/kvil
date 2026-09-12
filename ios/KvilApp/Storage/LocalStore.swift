import Foundation
import SwiftData

@Model final class StoredSchedule {
  @Attribute(.unique) var id: UUID
  var effectiveDay: String
  var payload: Data
  init(_ value: ScheduleVersion) throws {
    id = value.id
    effectiveDay = value.effectiveDay
    payload = try JSONEncoder().encode(value)
  }
}
@Model final class StoredOverride {
  @Attribute(.unique) var id: String
  var payload: Data
  init(_ value: DayOverride) throws {
    id = value.id
    payload = try JSONEncoder().encode(value)
  }
}
@Model final class StoredReflection {
  @Attribute(.unique) var id: String
  var payload: Data
  init(_ value: Reflection) throws {
    id = value.id
    payload = try JSONEncoder().encode(value)
  }
}
@Model final class StoredWeight {
  @Attribute(.unique) var id: UUID
  var payload: Data
  init(_ value: WeightEntry) throws {
    id = value.id
    payload = try JSONEncoder().encode(value)
  }
}
@Model final class StoredSettings {
  @Attribute(.unique) var id: String
  var payload: Data
  var revision: Date
  var resetAt: Date?
  var healthAnchor: Data?
  init(_ value: Preferences, revision: Date) throws {
    id = "preferences"
    payload = try JSONEncoder().encode(value)
    self.revision = revision
  }
}

struct LocalData: Codable, Equatable {
  var formatVersion = 1
  var schedule: ScheduleSnapshot = .empty
  var reflections: [Reflection] = []
  var weights: [WeightEntry] = []
  var preferences = Preferences()
  var healthAnchor: Data?

  func validated(now: Date = Date()) throws -> Self {
    guard formatVersion == 1, reflections.count <= 100_000, weights.count <= 100_000,
      schedule.versions.count <= 10_000, schedule.overrides.count <= 10_000
    else { throw ScheduleError.incompatibleData }
    if !schedule.versions.isEmpty {
      try ScheduleEngine(snapshot: schedule, calendar: LocalDay.calendar()).validate(near: now)
    }
    guard Set(reflections.map(\.id)).count == reflections.count,
      Set(weights.map(\.id)).count == weights.count,
      weights.allSatisfy(\.isValid)
    else { throw ScheduleError.incompatibleData }
    for r in reflections {
      guard let zone = TimeZone(identifier: r.timeZoneID),
        LocalDay.date(r.dayKey, calendar: LocalDay.calendar(timeZone: zone)) != nil,
        r.closing > r.opening, r.updatedAt.timeIntervalSince1970.isFinite
      else { throw ScheduleError.incompatibleData }
    }
    var result = self
    result.schedule.versions.sort { $0.effectiveDay < $1.effectiveDay }
    result.schedule.overrides.sort { $0.id < $1.id }
    result.reflections.sort { $0.id > $1.id }
    result.weights.sort {
      $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date > $1.date
    }
    return result
  }
}

@MainActor final class LocalStore {
  let container: ModelContainer
  let isInMemory: Bool
  private let context: ModelContext
  init(inMemory: Bool = false, directory: URL? = nil) throws {
    isInMemory = inMemory
    let schema = Schema([
      StoredSchedule.self, StoredOverride.self, StoredReflection.self, StoredWeight.self,
      StoredSettings.self,
    ])
    let configuration: ModelConfiguration
    if inMemory {
      configuration = ModelConfiguration(
        schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    } else {
      var folder =
        directory
        ?? URL.applicationSupportDirectory.appendingPathComponent("Kvil", isDirectory: true)
      try FileManager.default.createDirectory(
        at: folder, withIntermediateDirectories: true,
        attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try folder.setResourceValues(values)
      configuration = ModelConfiguration(
        schema: schema, url: folder.appendingPathComponent("Kvil.store"), cloudKitDatabase: .none)
    }
    container = try ModelContainer(for: schema, configurations: [configuration])
    context = ModelContext(container)
    context.autosaveEnabled = false
  }

  func load() throws -> LocalData {
    let decoder = JSONDecoder()
    let settings = try context.fetch(FetchDescriptor<StoredSettings>()).first
    return try LocalData(
      schedule: ScheduleSnapshot(
        revision: settings?.revision ?? .distantPast,
        versions: context.fetch(FetchDescriptor<StoredSchedule>()).map {
          try decoder.decode(ScheduleVersion.self, from: $0.payload)
        },
        overrides: context.fetch(FetchDescriptor<StoredOverride>()).map {
          try decoder.decode(DayOverride.self, from: $0.payload)
        }, resetAt: settings?.resetAt),
      reflections: context.fetch(FetchDescriptor<StoredReflection>()).map {
        try decoder.decode(Reflection.self, from: $0.payload)
      },
      weights: context.fetch(FetchDescriptor<StoredWeight>()).map {
        try decoder.decode(WeightEntry.self, from: $0.payload)
      },
      preferences: settings.map { try decoder.decode(Preferences.self, from: $0.payload) }
        ?? Preferences(), healthAnchor: settings?.healthAnchor
    ).validated()
  }

  func save(_ input: LocalData) throws {
    let value = try input.validated()
    do {
      let schedules = try context.fetch(FetchDescriptor<StoredSchedule>())
      let schedulesByID = Dictionary(uniqueKeysWithValues: schedules.map { ($0.id, $0) })
      let desiredStoredScheduleIDs = Set(value.schedule.versions.map(\.id))
      for row in schedules where !desiredStoredScheduleIDs.contains(row.id) { context.delete(row) }
      for item in value.schedule.versions {
        if let row = schedulesByID[item.id] {
          row.payload = try JSONEncoder().encode(item)
          row.effectiveDay = item.effectiveDay
        } else {
          context.insert(try StoredSchedule(item))
        }
      }
      let overrides = try context.fetch(FetchDescriptor<StoredOverride>())
      let overridesByID = Dictionary(uniqueKeysWithValues: overrides.map { ($0.id, $0) })
      let desiredStoredOverrideIDs = Set(value.schedule.overrides.map(\.id))
      for row in overrides where !desiredStoredOverrideIDs.contains(row.id) { context.delete(row) }
      for item in value.schedule.overrides {
        if let row = overridesByID[item.id] {
          row.payload = try JSONEncoder().encode(item)
        } else {
          context.insert(try StoredOverride(item))
        }
      }
      let reflections = try context.fetch(FetchDescriptor<StoredReflection>())
      let reflectionsByID = Dictionary(uniqueKeysWithValues: reflections.map { ($0.id, $0) })
      let desiredStoredReflectionIDs = Set(value.reflections.map(\.id))
      for row in reflections where !desiredStoredReflectionIDs.contains(row.id) {
        context.delete(row)
      }
      for item in value.reflections {
        if let row = reflectionsByID[item.id] {
          row.payload = try JSONEncoder().encode(item)
        } else {
          context.insert(try StoredReflection(item))
        }
      }
      let weights = try context.fetch(FetchDescriptor<StoredWeight>())
      let weightsByID = Dictionary(uniqueKeysWithValues: weights.map { ($0.id, $0) })
      let desiredStoredWeightIDs = Set(value.weights.map(\.id))
      for row in weights where !desiredStoredWeightIDs.contains(row.id) { context.delete(row) }
      for item in value.weights {
        if let row = weightsByID[item.id] {
          row.payload = try JSONEncoder().encode(item)
        } else {
          context.insert(try StoredWeight(item))
        }
      }
      if let settings = try context.fetch(FetchDescriptor<StoredSettings>()).first {
        settings.payload = try JSONEncoder().encode(value.preferences)
        settings.revision = value.schedule.revision
        settings.resetAt = value.schedule.resetAt
        settings.healthAnchor = value.healthAnchor
      } else {
        let row = try StoredSettings(value.preferences, revision: value.schedule.revision)
        row.resetAt = value.schedule.resetAt
        row.healthAnchor = value.healthAnchor
        context.insert(row)
      }
      try context.save()
    } catch {
      context.rollback()
      throw error
    }
  }
}
