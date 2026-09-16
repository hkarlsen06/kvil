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

/// Keeps actions in the bottom safe area while the content scrolls underneath.
struct KvilActionPage<Content: View, Actions: View>: View {
  var showsActions = true
  @ViewBuilder var content: Content
  @ViewBuilder var actions: Actions

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: KvilStyle.section) {
        content
      }.padding(KvilStyle.page).frame(maxWidth: .infinity, alignment: .leading)
    }.scrollIndicators(.hidden)
      .safeAreaInset(edge: .bottom, spacing: 0) {
        if showsActions { KvilBottomActions { actions } }
      }
      .background(Color.kvilCanvas)
  }
}

struct KvilBottomActions<Actions: View>: View {
  @ViewBuilder var actions: Actions

  var body: some View {
    VStack(spacing: KvilStyle.related) {
      actions
    }.frame(maxWidth: .infinity)
      .padding(.horizontal, KvilStyle.page)
      .padding(.vertical, KvilStyle.related)
      .background {
        Color.kvilCanvas.opacity(0.9).background(.ultraThinMaterial).ignoresSafeArea(edges: .bottom)
      }
  }
}

#if os(iOS)
  struct KvilWindowLengthPicker: View {
    @Environment(\.locale) private var locale
    var title: LocalizedStringResource = .windowLength
    var selected: Int?
    var onSelect: (Int) -> Void

    var body: some View {
      Picker(
        title,
        selection: Binding<Int?>(
          get: { selected },
          set: { if let minutes = $0 { onSelect(minutes) } })
      ) {
        if selected == nil {
          Text(.differentWindowLengths).tag(nil as Int?).disabled(true)
        }
        if let selected, selected % 60 != 0 || selected < DayPlan.minimumWindowMinutes {
          Text(verbatim: duration(selected)).tag(Optional(selected))
            .disabled(selected < DayPlan.minimumWindowMinutes)
        }
        ForEach((DayPlan.minimumWindowMinutes / 60)..<24, id: \.self) { hours in
          Text(verbatim: duration(hours * 60)).tag(Optional(hours * 60))
        }
      }.pickerStyle(.menu)
    }

    private func duration(_ minutes: Int) -> String {
      Duration.seconds(minutes * 60).formatted(
        .units(allowed: [.hours, .minutes], width: .abbreviated).locale(locale))
    }
  }
#endif

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
