import StoreKit
import SwiftUI

struct PurchaseView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          LandscapeView(height: 190, fade: false).clipShape(RoundedRectangle(cornerRadius: 24))
          Text(model.purchases.unlocked ? L10n.historyUnlocked : L10n.theBiggerPicture).font(
            KvilStyle.title)
          Text(L10n.purchaseBody).foregroundStyle(Color.kvilSecondary)
          Label(L10n.purchaseAllHistory, systemImage: "calendar")
          Label(L10n.purchaseRecaps, systemImage: "chart.bar.xaxis")
          Text(L10n.purchaseFreePromise).font(.subheadline).foregroundStyle(Color.kvilSecondary)
          if model.purchases.unlocked {
            Label(L10n.yoursToKeep, systemImage: "checkmark.seal").font(.headline)
          } else if let product = model.purchases.product {
            Button {
              Task { await model.purchases.purchase() }
            } label: {
              HStack {
                Text(L10n.unlockHistory)
                Text(product.displayPrice)
              }
            }.buttonStyle(KvilPrimaryButtonStyle()).disabled(model.purchases.busy)
              .accessibilityIdentifier("unlockHistory")
            Text(L10n.oneTimePurchase).font(.footnote).frame(maxWidth: .infinity).foregroundStyle(
              Color.kvilSecondary)
          } else if !model.purchases.loaded {
            ProgressView().frame(maxWidth: .infinity)
          } else {
            Text(L10n.purchaseUnavailable).font(.subheadline).foregroundStyle(Color.kvilSecondary)
            Button(L10n.tryAgain) { Task { await model.purchases.load() } }.buttonStyle(.bordered)
          }
          if model.purchases.pending { Text(L10n.purchasePending).font(.subheadline) }
          if let error = model.purchases.error {
            Text(error).font(.subheadline).foregroundStyle(Color.kvilWarning)
          }
          Button(L10n.restorePurchases) { Task { await model.purchases.restore() } }.disabled(
            model.purchases.busy
          ).frame(maxWidth: .infinity, minHeight: 44)
        }.padding(KvilStyle.page)
      }.background(Color.kvilCanvas).navigationTitle(L10n.fullHistory)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L10n.done) { dismiss() } } }
        .task { await model.purchases.load() }
    }.tint(Color.kvilAccent)
  }
}
