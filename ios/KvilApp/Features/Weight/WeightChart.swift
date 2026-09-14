import Charts
import SwiftUI

struct WeightChart: View {
  @Environment(\.dynamicTypeSize) private var typeSize
  let records: [DisplayWeight]
  let unit: WeightUnit

  var body: some View {
    Chart(records.sorted { $0.date < $1.date }) { record in
      LineMark(
        x: .value(String(localized: .date), record.date),
        y: .value(unit.rawValue, unit.display(record.kg))
      )
      .foregroundStyle(Color.kvilAccent).interpolationMethod(.linear)
      PointMark(
        x: .value(String(localized: .date), record.date),
        y: .value(unit.rawValue, unit.display(record.kg))
      ).foregroundStyle(Color.kvilAccent)
    }
    .chartXAxis {
      if typeSize.isAccessibilitySize {
        AxisMarks(values: .automatic(desiredCount: 2)) { value in
          AxisGridLine()
          AxisValueLabel {
            if let date = value.as(Date.self) {
              Text(date, format: .dateTime.day().month(.abbreviated).year(.twoDigits))
                .fixedSize(horizontal: false, vertical: true)
            }
          }
        }
      } else {
        AxisMarks()
      }
    }
    .chartYScale(domain: .automatic(includesZero: false))
    .chartYAxisLabel(unit.rawValue)
    .frame(height: typeSize.isAccessibilitySize ? 300 : 170)
  }
}
