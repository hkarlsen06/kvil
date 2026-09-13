import Foundation
import Observation
import StoreKit

@MainActor @Observable final class PurchaseService {
  static let productID = "dev.hkarlsen06.kvil.history"
  private(set) var product: Product?
  private(set) var unlocked = false
  private(set) var busy = false
  private(set) var pending = false
  private(set) var loaded = false
  var error: String?
  private var updates: Task<Void, Never>?
  private let scenario: Bool
  init(scenario: Bool = false, unlocked: Bool = false) {
    self.scenario = scenario
    self.unlocked = unlocked
    if scenario {
      loaded = true
      return
    }
    updates = Task { [weak self] in
      for await result in Transaction.updates {
        guard !Task.isCancelled else { return }
        if case .verified(let transaction) = result, transaction.productID == Self.productID {
          await self?.refreshEntitlements()
          await transaction.finish()
        }
      }
    }
  }
  isolated deinit { updates?.cancel() }
  func load() async {
    guard !scenario else { return }
    error = nil
    await refreshEntitlements()
    do { product = try await Product.products(for: [Self.productID]).first } catch {
      self.error = String(localized: .purchaseUnavailable)
    }
    loaded = true
  }
  func refreshEntitlements() async {
    guard !scenario else { return }
    var active = false
    for await result in Transaction.currentEntitlements {
      if case .verified(let transaction) = result, transaction.productID == Self.productID,
        transaction.revocationDate == nil
      {
        active = true
      }
    }
    unlocked = active
    if active { pending = false }
  }
  func purchase() async {
    guard !busy, let product else { return }
    busy = true
    error = nil
    defer { busy = false }
    do {
      switch try await product.purchase() {
      case .success(let result):
        guard case .verified(let transaction) = result else {
          error = String(localized: .purchaseUnverified)
          return
        }
        await refreshEntitlements()
        await transaction.finish()
        pending = false
      case .pending: pending = true
      case .userCancelled: break
      @unknown default: error = String(localized: .purchaseUnavailable)
      }
    } catch { self.error = String(localized: .purchaseUnavailable) }
  }
  func restore() async {
    guard !scenario, !busy else { return }
    busy = true
    error = nil
    defer { busy = false }
    do {
      try await AppStore.sync()
      await refreshEntitlements()
    } catch { self.error = String(localized: .restoreFailed) }
  }
}
