import SwiftUI

struct KvilTimeWheel: View {
  @Environment(\.locale) private var locale
  var title: LocalizedStringResource
  @Binding var time: WallTime

  private var uses12HourClock: Bool {
    DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: locale)?.contains("a") == true
  }
  private var periodSymbols: [String] {
    let formatter = DateFormatter()
    formatter.locale = locale
    return [formatter.amSymbol, formatter.pmSymbol]
  }

  var body: some View {
    VStack(spacing: 0) {
      Text(title).font(.footnote).foregroundStyle(Color.kvilSecondary)
        .fixedSize(horizontal: false, vertical: true).accessibilityHidden(true)
      GeometryReader { geometry in
        let columnWidth = geometry.size.width / (uses12HourClock ? 3 : 2)
        HStack(spacing: 0) {
          Picker(.clockHour, selection: hour) {
            ForEach(uses12HourClock ? 1...12 : 0...23, id: \.self) { value in
              Text(verbatim: uses12HourClock ? String(value) : String(format: "%02d", value))
                .tag(value)
            }
          }.frame(width: columnWidth).clipped().contentShape(Rectangle())
          Picker(.clockMinute, selection: minute) {
            ForEach(0...59, id: \.self) { value in
              Text(verbatim: String(format: "%02d", value)).tag(value)
            }
          }.frame(width: columnWidth).clipped().contentShape(Rectangle())
          if uses12HourClock {
            Picker(.clockPeriod, selection: period) {
              Text(verbatim: periodSymbols[0]).tag(false)
              Text(verbatim: periodSymbols[1]).tag(true)
            }.frame(width: columnWidth).clipped().contentShape(Rectangle())
          }
        }.pickerStyle(.wheel).labelsHidden().frame(height: 132).clipped()
      }.frame(minWidth: uses12HourClock ? 216 : 144, idealWidth: uses12HourClock ? 216 : 144).frame(
        height: 132)
    }.accessibilityElement(children: .contain).accessibilityLabel(title)
  }

  // Edit wall-clock components directly so neither time zones nor DST can shift another day.
  private var hour: Binding<Int> {
    Binding {
      uses12HourClock ? (time.hour % 12 == 0 ? 12 : time.hour % 12) : time.hour
    } set: { value in
      let hour = uses12HourClock ? value % 12 + (time.hour >= 12 ? 12 : 0) : value
      time = WallTime(hour: hour, minute: time.minuteComponent)
    }
  }
  private var minute: Binding<Int> {
    Binding {
      time.minuteComponent
    } set: {
      time = WallTime(hour: time.hour, minute: $0)
    }
  }
  private var period: Binding<Bool> {
    Binding {
      time.hour >= 12
    } set: { value in
      time = WallTime(hour: time.hour % 12 + (value ? 12 : 0), minute: time.minuteComponent)
    }
  }
}

/// Keeps actions near the bottom when content fits, and scrolls the whole page when it doesn't.
struct KvilActionPage<Content: View, Actions: View>: View {
  @ViewBuilder var content: Content
  @ViewBuilder var actions: Actions

  var body: some View {
    GeometryReader { geometry in
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          VStack(alignment: .leading, spacing: KvilStyle.section) {
            content
          }
          Spacer(minLength: KvilStyle.section)
          VStack(spacing: KvilStyle.related) {
            actions
          }
        }
        .padding(KvilStyle.page)
        .frame(minHeight: geometry.size.height, alignment: .top)
      }.scrollIndicators(.hidden)
    }.background(Color.kvilCanvas)
  }
}

struct KvilControlRow<Control: View>: View {
  var title: LocalizedStringResource
  @ViewBuilder var control: Control

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: KvilStyle.related) {
        Text(title).fixedSize().accessibilityHidden(true)
        Spacer(minLength: 0)
        control.fixedSize()
      }
      VStack(alignment: .leading, spacing: KvilStyle.related) {
        Text(title).fixedSize(horizontal: false, vertical: true).accessibilityHidden(true)
        control
      }.frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

struct KvilDescribedToggle: View {
  var title: LocalizedStringResource
  var description: LocalizedStringResource
  @Binding var isOn: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: KvilStyle.related) {
      KvilControlRow(title: title) {
        Toggle(title, isOn: $isOn).labelsHidden()
          .accessibilityHint(Text(description))
      }
      Text(description).font(.footnote).foregroundStyle(Color.kvilSecondary)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityHidden(true)
    }
  }
}
