import StoreKitTest
import XCTest

@MainActor final class KvilUITests: XCTestCase {
  private var storeKit: SKTestSession?
  override func setUpWithError() throws {
    continueAfterFailure = false
    let url = try XCTUnwrap(
      Bundle(for: Self.self).url(forResource: "Kvil", withExtension: "storekit"))
    storeKit = try SKTestSession(contentsOf: url)
    storeKit?.resetToDefaultState()
    storeKit?.clearTransactions()
    storeKit?.disableDialogs = true
  }
  private func app(_ scenario: String, language: String = "en", largeText: Bool = false)
    -> XCUIApplication
  {
    let app = XCUIApplication()
    app.launchEnvironment["KVIL_SCENARIO"] = scenario
    app.launchEnvironment["KVIL_STOREKIT_TESTING"] = "1"
    app.launchArguments = [
      "-AppleLanguages", "(\(language))", "-AppleLocale", language == "nb" ? "nb_NO" : "en_US",
    ]
    if largeText {
      app.launchArguments += [
        "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
      ]
    }
    app.launch()
    return app
  }
  func testHomeScheduleAndReflectionFlow() {
    let app = app("reflection")
    XCTAssertTrue(app.buttons["changeToday"].waitForExistence(timeout: 10))
    app.buttons["changeToday"].tap()
    XCTAssertTrue(app.buttons["saveSchedule"].waitForExistence(timeout: 3))
    app.buttons["saveSchedule"].tap()
    XCTAssertTrue(app.buttons["feeling.comfortable"].waitForExistence(timeout: 3))
    app.swipeUp()
    for _ in 0..<5 where !app.buttons["feeling.comfortable"].isHittable {
      app.swipeUp()
    }
    XCTAssertTrue(app.buttons["feeling.comfortable"].isHittable)
    attach(app, name: "Reflection-before-answer")
    app.buttons["feeling.comfortable"].tap()
    XCTAssertTrue(app.buttons["feeling.comfortable"].waitForNonExistence(timeout: 3))
    app.tabBars.buttons["History"].tap()
    XCTAssertTrue(app.staticTexts["Your reflections"].waitForExistence(timeout: 3))
    attach(app, name: "History")
  }
  func testOnboardingAndOptionalWeight() {
    let app = app("onboarding")
    XCTAssertTrue(app.buttons["beginSetup"].waitForExistence(timeout: 10))
    app.buttons["beginSetup"].tap()
    app.buttons["finishSetup"].tap()
    XCTAssertTrue(app.buttons["changeToday"].waitForExistence(timeout: 5))
    app.tabBars.buttons["History"].tap()
    app.buttons["Add weight logging, if you like"].tap()
    app.buttons["Weight"].tap()
    app.buttons["Log weight"].tap()
    app.textFields["weightAmount"].tap()
    app.textFields["weightAmount"].typeText("75.5")
    app.buttons["saveWeight"].tap()
    XCTAssertTrue(app.staticTexts["75.5"].waitForExistence(timeout: 3))
  }
  func testHomeAccessibilityAndScreenshots() throws {
    let app = app("home")
    XCTAssertTrue(app.buttons["changeToday"].waitForExistence(timeout: 10))
    XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    attach(app, name: "Home-before-audit")
    try app.performAccessibilityAudit(for: [
      .contrast, .elementDetection, .hitRegion, .sufficientElementDescription, .trait,
    ])
    attach(app, name: "Home")
    app.tabBars.buttons["Schedule"].tap()
    XCTAssertTrue(app.buttons["editWeek"].waitForExistence(timeout: 3))
    attach(app, name: "Schedule")
    app.buttons["editWeek"].tap()
    XCTAssertTrue(app.buttons["saveSchedule"].waitForExistence(timeout: 3))
    app.buttons["Cancel"].tap()
  }
  func testOpenWindowAndNorwegianLayouts() throws {
    let open = app("open")
    XCTAssertTrue(open.buttons["changeToday"].waitForExistence(timeout: 10))
    XCTAssertTrue(open.staticTexts["Your window\nis open"].exists)
    attach(open, name: "Open-window")
    try open.performAccessibilityAudit(for: [.contrast, .textClipped, .hitRegion])
    open.terminate()
    let norwegian = app("home", language: "nb")
    XCTAssertTrue(norwegian.buttons["changeToday"].waitForExistence(timeout: 10))
    attach(norwegian, name: "Hjem-norsk")
    norwegian.tabBars.buttons["Plan"].tap()
    XCTAssertTrue(norwegian.buttons["editWeek"].waitForExistence(timeout: 3))
    attach(norwegian, name: "Plan-norsk")
    norwegian.tabBars.buttons["Historikk"].tap()
    attach(norwegian, name: "Historikk-norsk")
  }
  func testLargestTextLayouts() throws {
    let app = app("reflection", largeText: true)
    XCTAssertTrue(app.buttons["changeToday"].waitForExistence(timeout: 10))
    attach(app, name: "Home-largest-text")
    try app.performAccessibilityAudit(for: [.textClipped, .sufficientElementDescription])
    app.tabBars.buttons["Schedule"].tap()
    XCTAssertTrue(app.buttons["editWeek"].waitForExistence(timeout: 3))
    try app.performAccessibilityAudit(for: [.textClipped])
    app.swipeUp()
    attach(app, name: "Schedule-largest-text")
    app.tabBars.buttons["History"].tap()
    try app.performAccessibilityAudit(for: [.textClipped])
    app.swipeUp()
    attach(app, name: "History-largest-text")
  }
  func testScreensForRelease() {
    let app = app("onboarding")
    XCTAssertTrue(app.buttons["beginSetup"].waitForExistence(timeout: 10))
    attach(app, name: "Welcome")
    app.terminate()
    let home = self.app("home")
    XCTAssertTrue(home.buttons["changeToday"].waitForExistence(timeout: 10))
    attach(home, name: "Home-release")
    home.tabBars.buttons["Schedule"].tap()
    XCTAssertTrue(home.buttons["editWeek"].waitForExistence(timeout: 3))
    attach(home, name: "Schedule-release")
    home.tabBars.buttons["Home"].tap()
    home.buttons["settings"].tap()
    XCTAssertTrue(home.navigationBars["Settings"].waitForExistence(timeout: 3))
    attach(home, name: "Settings")
    home.buttons["Done"].tap()
    home.tabBars.buttons["History"].tap()
    attach(home, name: "History-release")
    let explore = home.buttons["exploreHistory"]
    for _ in 0..<5 where !explore.isHittable {
      home.swipeUp()
    }
    XCTAssertTrue(explore.isHittable)
    attach(home, name: "History-purchase-link")
    explore.tap()
    attach(home, name: "Purchase-presented")
    XCTAssertTrue(home.navigationBars["Full history"].waitForExistence(timeout: 5))
    home.swipeUp()
    XCTAssertTrue(home.buttons["unlockHistory"].waitForExistence(timeout: 10))
    attach(home, name: "Full-history")
  }
  private func attach(_ app: XCUIApplication, name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
