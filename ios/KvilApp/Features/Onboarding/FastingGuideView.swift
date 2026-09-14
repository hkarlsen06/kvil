import SwiftUI

struct FastingGuideView: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: KvilStyle.section) {
        guideSection(.guideWindowTitle, body: .guideWindowBody)
        guideSection(.guideMealsTitle, body: .guideMealsBody)
        guideSection(.guideFlexibleTitle, body: .guideFlexibleBody)
        guideSection(.guideSuitabilityTitle, body: .guideSuitabilityBody)
        VStack(alignment: .leading, spacing: KvilStyle.related) {
          Text(.guideSourceHelp).font(.footnote).foregroundStyle(Color.kvilSecondary)
          if let url = URL(
            string:
              "https://www.hopkinsmedicine.org/health/expert-qa/intermittent-fasting-what-is-it-and-how-does-it-work"
          ) {
            Link(.guideSourceTitle, destination: url).font(.footnote).frame(minHeight: 44)
          }
        }
      }.padding(KvilStyle.page).frame(maxWidth: 640, alignment: .leading)
        .frame(maxWidth: .infinity)
    }.background(Color.kvilCanvas).navigationTitle(.fastingGuide)
      .navigationBarTitleDisplayMode(.inline)
  }

  private func guideSection(_ title: LocalizedStringResource, body: LocalizedStringResource)
    -> some View
  {
    VStack(alignment: .leading, spacing: KvilStyle.related) {
      Text(title).font(KvilStyle.heading).accessibilityAddTraits(.isHeader)
      Text(body).foregroundStyle(Color.kvilSecondary).lineSpacing(3)
    }.fixedSize(horizontal: false, vertical: true)
  }
}
