import StoreKit
import SwiftUI

struct PurchaseView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      ViewThatFits(in: .vertical) {
        content(imageHeight: 190).fixedSize(horizontal: false, vertical: true)
        content(imageHeight: 100).fixedSize(horizontal: false, vertical: true)
        ScrollView { content(imageHeight: 100) }
      }.frame(maxHeight: .infinity, alignment: .top)
        .background(Color.kvilCanvas).navigationTitle(.fullHistory)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button(.done) { dismiss() } } }
        .task { await model.purchases.load() }
    }.tint(Color.kvilAccent)
  }

  private func content(imageHeight: CGFloat) -> some View {
    VStack(alignment: .leading, spacing: KvilStyle.content) {
      LandscapeView(height: imageHeight).clipShape(RoundedRectangle(cornerRadius: KvilStyle.corner))
      Text(model.purchases.unlocked ? .historyUnlocked : .theBiggerPicture).font(
        KvilStyle.title)
      Text(.purchaseBody).foregroundStyle(Color.kvilSecondary)
      Label(.purchaseAllHistory, systemImage: "calendar")
      Label(.purchaseRecaps, systemImage: "chart.bar.xaxis")
      if model.purchases.unlocked {
        Label(.yoursToKeep, systemImage: "checkmark.seal").font(.headline)
      } else if let product = model.purchases.product {
        Button {
          Task { await model.purchases.purchase() }
        } label: {
          HStack {
            Text(.unlockHistory)
            Text(product.displayPrice)
          }
        }.buttonStyle(KvilPrimaryButtonStyle()).disabled(model.purchases.busy)
          .accessibilityIdentifier("unlockHistory")
      } else if !model.purchases.loaded {
        ProgressView().frame(maxWidth: .infinity)
      } else {
        Text(.purchaseUnavailable).font(.subheadline).foregroundStyle(Color.kvilSecondary)
        Button(.tryAgain) { Task { await model.purchases.load() } }.buttonStyle(.bordered)
      }
      ViewThatFits(in: .horizontal) {
        HStack(spacing: KvilStyle.page) { legalLinks }.fixedSize()
        VStack(spacing: 0) { legalLinks }
      }.font(.footnote).frame(maxWidth: .infinity)
      if model.purchases.pending { Text(.purchasePending).font(.subheadline) }
      if let error = model.purchases.error {
        Text(error).font(.subheadline).foregroundStyle(Color.kvilWarning)
      }
      Button(.restorePurchases) { Task { await model.purchases.restore() } }.disabled(
        model.purchases.busy
      ).frame(maxWidth: .infinity, minHeight: 44)
    }.padding(KvilStyle.page)
  }

  private var legalLinks: some View {
    Group {
      Link(.privacyPolicy, destination: URL(string: "https://hkarlsen06.dev/kvil/privacy/")!)
        .frame(minHeight: 44)
      Link(
        .eula,
        destination: URL(
          string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
      )
      .accessibilityLabel(Text(.endUserLicenseAgreement))
      .frame(minHeight: 44)
    }
  }
}
