import StoreKit
import StoreKitTest
import XCTest

@testable import KvilApp

@MainActor final class PurchaseTests: XCTestCase {
  func session() throws -> SKTestSession {
    let url = try XCTUnwrap(
      Bundle(for: Self.self).url(forResource: "Kvil", withExtension: "storekit"))
    let session = try SKTestSession(contentsOf: url)
    session.disableDialogs = true
    session.clearTransactions()
    session.resetToDefaultState()
    session.disableDialogs = true
    return session
  }
  func testPurchasePersistsAcrossServiceRecreationAndRefundRemovesEntitlement() async throws {
    let session = try session()
    defer { session.clearTransactions() }
    let service = PurchaseService()
    await service.load()
    XCTAssertNotNil(service.product)
    XCTAssertFalse(service.unlocked)
    await service.purchase()
    XCTAssertTrue(service.unlocked)
    let reopened = PurchaseService()
    await reopened.refreshEntitlements()
    XCTAssertTrue(reopened.unlocked)
    let transaction = try XCTUnwrap(session.allTransactions().first)
    try session.refundTransaction(identifier: transaction.identifier)
    for _ in 0..<30 {
      await service.refreshEntitlements()
      if !service.unlocked { break }
      try await Task.sleep(for: .milliseconds(100))
    }
    XCTAssertFalse(service.unlocked)
  }
  func testPendingPurchaseDoesNotUnlockBeforeApproval() async throws {
    let session = try session()
    defer { session.clearTransactions() }
    session.askToBuyEnabled = true
    let service = PurchaseService()
    await service.load()
    await service.purchase()
    XCTAssertTrue(service.pending)
    XCTAssertFalse(service.unlocked)
    let transaction = try XCTUnwrap(session.allTransactions().first)
    try session.approveAskToBuyTransaction(identifier: transaction.identifier)
    for _ in 0..<30 {
      await service.refreshEntitlements()
      if service.unlocked { break }
      try await Task.sleep(for: .milliseconds(100))
    }
    XCTAssertTrue(service.unlocked)
    XCTAssertFalse(service.pending)
  }
}
