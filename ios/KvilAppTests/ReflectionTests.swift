import XCTest

@testable import KvilApp

@MainActor final class ReflectionTests: XCTestCase {
  private let oslo = LocalDay.calendar(timeZone: TimeZone(identifier: "Europe/Oslo")!)

  private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }

  private func unansweredModel() throws -> AppModel {
    let model = try AppModel(store: LocalStore(inMemory: true), scenario: "home")
    let yesterday = try XCTUnwrap(model.calendar.date(byAdding: .day, value: -1, to: model.now))
    let key = LocalDay.key(yesterday, calendar: model.calendar)
    var data = model.data
    data.reflections.removeAll { $0.dayKey == key }
    XCTAssertTrue(model.commit(data))
    return model
  }

  func testLegacyReflectionAndPreferencesDecodeWithoutInventingAnswers() throws {
    let opening = date("2026-09-11T08:00:00Z")
    let closing = date("2026-09-11T16:00:00Z")
    // This is the original on-disk shape, without any of the newly added fields.
    let oldReflection: [String: Any] = [
      "dayKey": "2026-09-11", "timeZoneID": "Europe/Oslo", "feeling": "mixed",
      "opening": opening.timeIntervalSinceReferenceDate,
      "closing": closing.timeIntervalSinceReferenceDate,
      "updatedAt": closing.timeIntervalSinceReferenceDate,
    ]
    let record = try JSONDecoder().decode(
      Reflection.self, from: JSONSerialization.data(withJSONObject: oldReflection))
    let preferences = try JSONDecoder().decode(
      Preferences.self,
      from: Data(
        #"{"cloudScheduleEnabled":true,"openingReminder":true,"closingReminder":false,"weightEnabled":true,"healthEnabled":false,"healthWritesEnabled":false,"weightUnit":"kg"}"#
          .utf8))
    XCTAssertEqual(record.feeling, .mixed)
    XCTAssertEqual(record.opening, opening)
    XCTAssertEqual(record.closing, closing)
    XCTAssertNil(record.planExperience)
    XCTAssertNil(record.firstMeal)
    XCTAssertNil(record.lastMeal)
    XCTAssertNil(record.note)
    XCTAssertNil(record.wasDayOff)
    XCTAssertTrue(record.isValid)
    XCTAssertTrue(record.hasAnswer)
    XCTAssertTrue(preferences.openingReminder)
    XCTAssertTrue(preferences.weightEnabled)
    XCTAssertNil(preferences.openingReminderLeadMinutes)
    XCTAssertNil(preferences.closingReminderLeadMinutes)
    XCTAssertNil(preferences.liveActivitiesEnabled)

    var legacy = LocalData(formatVersion: 1)
    legacy.reflections = [record]
    legacy.preferences = preferences
    let store = try LocalStore(inMemory: true)
    try store.save(legacy)
    let restored = try store.load()
    XCTAssertEqual(restored.formatVersion, 2)
    XCTAssertEqual(restored.reflections, [record])
    XCTAssertEqual(restored.preferences, preferences)
  }

  func testAsPlannedPersistsReportedAnswerWithoutFabricatingMealTimes() throws {
    let model = try unansweredModel()
    let before = model.data
    var answer = try XCTUnwrap(model.yesterdayReflection)
    answer.planExperience = .asPlanned
    answer.feeling = .comfortable
    answer.note = "  Dinner with friends\n"
    XCTAssertTrue(model.saveReflection(answer))
    let saved = try XCTUnwrap(model.data.reflections.first { $0.id == answer.id })
    XCTAssertEqual(saved.planExperience, .asPlanned)
    XCTAssertEqual(saved.feeling, .comfortable)
    XCTAssertEqual(saved.note, "Dinner with friends")
    XCTAssertNil(saved.firstMeal)
    XCTAssertNil(saved.lastMeal)
    XCTAssertEqual(saved.opening, answer.opening)
    XCTAssertEqual(saved.closing, answer.closing)
    XCTAssertEqual(saved.updatedAt, model.now)
    XCTAssertEqual(model.data.schedule, before.schedule)
    XCTAssertEqual(model.data.weights, before.weights)
    XCTAssertEqual(try model.store.load(), model.data)
    XCTAssertNil(model.yesterdayReflection)

    let committed = model.data
    answer.firstMeal = answer.opening
    answer.lastMeal = answer.closing
    XCTAssertFalse(model.saveReflection(answer))
    XCTAssertEqual(model.data, committed)
    XCTAssertEqual(try model.store.load(), committed)
  }

  func testChangedDayAcceptsApproximateMealsAcrossMidnight() throws {
    let model = try unansweredModel()
    var answer = try XCTUnwrap(model.yesterdayReflection)
    let midnight = model.calendar.startOfDay(for: model.now)
    answer.planExperience = .changed
    answer.feeling = .mixed
    answer.firstMeal = midnight.addingTimeInterval(-1800)
    answer.lastMeal = midnight.addingTimeInterval(min(900, model.now.timeIntervalSince(midnight)))
    XCTAssertTrue(model.saveReflection(answer))
    let saved = try XCTUnwrap(model.data.reflections.first { $0.id == answer.id })
    XCTAssertEqual(saved.firstMeal, answer.firstMeal)
    XCTAssertEqual(saved.lastMeal, answer.lastMeal)
    XCTAssertFalse(
      model.calendar.isDate(
        try XCTUnwrap(saved.firstMeal), inSameDayAs: try XCTUnwrap(saved.lastMeal)))
    XCTAssertEqual(try model.store.load(), model.data)
  }

  func testMealDateValidationUsesLocalDaysAcrossDSTAndYearBoundary() throws {
    for (key, reviewedAt) in [
      ("2026-03-28", "2026-03-29T08:00:00Z"),
      ("2026-10-24", "2026-10-25T08:00:00Z"),
      ("2026-12-31", "2027-01-01T08:00:00Z"),
    ] {
      let day = try XCTUnwrap(LocalDay.date(key, calendar: oslo))
      let next = try XCTUnwrap(oslo.date(byAdding: .day, value: 1, to: day))
      let end = try XCTUnwrap(oslo.date(byAdding: .day, value: 2, to: day))
      let opening = try XCTUnwrap(WallTime(hour: 10).date(on: day, calendar: oslo))
      let closing = try XCTUnwrap(WallTime(hour: 18).date(on: day, calendar: oslo))
      var answer = Reflection(
        dayKey: key, timeZoneID: oslo.timeZone.identifier, feeling: .mixed,
        opening: opening, closing: closing, updatedAt: date(reviewedAt), planExperience: .changed,
        firstMeal: WallTime(hour: 22, minute: 15).date(on: day, calendar: oslo),
        lastMeal: WallTime(hour: 3, minute: 15).date(on: next, calendar: oslo))
      XCTAssertTrue(answer.isValid, key)
      let good = answer
      answer.firstMeal = day.addingTimeInterval(-1)
      XCTAssertFalse(answer.isValid, key)
      answer = good
      answer.firstMeal = WallTime(hour: 1).date(on: next, calendar: oslo)
      XCTAssertFalse(answer.isValid, "The first meal belongs to the reported day: \(key)")
      answer = good
      answer.lastMeal = end
      answer.updatedAt = end
      XCTAssertFalse(answer.isValid, key)
      answer = good
      answer.lastMeal = answer.firstMeal
      XCTAssertTrue(answer.isValid, "A single reported meal is valid: \(key)")
    }
  }

  func testInvalidMealEditsAndFutureAnswersLeaveSavedDataUntouched() throws {
    let model = try unansweredModel()
    var answer = try XCTUnwrap(model.yesterdayReflection)
    answer.planExperience = .changed
    answer.feeling = .difficult
    answer.firstMeal = answer.opening
    answer.lastMeal = answer.closing
    XCTAssertTrue(model.saveReflection(answer))
    let saved = model.data
    var invalid = answer
    invalid.lastMeal = nil
    XCTAssertFalse(model.saveReflection(invalid))
    invalid = answer
    invalid.lastMeal = try XCTUnwrap(invalid.firstMeal).addingTimeInterval(-1)
    XCTAssertFalse(model.saveReflection(invalid))
    invalid = answer
    invalid.lastMeal = model.now.addingTimeInterval(60)
    invalid.updatedAt = model.now.addingTimeInterval(3600)
    XCTAssertFalse(model.saveReflection(invalid), "A caller cannot supply a future review time")
    invalid = answer
    invalid.firstMeal = Date(timeIntervalSince1970: .infinity)
    XCTAssertFalse(model.saveReflection(invalid))
    XCTAssertEqual(model.data, saved)
    XCTAssertEqual(try model.store.load(), saved)

    let tomorrow = try XCTUnwrap(model.calendar.date(byAdding: .day, value: 1, to: model.now))
    let futureWindow = try XCTUnwrap(model.engine.window(on: tomorrow))
    let future = Reflection(
      dayKey: futureWindow.dayKey, timeZoneID: futureWindow.timeZoneID, feeling: .comfortable,
      opening: futureWindow.opening, closing: futureWindow.closing, updatedAt: model.now,
      planExperience: .asPlanned)
    XCTAssertFalse(model.saveReflection(future))
    XCTAssertEqual(model.data, saved)
    XCTAssertEqual(try model.store.load(), saved)
  }

  func testNotesAreTrimmedAndBoundedWithoutTruncatingSavedText() throws {
    let model = try unansweredModel()
    var answer = try XCTUnwrap(model.yesterdayReflection)
    answer.planExperience = .unsure
    answer.feeling = .mixed
    let limit = String(repeating: "ø", count: 1000)
    answer.note = " \n" + limit + "\n "
    XCTAssertTrue(model.saveReflection(answer))
    XCTAssertEqual(model.data.reflections.first { $0.id == answer.id }?.note, limit)
    let saved = model.data
    answer.note = limit + "ø"
    XCTAssertFalse(model.saveReflection(answer))
    XCTAssertEqual(model.data, saved)
    XCTAssertEqual(try model.store.load(), saved)
    answer.note = " \n\t "
    XCTAssertTrue(model.saveReflection(answer))
    XCTAssertNil(model.data.reflections.first { $0.id == answer.id }?.note)
    XCTAssertNil(model.data.reflections.first { $0.id == answer.id }?.firstMeal)
    XCTAssertNil(model.data.reflections.first { $0.id == answer.id }?.lastMeal)
  }

  func testOfferIsYesterdayOnlyAndAnUnansweredDraftDoesNotChangeStorage() throws {
    let model = try unansweredModel()
    let saved = model.data
    let original = try XCTUnwrap(model.yesterdayReflection)
    let yesterday = try XCTUnwrap(model.calendar.date(byAdding: .day, value: -1, to: model.now))
    XCTAssertEqual(original.dayKey, LocalDay.key(yesterday, calendar: model.calendar))
    var canceledDraft = original
    canceledDraft.planExperience = .changed
    canceledDraft.firstMeal = original.opening
    canceledDraft.lastMeal = original.closing
    canceledDraft.note = "Unfinished thought"
    // A sheet edits a value copy. Reading the offer and abandoning that copy is not a save.
    _ = ReflectionFlowView(reflection: canceledDraft)
    XCTAssertEqual(model.data, saved)
    XCTAssertEqual(try model.store.load(), saved)
    XCTAssertEqual(model.yesterdayReflection, original)
    XCTAssertFalse(model.saveReflection(original), "An empty draft is not an answer")
    XCTAssertEqual(try model.store.load(), saved)

    var answered = original
    answered.feeling = .comfortable
    XCTAssertTrue(model.saveReflection(answered))
    var missingOlderDays = model.data
    missingOlderDays.reflections.removeAll { $0.dayKey != original.dayKey }
    XCTAssertTrue(model.commit(missingOlderDays))
    XCTAssertNil(
      model.yesterdayReflection, "Do not replace yesterday with an older missing check-in")
  }

  func testYesterdayIsNotOfferedBeforeAnOvernightWindowHasClosed() throws {
    let model = try unansweredModel()
    var data = model.data
    let later = model.now.addingTimeInterval(60)
    let closing = WallTime(
      hour: model.calendar.component(.hour, from: later),
      minute: model.calendar.component(.minute, from: later))
    let opening = WallTime(hour: 23, minute: 59)
    XCTAssertLessThan(closing, opening)
    for version in data.schedule.versions.indices {
      data.schedule.versions[version].days = (1...7).map {
        DayPlan(weekday: $0, opens: opening, closes: closing)
      }
    }
    XCTAssertTrue(model.commit(data))
    XCTAssertNil(model.yesterdayReflection)
  }

  func testDayOffOfferStoresFeelingWithoutPlanOrMealClaims() throws {
    let model = try unansweredModel()
    let yesterday = try XCTUnwrap(model.calendar.date(byAdding: .day, value: -1, to: model.now))
    var data = model.data
    data.schedule.schema = 2
    data.schedule.breaks = [
      ScheduleBreak(
        startDay: LocalDay.key(yesterday, calendar: model.calendar),
        resumeDay: LocalDay.key(model.now, calendar: model.calendar), modifiedAt: model.now)
    ]
    XCTAssertTrue(model.commit(data))
    var answer = try XCTUnwrap(model.yesterdayReflection)
    XCTAssertEqual(answer.wasDayOff, true)
    XCTAssertNil(answer.planExperience)
    XCTAssertNil(answer.firstMeal)
    XCTAssertNil(answer.lastMeal)
    XCTAssertEqual(answer.opening, model.calendar.startOfDay(for: yesterday))
    XCTAssertEqual(answer.closing, model.calendar.startOfDay(for: model.now))
    answer.feeling = .comfortable
    XCTAssertTrue(model.saveReflection(answer))
    let saved = model.data
    answer.planExperience = .asPlanned
    XCTAssertFalse(model.saveReflection(answer))
    XCTAssertEqual(model.data, saved)
    XCTAssertEqual(try model.store.load(), saved)
    XCTAssertNil(model.yesterdayReflection)
  }

  func testFirstLaunchDoesNotInventAYesterdayPlan() throws {
    let model = try AppModel(store: LocalStore(inMemory: true), scenario: "onboarding")
    XCTAssertNil(model.yesterdayReflection)
    XCTAssertTrue(model.configure(days: DayPlan.initial))
    XCTAssertNil(model.yesterdayReflection)
  }

  func testImportRejectsIncompleteMealsAndUnsupportedReminderLeadsAtomically() throws {
    let model = try unansweredModel()
    var answer = try XCTUnwrap(model.yesterdayReflection)
    answer.planExperience = .changed
    answer.feeling = .mixed
    answer.firstMeal = answer.opening
    answer.lastMeal = answer.closing
    XCTAssertTrue(model.saveReflection(answer))
    let saved = model.data
    let index = try XCTUnwrap(saved.reflections.firstIndex { $0.id == answer.id })
    var invalid = saved
    invalid.reflections[index].lastMeal = nil
    XCTAssertThrowsError(try invalid.validated())
    XCTAssertThrowsError(try model.store.save(invalid))
    invalid = saved
    invalid.reflections[index].note = String(repeating: "x", count: 1001)
    XCTAssertThrowsError(try invalid.validated())
    XCTAssertThrowsError(try model.store.save(invalid))
    for lead in [-15, 1, 60] {
      invalid = saved
      invalid.preferences.openingReminderLeadMinutes = lead
      XCTAssertThrowsError(try invalid.validated())
      invalid = saved
      invalid.preferences.closingReminderLeadMinutes = lead
      XCTAssertThrowsError(try model.store.save(invalid))
    }
    XCTAssertEqual(try model.store.load(), saved)
  }
}
