import SwiftUI

struct ScheduleBreakEditor: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @State private var starts = Date()
  @State private var resumes = Date()
  @State private var validation: String?

  private var earliestResume: Date {
    model.calendar.date(byAdding: .day, value: 1, to: starts) ?? starts
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Text(.scheduleBreakIntro).foregroundStyle(Color.kvilSecondary)
        }.listRowBackground(Color.clear)
        Section {
          DatePicker(
            .breakStarts, selection: $starts,
            in: model.calendar.startOfDay(for: model.now)..., displayedComponents: .date
          ).accessibilityIdentifier("breakStarts")
          DatePicker(
            .scheduleResumes, selection: $resumes, in: earliestResume...,
            displayedComponents: .date
          ).accessibilityIdentifier("breakResumes")
        } footer: {
          Text(.scheduleBreakLocalDates)
        }
        if let validation {
          Section { Text(validation).foregroundStyle(Color.kvilWarning) }
        }
      }.scrollContentBackground(.hidden).background(Color.kvilCanvas)
        .navigationTitle(.planScheduleBreak).navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button(.cancel) { dismiss() } }
          ToolbarItem(placement: .confirmationAction) {
            Button(.save) {
              if model.scheduleBreak(from: starts, resuming: resumes) {
                dismiss()
              } else {
                validation = model.message
                model.message = nil
              }
            }.fontWeight(.semibold).accessibilityIdentifier("saveScheduleBreak")
          }
        }
        .onAppear {
          starts = model.calendar.startOfDay(for: model.now)
          resumes = earliestResume
        }
        .onChange(of: starts) { _, _ in
          if resumes < earliestResume { resumes = earliestResume }
        }
    }.tint(Color.kvilAccent)
  }
}
