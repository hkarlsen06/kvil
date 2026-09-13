import SwiftUI
import XCTest

@testable import KvilApp

@MainActor final class ProgressRingTests: XCTestCase {
  func testEmptyProgressLeavesNoForegroundArc() {
    let bounds = CGRect(x: 0, y: 0, width: 272, height: 272)
    XCTAssertTrue(OpenArc(progress: 0).path(in: bounds).isEmpty)
    XCTAssertTrue(OpenArc(progress: -0.01).path(in: bounds).isEmpty)
    XCTAssertFalse(OpenArc(progress: 0.5).path(in: bounds).isEmpty)
    XCTAssertFalse(OpenArc(progress: 1).path(in: bounds).isEmpty)
  }
}
