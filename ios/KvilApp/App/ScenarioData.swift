#if DEBUG
  import Foundation

  enum ScenarioData {
    static func make(
      now: Date, calendar: Calendar, openingSoon: Bool = false, closingSoon: Bool = false,
      progressReturn: Bool = false
    ) -> LocalData {
      var value = LocalData()
      value.schedule = ScheduleSnapshot(
        revision: now,
        versions: [ScheduleVersion(effectiveDay: "2026-08-01", days: DayPlan.initial)],
        overrides: [])
      if openingSoon || closingSoon || progressReturn {
        let opening = now.addingTimeInterval(closingSoon ? -3600 : progressReturn ? -10 : 20)
        value.schedule.overrides = [
          DayOverride(
            dayKey: LocalDay.key(opening, calendar: calendar),
            timeZoneID: calendar.timeZone.identifier, opening: opening,
            closing: closingSoon
              ? now.addingTimeInterval(20)
              : opening.addingTimeInterval(progressReturn ? 120 : 3600),
            modifiedAt: now)
        ]
      }
      let engine = ScheduleEngine(snapshot: value.schedule, calendar: calendar)
      for offset in 1...35 {
        guard offset % 6 != 0, let day = calendar.date(byAdding: .day, value: -offset, to: now),
          let w = engine.window(on: day)
        else { continue }
        value.reflections.append(
          Reflection(
            dayKey: w.dayKey, timeZoneID: w.timeZoneID,
            feeling: offset % 5 == 0 ? .difficult : offset % 3 == 0 ? .mixed : .comfortable,
            opening: w.opening, closing: w.closing, updatedAt: w.closing))
      }
      return value
    }
  }
#endif
