import Foundation

extension AppModel {
  var upcomingScheduleBreaks: [ScheduleBreak] {
    let today = LocalDay.key(now, calendar: calendar)
    return (data.schedule.breaks ?? []).filter {
      $0.deleted != true && $0.resumeDay > today
    }.sorted {
      $0.startDay == $1.startDay ? $0.id.uuidString < $1.id.uuidString : $0.startDay < $1.startDay
    }
  }

  @discardableResult func takeTodayOff() -> Bool {
    guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else { return false }
    return scheduleBreak(from: now, resuming: tomorrow)
  }

  @discardableResult func scheduleBreak(from start: Date, resuming resume: Date) -> Bool {
    do {
      var next = data
      next.schedule = try engine.takingBreak(
        from: start, resuming: resume, at: now, modifiedAt: Date())
      return commit(next, publish: true)
    } catch {
      message = errorText(error)
      return false
    }
  }

  @discardableResult func endScheduleBreak(_ item: ScheduleBreak) -> Bool {
    guard data.schedule.breaks?.first(where: { $0.id == item.id }) == item else {
      message = String(localized: .scheduleChangedWhileEditing)
      return false
    }
    do {
      var next = data
      next.schedule = try engine.endingBreak(item.id, at: now, modifiedAt: Date())
      return commit(next, publish: true)
    } catch {
      message = errorText(error)
      return false
    }
  }

  @discardableResult func resumeSchedule() -> Bool {
    do {
      var next = data
      let key = LocalDay.key(now, calendar: calendar)
      for item in upcomingScheduleBreaks where item.contains(key) {
        let updated = ScheduleEngine(snapshot: next.schedule, calendar: calendar)
        next.schedule = try updated.endingBreak(item.id, at: now, modifiedAt: Date())
      }
      return commit(next, publish: true)
    } catch {
      message = errorText(error)
      return false
    }
  }
}
