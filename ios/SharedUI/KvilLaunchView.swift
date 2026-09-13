import SwiftUI

struct KvilLaunchView: View {
  var body: some View {
    Color.kvilCanvas
      .overlay {
        Image("KvilLaunchLogo")
          .resizable()
          .scaledToFit()
          .frame(width: 160, height: 160)
      }
      .ignoresSafeArea()
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(Text(verbatim: "Kvil"))
  }
}
