import SwiftUI

extension PlanExperience {
  var title: LocalizedStringResource {
    switch self {
    case .asPlanned: .reflectionAsPlanned
    case .changed: .reflectionPlanChanged
    case .unsure: .reflectionNotSure
    }
  }
}

struct ReflectionFlowView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var typeSize
  @AccessibilityFocusState private var questionFocused: Bool
  private enum Step { case plan, meals, feeling }
  let reflection: Reflection
  @State private var draft: Reflection
  @State private var step: Step
  @State private var first: WallTime
  @State private var last: WallTime
  @State private var note: String
  @State private var showingNote: Bool
  @State private var validation: String?

  init(reflection: Reflection) {
    self.reflection = reflection
    _draft = State(initialValue: reflection)
    _step = State(initialValue: reflection.wasDayOff == true ? .feeling : .plan)
    let calendar = LocalDay.calendar(
      timeZone: TimeZone(identifier: reflection.timeZoneID) ?? .current)
    let firstDate = reflection.firstMeal ?? reflection.opening
    let lastDate = reflection.lastMeal ?? reflection.closing
    _first = State(
      initialValue: WallTime(
        hour: calendar.component(.hour, from: firstDate),
        minute: calendar.component(.minute, from: firstDate)))
    _last = State(
      initialValue: WallTime(
        hour: calendar.component(.hour, from: lastDate),
        minute: calendar.component(.minute, from: lastDate)))
    _note = State(initialValue: reflection.note ?? "")
    _showingNote = State(initialValue: reflection.note?.isEmpty == false)
  }

  private var calendar: Calendar {
    LocalDay.calendar(timeZone: TimeZone(identifier: reflection.timeZoneID) ?? .current)
  }
  private var question: LocalizedStringResource {
    switch step {
    case .plan:
      if let yesterday = calendar.date(byAdding: .day, value: -1, to: model.now),
        LocalDay.key(yesterday, calendar: calendar) == reflection.dayKey
      {
        .didYesterdayGoAsPlanned
      } else {
        .didThatDayGoAsPlanned
      }
    case .meals: .whenDidYouEat
    case .feeling: .howDidTheDayFeel
    }
  }

  var body: some View {
    NavigationStack {
      KvilActionPage(showsActions: step != .plan) {
        VStack(alignment: .leading, spacing: KvilStyle.content) {
          Text(
            LocalDay.date(reflection.dayKey, calendar: calendar) ?? reflection.opening,
            format: .dateTime.weekday(.wide).month(.abbreviated).day()
          )
          .font(.subheadline).foregroundStyle(Color.kvilSecondary)
          Text(question).font(KvilStyle.title).fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader).accessibilityFocused($questionFocused)
            .accessibilityIdentifier("reflectionQuestion")
        }
        Group {
          switch step {
          case .plan: planStep
          case .meals: mealsStep
          case .feeling: feelingStep
          }
        }.id(step).transition(.opacity)
        if let validation {
          Text(validation).font(.footnote).foregroundStyle(Color.kvilWarning)
            .accessibilityIdentifier("reflectionValidation")
        }
      } actions: {
        if step == .meals {
          Button(.continueReflection) { acceptMeals() }.buttonStyle(KvilPrimaryButtonStyle())
            .accessibilityIdentifier("confirmMealTimes")
          Button(.dontRememberMealTimes) {
            draft.firstMeal = nil
            draft.lastMeal = nil
            show(.feeling)
          }.frame(minHeight: 44).accessibilityIdentifier("skipMealTimes")
        } else if step == .feeling {
          Button(.saveReflection) { save() }.buttonStyle(KvilPrimaryButtonStyle())
            .disabled(draft.feeling == nil).accessibilityIdentifier("saveReflection")
        }
        if step != .plan && reflection.wasDayOff != true {
          Button(.back) {
            show(step == .feeling && draft.planExperience != .asPlanned ? .meals : .plan)
          }.frame(minHeight: 44).accessibilityIdentifier("reflectionBack")
        }
      }
      .id(step)
      .navigationTitle(.yourReflections).navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(.cancel) { dismiss() }.accessibilityIdentifier("cancelReflection")
        }
      }
      .task(id: step) {
        try? await Task.sleep(for: .milliseconds(250))
        guard !Task.isCancelled else { return }
        questionFocused = true
      }
    }.tint(Color.kvilAccent).environment(\.timeZone, calendar.timeZone)
  }

  private var planStep: some View {
    VStack(alignment: .leading, spacing: KvilStyle.content) {
      VStack(alignment: .leading, spacing: 6) {
        Text(.plannedEatingWindow).font(.footnote).foregroundStyle(Color.kvilSecondary)
        ReflectionTimeRange(opening: reflection.opening, closing: reflection.closing)
          .font(.title3).monospacedDigit()
      }.padding(.bottom, KvilStyle.related)
      Text(.reflectionPlanHelp).font(.subheadline).foregroundStyle(Color.kvilSecondary)
      ForEach(PlanExperience.allCases, id: \.self) { answer in
        Button {
          draft.planExperience = answer
          if answer == .asPlanned {
            draft.firstMeal = nil
            draft.lastMeal = nil
          }
          show(answer == .asPlanned ? .feeling : .meals)
        } label: {
          HStack {
            Text(answer.title).font(.body.weight(.medium))
            Spacer()
            Image(systemName: "chevron.right").font(.footnote)
          }.padding(KvilStyle.cardPadding).frame(minHeight: 52)
            .background(Color.kvilSurface, in: RoundedRectangle(cornerRadius: KvilStyle.corner))
            .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier("planExperience.\(answer.rawValue)")
      }
    }
  }

  private var mealsStep: some View {
    VStack(alignment: .leading, spacing: KvilStyle.content) {
      Text(.approximateMealsHelp).foregroundStyle(Color.kvilSecondary)
      ViewThatFits(in: .horizontal) {
        if !typeSize.isAccessibilitySize {
          HStack(spacing: KvilStyle.related) { mealWheels }.fixedSize(
            horizontal: true, vertical: false)
        }
        VStack(spacing: KvilStyle.content) { mealWheels }
      }.frame(maxWidth: .infinity).padding(KvilStyle.content)
        .background(Color.kvilSurface, in: RoundedRectangle(cornerRadius: KvilStyle.corner))
      if last < first {
        Label(.lastMealAfterMidnight, systemImage: "moon").font(.footnote)
          .foregroundStyle(Color.kvilSecondary)
      }
    }
  }

  @ViewBuilder private var mealWheels: some View {
    KvilTimeWheel(title: .firstMeal, time: $first).accessibilityIdentifier("firstMealTime")
    KvilTimeWheel(title: .lastMeal, time: $last).accessibilityIdentifier("lastMealTime")
  }

  private var feelingStep: some View {
    VStack(alignment: .leading, spacing: KvilStyle.content) {
      if reflection.wasDayOff == true {
        Text(.reflectionDayOffHelp).foregroundStyle(Color.kvilSecondary)
      }
      ForEach(DayFeeling.allCases, id: \.self) { feeling in
        Button {
          draft.feeling = feeling
        } label: {
          Group {
            if typeSize.isAccessibilitySize {
              VStack(alignment: .leading, spacing: KvilStyle.related) {
                HStack {
                  Image(systemName: feeling.symbol)
                  Spacer()
                  Image(systemName: draft.feeling == feeling ? "checkmark.circle.fill" : "circle")
                }.accessibilityHidden(true)
                Text(feeling.title).fixedSize(horizontal: false, vertical: true)
              }
            } else {
              HStack(spacing: KvilStyle.content) {
                Label(feeling.title, systemImage: feeling.symbol)
                Spacer()
                Image(systemName: draft.feeling == feeling ? "checkmark.circle.fill" : "circle")
                  .accessibilityHidden(true)
              }
            }
          }.padding(KvilStyle.cardPadding).frame(minHeight: 52)
            .background(Color.kvilSurface, in: RoundedRectangle(cornerRadius: KvilStyle.corner))
            .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier("feeling.\(feeling.rawValue)")
          .accessibilityAddTraits(draft.feeling == feeling ? .isSelected : [])
      }
      DisclosureGroup(.addReflectionNote, isExpanded: $showingNote) {
        TextField(.reflectionNotePrompt, text: $note, axis: .vertical)
          .lineLimit(3...6).padding(.vertical, 10)
          .accessibilityIdentifier("reflectionNote")
      }.padding(.top, KvilStyle.related)
    }
  }

  private func show(_ next: Step) {
    validation = nil
    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { step = next }
  }

  private func acceptMeals() {
    guard let day = LocalDay.date(reflection.dayKey, calendar: calendar),
      let firstDate = first.date(on: day, calendar: calendar),
      let lastDay = calendar.date(byAdding: .day, value: last < first ? 1 : 0, to: day),
      let lastDate = last.date(on: lastDay, calendar: calendar), lastDate <= model.now,
      lastDate >= firstDate
    else {
      validation = String(localized: .reflectionMealTimesInvalid)
      return
    }
    draft.firstMeal = firstDate
    draft.lastMeal = lastDate
    show(.feeling)
  }

  private func save() {
    draft.note = note
    if model.saveReflection(draft) {
      dismiss()
    } else {
      validation = model.message
      model.message = nil
    }
  }
}

struct ReflectionTimeRange: View {
  @Environment(\.timeZone) private var timeZone
  let opening: Date
  let closing: Date
  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 6) { times }
      VStack(alignment: .leading, spacing: 6) { times }
    }
  }
  @ViewBuilder private var times: some View {
    Text(opening, format: .dateTime.hour().minute())
    Image(systemName: "arrow.right").font(.caption).accessibilityHidden(true)
    Text(closing, format: .dateTime.hour().minute())
    if !LocalDay.calendar(timeZone: timeZone).isDate(opening, inSameDayAs: closing) {
      Text(.nextDayShort).font(.caption).foregroundStyle(Color.kvilSecondary)
    }
  }
}
