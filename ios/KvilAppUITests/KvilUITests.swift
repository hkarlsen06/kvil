import StoreKitTest
import UIKit
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
  private func waitForUnobstructedHome(_ app: XCUIApplication) {
    let wordmark = app.descendants(matching: .any).matching(identifier: "homeWordmark").firstMatch
    XCTAssertTrue(wordmark.waitForExistence(timeout: 5))
    // A system notification can cover the header and contaminate a whole-screen contrast audit.
    let visible = XCTNSPredicateExpectation(
      predicate: NSPredicate { _, _ in wordmark.isHittable }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [visible], timeout: 15), .completed)
  }
  private func auditCurrentScreen(_ app: XCUIApplication, for types: XCUIAccessibilityAuditType) throws {
    let previous = continueAfterFailure
    continueAfterFailure = true
    defer { continueAfterFailure = previous }
    let hierarchy = XCTAttachment(string: app.debugDescription)
    hierarchy.name = "Accessibility-audit-layout"
    hierarchy.lifetime = .keepAlways
    add(hierarchy)
    try app.performAccessibilityAudit(for: types)
  }
  func testHomeScheduleAndReflectionFlow() {
    let app = app("reflection")
    XCTAssertTrue(app.buttons["changeToday"].waitForExistence(timeout: 10))
    app.buttons["changeToday"].tap()
    XCTAssertTrue(app.buttons["saveSchedule"].waitForExistence(timeout: 3))
    app.buttons["saveSchedule"].tap()
    tap(app.buttons["openReflection"], in: app)
    XCTAssertTrue(app.buttons["planExperience.asPlanned"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.buttons["feeling.comfortable"].exists)
    attach(app, name: "Reflection-plan-question")
    tap(app.buttons["planExperience.asPlanned"], in: app)
    XCTAssertFalse(app.pickerWheels.firstMatch.exists)
    XCTAssertTrue(app.buttons["feeling.comfortable"].waitForExistence(timeout: 3))
    for _ in 0..<5 where !app.buttons["feeling.comfortable"].isHittable {
      app.swipeUp()
    }
    XCTAssertTrue(app.buttons["feeling.comfortable"].isHittable)
    attach(app, name: "Reflection-before-answer")
    app.buttons["feeling.comfortable"].tap()
    tap(app.buttons["saveReflection"], in: app)
    XCTAssertTrue(app.buttons["feeling.comfortable"].waitForNonExistence(timeout: 3))
    app.tabBars.buttons["History"].tap()
    XCTAssertTrue(app.staticTexts["Your reflections"].waitForExistence(timeout: 3))
    attach(app, name: "History")
  }
  func testHomeFastingActionsAndDatePencil() throws {
    let app = app("home", language: "nb")
    let action = app.buttons["fastingAction"]
    let undo = app.buttons["undoEarlyBreak"]
    let pencil = app.buttons["changeToday"]
    XCTAssertTrue(action.waitForExistence(timeout: 10))
    XCTAssertEqual(action.label, "Bryt fasten tidlig")
    XCTAssertFalse(undo.exists)
    XCTAssertTrue(pencil.isHittable)
    XCTAssertLessThan(pencil.frame.maxY, action.frame.minY)
    let date = app.staticTexts["homeDate"]
    XCTAssertEqual(date.frame.midX, app.frame.midX, accuracy: 1)
    XCTAssertEqual(pencil.frame.minX, date.frame.maxX, accuracy: 1)
    attach(app, name: "Fasting-action-norsk")
    try app.performAccessibilityAudit(for: [
      .textClipped, .hitRegion, .sufficientElementDescription,
    ])
    action.tap()
    XCTAssertTrue(app.staticTexts["Spisevinduet\ner åpent"].waitForExistence(timeout: 3))
    XCTAssertEqual(action.label, "Start fasten nå")
    XCTAssertTrue(undo.isHittable)
    XCTAssertEqual(undo.label, "Angre tidlig fastebrudd")
    XCTAssertGreaterThan(undo.frame.minX, action.frame.maxX)
    XCTAssertEqual(undo.frame.midY, action.frame.midY, accuracy: 1)
    attach(app, name: "Eating-action-norsk")
    try app.performAccessibilityAudit(for: [
      .textClipped, .hitRegion, .sufficientElementDescription,
    ])
    app.tabBars.buttons["Plan"].tap()
    app.tabBars.buttons["Hjem"].tap()
    XCTAssertTrue(undo.isHittable)
    undo.tap()
    XCTAssertTrue(undo.waitForNonExistence(timeout: 3))
    XCTAssertEqual(action.label, "Bryt fasten tidlig")
    action.tap()
    action.tap()
    XCTAssertEqual(action.label, "Bryt fasten tidlig")
    let undoStart = app.buttons["undoEarlyStart"]
    XCTAssertTrue(undoStart.isHittable)
    XCTAssertEqual(undoStart.label, "Angre tidlig fastestart")
    XCTAssertFalse(undo.exists)
    XCTAssertGreaterThan(undoStart.frame.minX, action.frame.maxX)
    XCTAssertEqual(undoStart.frame.midY, action.frame.midY, accuracy: 1)
    attach(app, name: "Undo-early-start-norsk")
    app.tabBars.buttons["Plan"].tap()
    app.tabBars.buttons["Hjem"].tap()
    undoStart.tap()
    XCTAssertTrue(undoStart.waitForNonExistence(timeout: 3))
    XCTAssertEqual(action.label, "Start fasten nå")
    XCTAssertTrue(undo.isHittable)
    undo.tap()
    XCTAssertTrue(undo.waitForNonExistence(timeout: 3))
    try app.performAccessibilityAudit(for: [.textClipped, .hitRegion])
    attach(app, name: "Started-fast-norsk")
    pencil.tap()
    XCTAssertTrue(app.buttons["saveSchedule"].waitForExistence(timeout: 3))
  }
  func testUndoEarlyBreakAtLargestText() throws {
    let app = app("home", largeText: true)
    let action = app.buttons["fastingAction"]
    let undo = app.buttons["undoEarlyBreak"]
    XCTAssertTrue(action.waitForExistence(timeout: 10))
    action.tap()
    XCTAssertTrue(undo.waitForExistence(timeout: 3))
    XCTAssertTrue(undo.isHittable)
    XCTAssertGreaterThan(undo.frame.minX, action.frame.maxX)
    XCTAssertLessThanOrEqual(action.frame.maxY, app.tabBars.firstMatch.frame.minY)
    XCTAssertFalse(app.scrollViews.firstMatch.exists)
    attach(app, name: "Undo-early-break-largest-text")
    try app.performAccessibilityAudit(for: [
      .textClipped, .hitRegion, .sufficientElementDescription,
    ])
    undo.tap()
    XCTAssertTrue(undo.waitForNonExistence(timeout: 3))
    XCTAssertEqual(action.label, "Break fast early")
  }
  func testUndoEarlyBreakExpiresWhenScheduledWindowOpens() {
    let app = app("openingSoon")
    let action = app.buttons["fastingAction"]
    let undo = app.buttons["undoEarlyBreak"]
    XCTAssertTrue(action.waitForExistence(timeout: 10))
    action.tap()
    XCTAssertTrue(undo.waitForExistence(timeout: 3))
    XCTAssertEqual(action.label, "Start fast now")
    XCTAssertTrue(undo.waitForNonExistence(timeout: 25))
    XCTAssertEqual(action.label, "Start fast now")
    attach(app, name: "Undo-expired-at-scheduled-opening")
  }
  func testUndoEarlyStartExpiresWhenScheduledWindowCloses() {
    let app = app("closingSoon")
    let action = app.buttons["fastingAction"]
    let undo = app.buttons["undoEarlyStart"]
    XCTAssertTrue(action.waitForExistence(timeout: 10))
    XCTAssertFalse(undo.exists)
    action.tap()
    XCTAssertTrue(undo.waitForExistence(timeout: 3))
    XCTAssertEqual(action.label, "Break fast early")
    XCTAssertTrue(undo.waitForNonExistence(timeout: 25))
    XCTAssertEqual(action.label, "Break fast early")
    attach(app, name: "Undo-expired-at-scheduled-closing")
  }
  func testFastingActionsAtLargestText() throws {
    let app = app("open", largeText: true)
    let action = app.buttons["fastingAction"]
    XCTAssertTrue(action.waitForExistence(timeout: 10))
    XCTAssertEqual(action.label, "Start fast now")
    XCTAssertEqual(app.staticTexts["homeDate"].frame.midX, app.frame.midX, accuracy: 1)
    attach(app, name: "Fasting-action-largest-text")
    try app.performAccessibilityAudit(for: [.textClipped, .sufficientElementDescription])
    XCTAssertFalse(app.scrollViews.firstMatch.exists)
    XCTAssertTrue(action.isHittable)
    XCTAssertLessThanOrEqual(action.frame.maxY, app.tabBars.firstMatch.frame.minY)
    action.tap()
    XCTAssertEqual(action.label, "Break fast early")
    let undo = app.buttons["undoEarlyStart"]
    XCTAssertTrue(undo.isHittable)
    XCTAssertEqual(undo.label, "Undo early fast start")
    let aligned = XCTNSPredicateExpectation(
      predicate: NSPredicate { _, _ in
        undo.frame.minX > action.frame.maxX && abs(undo.frame.midY - action.frame.midY) <= 1
      },
      object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [aligned], timeout: 3), .completed)
    try app.performAccessibilityAudit(for: [.textClipped, .sufficientElementDescription])
    XCTAssertFalse(app.scrollViews.firstMatch.exists)
    XCTAssertLessThanOrEqual(action.frame.maxY, app.tabBars.firstMatch.frame.minY)
    attach(app, name: "Started-fast-largest-text")
    let reflection = app.buttons["openReflection"]
    XCTAssertTrue(reflection.isHittable)
    XCTAssertLessThanOrEqual(reflection.frame.maxY, app.tabBars.firstMatch.frame.minY)
    reflection.tap()
    tap(app.buttons["planExperience.asPlanned"], in: app)
    let feeling = app.buttons["feeling.comfortable"]
    XCTAssertTrue(feeling.waitForExistence(timeout: 3))
    for _ in 0..<5 where !feeling.isHittable { app.swipeUp() }
    XCTAssertTrue(feeling.isHittable)
    feeling.tap()
    tap(app.buttons["saveReflection"], in: app)
    XCTAssertTrue(reflection.waitForNonExistence(timeout: 3))
    XCTAssertFalse(app.scrollViews.firstMatch.exists)
    undo.tap()
    XCTAssertTrue(undo.waitForNonExistence(timeout: 3))
    XCTAssertEqual(action.label, "Start fast now")
    XCTAssertFalse(app.buttons["undoEarlyBreak"].exists)
  }
  func testHomeLeavesSpaceForLandscapeWithoutScrolling() throws {
    let app = app("open", language: "nb")
    let action = app.buttons["fastingAction"]
    XCTAssertTrue(action.waitForExistence(timeout: 10))
    let content = app.otherElements["homeContent"]
    XCTAssertTrue(content.exists)
    XCTAssertFalse(app.scrollViews.firstMatch.exists)
    let navigationBottom = app.navigationBars.firstMatch.frame.maxY
    let tabTop = app.tabBars.firstMatch.frame.minY
    XCTAssertEqual(content.frame.midX, app.frame.midX, accuracy: 1)
    // The date's 44-point edit target extends above the content's visual top edge.
    XCTAssertEqual(app.staticTexts["homeDate"].frame.minY, navigationBottom + 16, accuracy: 2)
    XCTAssertGreaterThanOrEqual(tabTop - content.frame.maxY, 100)
    let window = app.descendants(matching: .any).matching(identifier: "homeWindowTime").firstMatch
    XCTAssertTrue(window.label.contains("10:00"))
    XCTAssertTrue(window.label.contains("18:00"))
    let dateBeforeSwipe = app.staticTexts["homeDate"].frame
    app.swipeUp()
    XCTAssertEqual(app.staticTexts["homeDate"].frame, dateBeforeSwipe)
    XCTAssertTrue(action.isHittable)
    waitForUnobstructedHome(app)
    try auditCurrentScreen(app, for: [.contrast, .textClipped, .hitRegion])
    attach(app, name: "Home-landscape-space-norsk")
  }
  func testWindowOpensWhileHomeIsVisible() throws {
    let app = app("openingSoon")
    XCTAssertTrue(app.buttons["fastingAction"].waitForExistence(timeout: 10))
    XCTAssertEqual(app.buttons["fastingAction"].label, "Break fast early")
    XCTAssertTrue(app.staticTexts["Your window\nis open"].waitForExistence(timeout: 30))
    XCTAssertEqual(app.buttons["fastingAction"].label, "Start fast now")
    try app.performAccessibilityAudit(for: [.textClipped, .hitRegion])
    attach(app, name: "Automatic-window-opening")
  }
  func testHomeArrivalAfterOpeningInBackground() throws {
    let app = app("openingSoon")
    XCTAssertTrue(app.buttons["fastingAction"].waitForExistence(timeout: 10))
    app.tabBars.buttons["Schedule"].tap()
    XCUIDevice.shared.press(.home)
    XCTAssertTrue(app.wait(for: .runningBackground, timeout: 3))
    // Cross the fixture's real clock boundary while the application is suspended.
    let backgroundTime = XCTestExpectation(description: "Wait past the scheduled opening")
    backgroundTime.isInverted = true
    XCTAssertEqual(XCTWaiter.wait(for: [backgroundTime], timeout: 21), .completed)
    XCUIDevice.shared.system.open(URL(string: "kvil://home")!)
    XCTAssertTrue(app.staticTexts["Your window\nis open"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.buttons["fastingAction"].label, "Start fast now")
    attach(app, name: "Home-after-background-opening")
  }
  func testWindowClosesWhileHomeIsVisible() throws {
    let app = app("closingSoon")
    let action = app.buttons["fastingAction"]
    XCTAssertTrue(action.waitForExistence(timeout: 10))
    XCTAssertEqual(action.label, "Start fast now")
    attach(app, name: "Landscape-before-scheduled-close")
    let closed = NSPredicate(format: "label == %@", "Break fast early")
    expectation(for: closed, evaluatedWith: action)
    waitForExpectations(timeout: 30)
    XCTAssertFalse(app.staticTexts["Your window\nis open"].exists)
    try app.performAccessibilityAudit(for: [.textClipped, .hitRegion])
    attach(app, name: "Landscape-after-scheduled-close")
  }
  func testOpenWindowHomeLinksAndReturnToLandscape() throws {
    let app = app("open")
    let action = app.buttons["fastingAction"]
    XCTAssertTrue(action.waitForExistence(timeout: 10))
    attach(app, name: "Boat-after-open-window-launch")
    app.tabBars.buttons["Schedule"].tap()
    XCUIDevice.shared.system.open(URL(string: "kvil://home")!)
    XCTAssertTrue(action.waitForExistence(timeout: 5))
    XCTAssertEqual(action.label, "Start fast now")
    attach(app, name: "Boat-after-Home-link")
    // Repeated links must also replay when the destination tab is already selected.
    XCUIDevice.shared.system.open(URL(string: "kvil://home")!)
    XCTAssertTrue(action.waitForExistence(timeout: 5))
    attach(app, name: "Boat-after-repeated-Home-link")
    action.tap()
    XCTAssertEqual(action.label, "Break fast early")
    try app.performAccessibilityAudit(for: [.textClipped, .hitRegion])
    attach(app, name: "Landscape-after-closing-window")
  }
  func testProgressAfterTimeOnAnotherTab() {
    let app = app("progressReturn")
    XCTAssertTrue(app.staticTexts["Your window\nis open"].waitForExistence(timeout: 10))
    attach(app, name: "Progress-before-leaving-Home")
    app.tabBars.buttons["Schedule"].tap()
    XCTAssertTrue(app.buttons["weekOptions"].waitForExistence(timeout: 3))
    let timeAway = XCTestExpectation(description: "Let the isolated window progress offscreen")
    timeAway.isInverted = true
    XCTAssertEqual(XCTWaiter.wait(for: [timeAway], timeout: 25), .completed)
    app.tabBars.buttons["Home"].tap()
    XCTAssertTrue(app.staticTexts["Your window\nis open"].waitForExistence(timeout: 3))
    attach(app, name: "Progress-after-returning-Home")
  }
  func testFastingActionsWithReducedMotion() throws {
    guard UIAccessibility.isReduceMotionEnabled else {
      throw XCTSkip("Enable Reduce Motion on the test simulator for this check.")
    }
    let app = app("home")
    let action = app.buttons["fastingAction"]
    XCTAssertTrue(action.waitForExistence(timeout: 10))
    action.tap()
    XCTAssertTrue(app.staticTexts["Your window\nis open"].waitForExistence(timeout: 3))
    XCTAssertEqual(action.label, "Start fast now")
    action.tap()
    XCTAssertEqual(action.label, "Break fast early")
    try app.performAccessibilityAudit(for: [.textClipped, .hitRegion])
    attach(app, name: "Home-reduced-motion")
  }
  func testOnboardingAndOptionalWeight() {
    let app = app("onboarding")
    XCTAssertTrue(app.buttons["beginSetup"].waitForExistence(timeout: 10))
    app.buttons["beginSetup"].tap()
    continueIntroduction(in: app)
    previewWeek(in: app)
    disableSetupCloudSync(in: app)
    tap(app.buttons["finishSetup"], in: app)
    XCTAssertTrue(app.buttons["changeToday"].waitForExistence(timeout: 5))
    assertSetupCloudSyncRemainsDisabled(in: app, language: "en")
    XCTAssertFalse(app.buttons["settings"].exists)
    XCTAssertFalse(app.buttons["logWeight"].exists)
    attach(app, name: "Home-weight-disabled")
    app.tabBars.buttons["History"].tap()
    let chart = app.descendants(matching: .any).matching(identifier: "historyWeightChart")
      .firstMatch
    XCTAssertFalse(chart.exists)
    XCTAssertFalse(app.buttons["historyAddWeight"].exists)
    app.buttons["Add weight logging, if you like"].tap()
    XCTAssertFalse(chart.exists)
    XCTAssertTrue(app.buttons["weightLog"].exists)
    app.tabBars.buttons["Home"].tap()
    XCTAssertTrue(app.buttons["logWeight"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["logWeight"].isHittable)
    XCTAssertEqual(app.buttons["logWeight"].label, "Log weight")
    XCTAssertFalse(app.buttons["settings"].exists)
    attach(app, name: "Home-weight-enabled")
    app.buttons["logWeight"].tap()
    XCTAssertTrue(app.textFields["weightAmount"].waitForExistence(timeout: 3))
    app.buttons["Cancel"].tap()
    XCTAssertTrue(app.buttons["logWeight"].waitForExistence(timeout: 3))
    app.buttons["logWeight"].tap()
    app.textFields["weightAmount"].tap()
    app.textFields["weightAmount"].typeText("75.5")
    attach(app, name: "Home-weight-entry")
    app.buttons["saveWeight"].tap()
    XCTAssertTrue(app.buttons["logWeight"].waitForExistence(timeout: 3))
    app.tabBars.buttons["History"].tap()
    XCTAssertFalse(chart.exists)
    app.buttons["weightLog"].tap()
    XCTAssertTrue(app.staticTexts["75.5"].waitForExistence(timeout: 3))
    app.buttons["Log weight"].tap()
    XCTAssertTrue(app.textFields["weightAmount"].waitForExistence(timeout: 3))
    app.textFields["weightAmount"].typeText("75.2")
    app.buttons["saveWeight"].tap()
    XCTAssertTrue(app.staticTexts["75.2"].waitForExistence(timeout: 3))
    app.navigationBars.buttons["History"].tap()
    XCTAssertTrue(chart.waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["historyAddWeight"].isHittable)
    XCTAssertGreaterThanOrEqual(app.buttons["weightLog"].frame.minY, chart.frame.maxY)
    attach(app, name: "History-two-weights-same-time")
    app.buttons["historyAddWeight"].tap()
    XCTAssertTrue(app.textFields["weightAmount"].waitForExistence(timeout: 3))
    app.buttons["Cancel"].tap()
    XCTAssertTrue(chart.waitForExistence(timeout: 3))
    app.buttons["historyAddWeight"].tap()
    XCTAssertTrue(app.textFields["weightAmount"].waitForExistence(timeout: 3))
    app.textFields["weightAmount"].typeText("75.0")
    app.buttons["saveWeight"].tap()
    XCTAssertTrue(chart.waitForExistence(timeout: 3))
    app.buttons["weightLog"].tap()
    XCTAssertTrue(app.staticTexts["75.0"].waitForExistence(timeout: 3))
  }
  func testHistoryWeightChartLayout() throws {
    for largeText in [false, true] {
      let app = app("weightHistory", language: "nb", largeText: largeText)
      app.tabBars.buttons["Historikk"].tap()
      let chart = app.descendants(matching: .any).matching(identifier: "historyWeightChart")
        .firstMatch
      XCTAssertTrue(chart.waitForExistence(timeout: 5))
      let add = app.buttons["historyAddWeight"]
      for _ in 0..<10 where !add.isHittable || !app.buttons["weightLog"].isHittable {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75)).press(
          forDuration: 0.1,
          thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.67)))
      }
      XCTAssertTrue(add.isHittable)
      XCTAssertEqual(add.label, "Logg vekt")
      XCTAssertGreaterThan(add.frame.midX, chart.frame.midX)
      XCTAssertLessThanOrEqual(add.frame.maxY, chart.frame.minY)
      XCTAssertGreaterThanOrEqual(app.buttons["weightLog"].frame.minY, chart.frame.maxY)
      attach(app, name: largeText ? "History-weight-largest-text" : "History-weight-norwegian")
      try app.performAccessibilityAudit(for: [.textClipped, .hitRegion])
      add.tap()
      XCTAssertTrue(app.textFields["weightAmount"].waitForExistence(timeout: 3))
      attach(app, name: largeText ? "History-weight-editor-largest-text" : "History-weight-editor")
      app.terminate()
    }
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
    XCTAssertTrue(app.buttons["weekOptions"].waitForExistence(timeout: 3))
    attach(app, name: "Schedule")
    app.buttons["dayMenu.1"].tap()
    app.buttons["Set exact times"].tap()
    XCTAssertTrue(app.buttons["saveSchedule"].waitForExistence(timeout: 3))
    app.buttons["Cancel"].tap()
  }
  func testOpenWindowAndNorwegianLayouts() throws {
    let open = app("open")
    XCTAssertTrue(open.buttons["changeToday"].waitForExistence(timeout: 10))
    XCTAssertTrue(open.staticTexts["Your window\nis open"].exists)
    waitForUnobstructedHome(open)
    attach(open, name: "Open-window")
    try auditCurrentScreen(open, for: [.contrast, .textClipped, .hitRegion])
    open.terminate()
    let norwegian = app("home", language: "nb")
    XCTAssertTrue(norwegian.buttons["changeToday"].waitForExistence(timeout: 10))
    attach(norwegian, name: "Hjem-norsk")
    norwegian.tabBars.buttons["Plan"].tap()
    XCTAssertTrue(norwegian.buttons["weekOptions"].waitForExistence(timeout: 3))
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
    XCTAssertTrue(app.buttons["weekOptions"].waitForExistence(timeout: 3))
    let today = app.descendants(matching: .any).matching(identifier: "todayWindow").firstMatch
    XCTAssertTrue(today.exists)
    XCTAssertGreaterThanOrEqual(today.frame.minX, app.frame.minX)
    XCTAssertLessThanOrEqual(today.frame.maxX, app.frame.maxX)
    attach(app, name: "Schedule-largest-text-top")
    try app.performAccessibilityAudit(for: [.textClipped])
    app.swipeUp()
    attach(app, name: "Schedule-largest-text")
    try app.performAccessibilityAudit(for: [.textClipped])
    app.tabBars.buttons["History"].tap()
    try app.performAccessibilityAudit(for: [.textClipped])
    app.swipeUp()
    attach(app, name: "History-largest-text")
  }
  func testScreensForRelease() {
    for language in ["en", "nb"] {
      let welcome = app("onboarding", language: language)
      XCTAssertTrue(welcome.buttons["beginSetup"].waitForExistence(timeout: 10))
      attach(welcome, name: "\(language)-04-welcome")
      welcome.terminate()
      let home = app("home", language: language)
      XCTAssertTrue(home.buttons["changeToday"].waitForExistence(timeout: 10))
      // The ring's spring and landscape arrival finish within two seconds.
      let arrival = XCTestExpectation(description: "Home arrival completes")
      arrival.isInverted = true
      XCTAssertEqual(XCTWaiter.wait(for: [arrival], timeout: 2.2), .completed)
      attach(home, name: "\(language)-01-home")
      home.tabBars.buttons[language == "nb" ? "Plan" : "Schedule"].tap()
      XCTAssertTrue(home.buttons["weekOptions"].waitForExistence(timeout: 3))
      attach(home, name: "\(language)-02-schedule")
      home.tabBars.buttons[language == "nb" ? "Historikk" : "History"].tap()
      XCTAssertTrue(home.buttons["settings"].waitForExistence(timeout: 3))
      attach(home, name: "\(language)-03-history")
      if language == "en" {
        tap(home.buttons["exploreHistory"], in: home)
        XCTAssertTrue(home.buttons["unlockHistory"].waitForExistence(timeout: 10))
        attach(home, name: "en-purchase-review")
      }
      home.terminate()
    }
  }
  private func continueIntroduction(in app: XCUIApplication) {
    tap(app.buttons["continueWindows"], in: app)
  }

  private func previewWeek(in app: XCUIApplication) {
    tap(app.buttons["continueMealTimes"], in: app)
    tap(app.buttons["previewSetup"], in: app)
  }

  private func disableSetupCloudSync(in app: XCUIApplication) {
    let cloud = app.switches["setupCloudScheduleSync"]
    let control = cloud.switches.firstMatch
    reveal(control, in: app)
    XCTAssertEqual(cloud.value as? String, "1")
    attach(app, name: "Onboarding-cloud-choice-default")
    control.tap()
    XCTAssertEqual(cloud.value as? String, "0")
  }

  private func assertSetupCloudSyncRemainsDisabled(in app: XCUIApplication, language: String) {
    tap(app.tabBars.buttons[language == "nb" ? "Plan" : "Schedule"], in: app)
    tap(app.buttons["settings"], in: app)
    let cloud = app.switches["cloudScheduleSync"]
    // Settings opens at the top; iCloud is below the preceding sections at large text sizes.
    for _ in 0..<20 where !cloud.isHittable { scrollContent(in: app, towardTop: false) }
    XCTAssertTrue(cloud.isHittable)
    XCTAssertEqual(cloud.value as? String, "0")
    attach(app, name: "Settings-cloud-choice-retained")
    tap(app.buttons[language == "nb" ? "Ferdig" : "Done"], in: app)
    tap(app.tabBars.buttons[language == "nb" ? "Hjem" : "Home"], in: app)
  }

  func testOnboardingEducationAndProgress() throws {
    let app = app("onboarding", language: "nb")
    let progress = app.descendants(matching: .any).matching(identifier: "onboardingProgress")
      .firstMatch
    XCTAssertTrue(app.buttons["beginSetup"].waitForExistence(timeout: 10))
    XCTAssertEqual(progress.value as? String, "Steg 1 av 5")
    tap(app.buttons["beginSetup"], in: app)
    XCTAssertTrue(app.buttons["beginSetup"].waitForNonExistence(timeout: 3))
    XCTAssertEqual(progress.value as? String, "Steg 2 av 5")
    XCTAssertEqual(app.buttons["continueWindows"].label, "Bruk denne rytmen")
    attachOnboarding(app, name: "Onboarding-rhythm-picker")
    XCTAssertLessThanOrEqual(
      app.buttons["setupRhythm.custom"].frame.maxY, visibleContent(in: app).maxY,
      "Every rhythm should fit above the actions without scrolling at standard text size.")
    let explanation = app.descendants(matching: .any)
      .matching(identifier: "onboardingWindowExplanation").firstMatch
    XCTAssertFalse(app.descendants(matching: .any)
      .matching(identifier: "onboardingWindowLegend").firstMatch.exists)
    try app.performAccessibilityAudit(for: [.contrast, .textClipped, .hitRegion])
    tap(app.buttons["setupRhythm.sixteen"], in: app)
    XCTAssertEqual(explanation.label, "16 timer faste · 8 timer til måltider")
    tap(app.buttons["continueWindows"], in: app)
    XCTAssertEqual(progress.value as? String, "Steg 3 av 5")
    let slider = app.descendants(matching: .any).matching(identifier: "setupWindowSlider")
      .firstMatch
    XCTAssertEqual(try clockMinutes(in: slider, app: app), [10 * 60, 18 * 60])
    attachOnboarding(app, name: "Onboarding-meals-step-three")
    tap(app.buttons["continueMealTimes"], in: app)
    XCTAssertEqual(progress.value as? String, "Steg 4 av 5")
    let pause = app.descendants(matching: .any)
      .matching(identifier: "onboardingNightExplanation").firstMatch
    XCTAssertEqual(try clockMinutes(in: pause, app: app), [18 * 60, 10 * 60])
    XCTAssertTrue((pause.value as? String)?.contains("16 timer") == true)
    XCTAssertTrue((pause.value as? String)?.contains("+1 dag") == true)
    XCTAssertFalse(app.buttons["onboardingLateDinner"].exists)
    XCTAssertFalse(app.buttons["onboardingUsualDinner"].exists)
    attachOnboarding(app, name: "Onboarding-personal-pause-sixteen")
    XCTAssertLessThanOrEqual(
      app.buttons["onboardingSafetyGuide"].frame.maxY, visibleContent(in: app).maxY,
      "The lesson and guide should fit above the actions at standard text size.")
    try app.performAccessibilityAudit(for: [.contrast, .textClipped, .hitRegion])
    tap(app.buttons["onboardingSafetyGuide"], in: app)
    XCTAssertTrue(app.navigationBars["Faste og din rytme"].waitForExistence(timeout: 3))
    tap(app.buttons["Ferdig"], in: app)
    tap(app.buttons["onboardingBack"], in: app)
    XCTAssertEqual(progress.value as? String, "Steg 3 av 5")
    XCTAssertEqual(try clockMinutes(in: slider, app: app), [10 * 60, 18 * 60])
    tap(app.buttons["onboardingBack"], in: app)
    XCTAssertEqual(progress.value as? String, "Steg 2 av 5")
    XCTAssertTrue(app.buttons["setupRhythm.sixteen"].isSelected)
    tap(app.buttons["setupRhythm.fourteen"], in: app)
    tap(app.buttons["continueWindows"], in: app)
    XCTAssertEqual(try clockMinutes(in: slider, app: app), [9 * 60, 19 * 60])
    dragWindow(slider, byDayFraction: 0.15625, in: app)
    let edited = try clockMinutes(in: slider, app: app)
    XCTAssertEqual(edited, [12 * 60 + 45, 22 * 60 + 45])
    tap(app.buttons["continueMealTimes"], in: app)
    XCTAssertEqual(try clockMinutes(in: pause, app: app), [edited[1], edited[0]])
    XCTAssertTrue((pause.value as? String)?.contains("14 timer") == true)
    attachOnboarding(app, name: "Onboarding-personal-pause-edited-times")
    tap(app.buttons["onboardingBack"], in: app)
    tap(app.buttons["onboardingBack"], in: app)
    XCTAssertTrue(app.buttons["setupRhythm.fourteen"].isSelected)
    // Returning to the selector, or tapping the same rhythm, must retain edited times.
    tap(app.buttons["setupRhythm.fourteen"], in: app)
    tap(app.buttons["continueWindows"], in: app)
    XCTAssertEqual(try clockMinutes(in: slider, app: app), edited)
    previewWeek(in: app)
    XCTAssertEqual(progress.value as? String, "Steg 5 av 5")
    tap(app.buttons["finishSetup"], in: app)
    XCTAssertTrue(app.buttons["fastingAction"].waitForExistence(timeout: 5))
  }

  func testOnboardingEducationWithReducedMotion() throws {
    guard UIAccessibility.isReduceMotionEnabled else {
      throw XCTSkip("Enable Reduce Motion on the test simulator for this check.")
    }
    try testOnboardingEducationAndProgress()
  }

  func testOnboardingEducationAtLargestText() throws {
    let app = app("onboarding", largeText: true)
    tap(app.buttons["beginSetup"], in: app)
    XCTAssertTrue(app.buttons["beginSetup"].waitForNonExistence(timeout: 3))
    XCTAssertTrue(app.buttons["continueWindows"].isHittable)
    try app.performAccessibilityAudit(for: [.textClipped, .hitRegion])
    attachOnboarding(app, name: "Onboarding-windows-largest-text")
    tap(app.buttons["setupRhythm.fourteen"], in: app)
    try app.performAccessibilityAudit(for: [.textClipped, .hitRegion])
    reveal(app.buttons["setupRhythm.custom"], in: app)
    attachOnboarding(app, name: "Onboarding-windows-largest-text-scrolled")
    tap(app.buttons["continueWindows"], in: app)
    XCTAssertTrue(app.buttons["continueMealTimes"].isHittable)
    tap(app.buttons["continueMealTimes"], in: app)
    XCTAssertTrue(app.buttons["previewSetup"].isHittable)
    try app.performAccessibilityAudit(for: [.textClipped, .hitRegion])
    let pause = app.descendants(matching: .any)
      .matching(identifier: "onboardingNightExplanation").firstMatch
    XCTAssertTrue((pause.value as? String)?.contains("14 hours") == true)
    XCTAssertFalse(app.buttons["onboardingLateDinner"].exists)
    XCTAssertFalse(app.buttons["onboardingUsualDinner"].exists)
    reveal(pause, in: app)
    attachOnboarding(app, name: "Onboarding-personal-pause-largest-text")
    tap(app.buttons["onboardingSafetyGuide"], in: app)
    tap(app.buttons["Done"], in: app)
    XCTAssertTrue(app.buttons["previewSetup"].isHittable)
  }

  private func attachOnboarding(_ app: XCUIApplication, name: String) {
    // Artwork continues animating after navigation. Capture its settled composition.
    let settling = XCTestExpectation(description: "Onboarding artwork settles")
    settling.isInverted = true
    XCTAssertEqual(XCTWaiter.wait(for: [settling], timeout: 1.4), .completed)
    attach(app, name: name)
  }

  private func tap(_ element: XCUIElement, in app: XCUIApplication) {
    reveal(element, in: app)
    element.tap()
  }

  private func visibleContent(in app: XCUIApplication) -> CGRect {
    let scroll = app.scrollViews.firstMatch
    var bounds = scroll.exists ? scroll.frame.intersection(app.frame) : app.frame
    for bar in app.navigationBars.allElementsBoundByIndex where bar.exists {
      if bar.frame.minY < bounds.midY {
        bounds.origin.y = max(bounds.minY, bar.frame.maxY)
      }
    }
    var bottom = min(bounds.maxY, app.frame.maxY)
    let primaryActions = [
      "beginSetup", "continueWindows", "continueMealTimes", "previewSetup",
      "finishSetup", "confirmMealTimes",
      "saveReflection",
    ]
    for identifier in primaryActions {
      let action = app.buttons[identifier]
      if action.exists && action.isHittable { bottom = min(bottom, action.frame.minY - 12) }
    }
    let tabs = app.tabBars.firstMatch
    if tabs.exists { bottom = min(bottom, tabs.frame.minY - 8) }
    let keyboard = app.keyboards.firstMatch
    if keyboard.exists { bottom = min(bottom, keyboard.frame.minY - 8) }
    bounds.size.height = max(1, bottom - bounds.minY)
    return bounds.insetBy(dx: 8, dy: 8)
  }

  private func scrollContent(
    in app: XCUIApplication, towardTop: Bool, distance: CGFloat? = nil
  ) {
    let bounds = visibleContent(in: app)
    let travel = min(distance ?? bounds.height * 0.6, bounds.height * 0.7)
    let center = bounds.midY
    // Start inside the padded content. A slow drag in its outer gutter can be
    // forwarded to a nearby button as a tap instead of reaching the scroll view.
    let start = CGPoint(x: bounds.minX + 24, y: center + (towardTop ? -travel : travel) / 2)
    let end = CGPoint(x: start.x, y: center + (towardTop ? travel : -travel) / 2)
    let origin = app.coordinate(withNormalizedOffset: .zero)
    origin.withOffset(CGVector(dx: start.x, dy: start.y)).press(
      forDuration: 0, thenDragTo: origin.withOffset(CGVector(dx: end.x, dy: end.y)),
      withVelocity: .slow, thenHoldForDuration: 0.2)
  }

  private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
    for attempt in 0..<12 {
      let bounds = visibleContent(in: app)
      if element.exists {
        let fixedActions = [
          "beginSetup", "continueWindows", "continueMealTimes", "previewSetup",
          "finishSetup", "confirmMealTimes",
          "skipMealTimes", "saveReflection", "reflectionBack",
        ]
        if element.isHittable
          && (fixedActions.contains(element.identifier)
            || (["Back", "Tilbake"].contains(element.label) && element.frame.minY > bounds.maxY))
        {
          return
        }
        let scroll = app.scrollViews.firstMatch
        let inScroll =
          scroll.exists
          && scroll.descendants(matching: element.elementType).matching(
            NSPredicate(
              format: "identifier == %@ AND label == %@", element.identifier, element.label)
          ).firstMatch.exists
        if element.isHittable && !inScroll { return }
        let fits = element.frame.height <= bounds.height
        let visible =
          fits
          ? element.frame.minY >= bounds.minY && element.frame.maxY <= bounds.maxY
          : bounds.contains(CGPoint(x: element.frame.midX, y: element.frame.midY))
        if element.isHittable && visible { return }
        let towardTop = element.frame.midY < bounds.midY
        let distance = fits
          ? (towardTop ? bounds.minY - element.frame.minY : element.frame.maxY - bounds.maxY)
          : abs(element.frame.midY - bounds.midY)
        scrollContent(in: app, towardTop: towardTop, distance: max(20, distance + 8))
      } else {
        // Offscreen accessibility rows may be absent. Search both directions so a retained
        // scroll position does not hide an earlier weekday or History entry from the test.
        scrollContent(in: app, towardTop: attempt >= 6)
      }
    }
    XCTAssertTrue(element.exists)
    XCTAssertTrue(element.isHittable, "Could not reveal \(element.identifier): \(element.label)")
    XCTFail(
      "The target remained outside the unobscured scroll content: \(element.identifier) "
        + "\(element.frame), visible \(visibleContent(in: app))")
  }

  func testGuidedSetupPreviewAndGuide() throws {
    let app = app("onboarding", language: "nb")
    tap(app.buttons["beginSetup"], in: app)
    tap(app.buttons["setupRhythm.fourteen"], in: app)
    continueIntroduction(in: app)
    XCTAssertFalse(app.pickerWheels.firstMatch.exists)
    XCTAssertTrue(
      app.descendants(matching: .any).matching(identifier: "setupWindowSlider").firstMatch
        .waitForExistence(timeout: 3))
    attach(app, name: "Guided-meal-times-norsk")
    try app.performAccessibilityAudit(for: [
      .textClipped, .hitRegion, .sufficientElementDescription,
    ])
    tap(app.buttons["continueMealTimes"], in: app)
    attach(app, name: "Guided-pause-norsk")
    tap(app.buttons["onboardingSafetyGuide"], in: app)
    attach(app, name: "Fasting-guide-norsk")
    tap(app.buttons["Ferdig"], in: app)
    tap(app.buttons["previewSetup"], in: app)
    XCTAssertTrue(
      app.descendants(matching: .any).matching(identifier: "setupWindowSlider.1").firstMatch.exists)
    XCTAssertFalse(app.pickerWheels.firstMatch.exists)
    for day in 1...7 {
      let slider = app.descendants(matching: .any)
        .matching(identifier: "setupWindowSlider.\(day)").firstMatch
      reveal(slider, in: app)
      XCTAssertTrue(slider.isHittable)
    }
    attach(app, name: "Guided-week-preview-norsk")
    tap(app.buttons["finishSetup"], in: app)
    XCTAssertTrue(app.buttons["fastingAction"].waitForExistence(timeout: 5))
  }

  func testGuidedSetupSlidersKeepLengthAndSaveWeekEdits() throws {
    // A frozen clock hides weekday rows losing their identity during drag updates.
    let app = app("onboardingLiveClock", language: "nb")
    tap(app.buttons["beginSetup"], in: app)
    tap(app.buttons["setupRhythm.fourteen"], in: app)
    continueIntroduction(in: app)
    XCTAssertFalse(app.pickerWheels.firstMatch.exists)
    let daily = app.descendants(matching: .any).matching(identifier: "setupWindowSlider").firstMatch
    XCTAssertTrue(daily.waitForExistence(timeout: 3))
    let initial = try clockMinutes(in: daily, app: app)
    XCTAssertEqual(initial, [9 * 60, 19 * 60])
    dragWindow(daily, byDayFraction: 0.125, in: app)
    let moved = try clockMinutes(in: daily, app: app)
    XCTAssertEqual(moved, [12 * 60, 22 * 60])
    XCTAssertEqual((moved[1] - moved[0] + 1440) % 1440, 10 * 60)
    XCTAssertFalse(app.pickerWheels.firstMatch.exists)
    attach(app, name: "Onboarding-shifted-ten-hour-window")

    previewWeek(in: app)
    for day in 1...7 {
      let slider = app.descendants(matching: .any)
        .matching(identifier: "setupWindowSlider.\(day)").firstMatch
      XCTAssertEqual(try clockMinutes(in: slider, app: app), moved)
    }
    let sunday = app.descendants(matching: .any).matching(identifier: "setupWindowSlider.1")
      .firstMatch
    dragWindow(sunday, byDayFraction: 0.0625, in: app)
    let edited = try clockMinutes(in: sunday, app: app)
    XCTAssertEqual(edited, [13 * 60 + 30, 23 * 60 + 30])
    XCTAssertEqual((edited[1] - edited[0] + 1440) % 1440, 10 * 60)
    for day in 2...7 {
      let slider = app.descendants(matching: .any)
        .matching(identifier: "setupWindowSlider.\(day)").firstMatch
      XCTAssertEqual(
        try clockMinutes(in: slider, app: app), moved, "Only the edited weekday should move")
    }
    let sundayTimes = app.descendants(matching: .any).matching(identifier: "setupDayTimes.1")
      .firstMatch
    XCTAssertEqual(try clockMinutes(in: sundayTimes, app: app), edited)
    attach(app, name: "Onboarding-edited-Sunday-preview")
    tap(app.buttons["Tilbake"], in: app)
    tap(app.buttons["Tilbake"], in: app)
    XCTAssertEqual(try clockMinutes(in: daily, app: app), moved)
    previewWeek(in: app)
    for day in 1...7 {
      let retained = app.descendants(matching: .any)
        .matching(identifier: "setupWindowSlider.\(day)").firstMatch
      XCTAssertEqual(
        try clockMinutes(in: retained, app: app), day == 1 ? edited : moved,
        "Returning to the preview should preserve individual weekday edits")
    }
    tap(app.buttons["finishSetup"], in: app)
    XCTAssertTrue(app.tabBars.buttons["Plan"].waitForExistence(timeout: 5))
    tap(app.tabBars.buttons["Plan"], in: app)
    XCTAssertTrue(app.buttons["weekOptions"].waitForExistence(timeout: 3))
    for day in 1...7 {
      let saved = app.descendants(matching: .any).matching(identifier: "dayTimes.\(day)").firstMatch
      XCTAssertEqual(try clockMinutes(in: saved, app: app), day == 1 ? edited : moved)
    }
    attach(app, name: "Onboarding-week-edits-persisted-in-Plan")

    app.terminate()
    let custom = self.app("onboarding", language: "nb")
    tap(custom.buttons["beginSetup"], in: custom)
    tap(custom.buttons["setupRhythm.custom"], in: custom)
    continueIntroduction(in: custom)
    tap(custom.buttons["setupWindowLength"], in: custom)
    let eightHours = Duration.seconds(8 * 60 * 60).formatted(
      .units(allowed: [.hours, .minutes], width: .abbreviated).locale(Locale(identifier: "nb_NO")))
    tap(custom.buttons[eightHours], in: custom)
    XCTAssertFalse(custom.pickerWheels.firstMatch.exists)
    let customSlider = custom.descendants(matching: .any)
      .matching(identifier: "setupWindowSlider").firstMatch
    XCTAssertEqual(try clockMinutes(in: customSlider, app: custom), [8 * 60, 16 * 60])
    dragWindow(customSlider, byDayFraction: 0.375, in: custom)
    let overnight = try clockMinutes(in: customSlider, app: custom)
    XCTAssertEqual(overnight, [17 * 60, 60])
    XCTAssertEqual((overnight[1] - overnight[0] + 1440) % 1440, 8 * 60)
    attach(custom, name: "Onboarding-custom-eight-hour-window-across-midnight")
    tap(custom.buttons["continueMealTimes"], in: custom)
    let pause = custom.descendants(matching: .any)
      .matching(identifier: "onboardingNightExplanation").firstMatch
    XCTAssertEqual(try clockMinutes(in: pause, app: custom), [60, 17 * 60])
    XCTAssertTrue((pause.value as? String)?.contains("16 timer") == true)
    XCTAssertFalse((pause.value as? String)?.contains("+1 dag") == true)
    attachOnboarding(custom, name: "Onboarding-personal-daytime-pause")
  }

  func testGuidedSetupActionsStayPinnedAtLargestText() throws {
    let app = app("onboarding", language: "nb", largeText: true)
    tap(app.buttons["beginSetup"], in: app)
    assertPinnedAction(
      app.buttons["continueWindows"], whileScrolling: app.buttons["setupRhythm.twelve"], in: app)
    attach(app, name: "Onboarding-rhythm-pinned-footer-largest-text")
    continueIntroduction(in: app)
    XCTAssertFalse(app.pickerWheels.firstMatch.exists)
    let daily = app.descendants(matching: .any).matching(identifier: "setupWindowSlider").firstMatch
    assertPinnedAction(app.buttons["continueMealTimes"], whileScrolling: daily, in: app)
    XCTAssertGreaterThanOrEqual(daily.frame.minX, app.frame.minX)
    XCTAssertLessThanOrEqual(daily.frame.maxX, app.frame.maxX)
    attach(app, name: "Onboarding-slider-pinned-footer-largest-text")
    previewWeek(in: app)
    XCTAssertFalse(app.pickerWheels.firstMatch.exists)
    disableSetupCloudSync(in: app)
    let firstDay = app.descendants(matching: .any)
      .matching(NSPredicate(format: "identifier BEGINSWITH %@", "setupDayTimes.")).firstMatch
    assertPinnedAction(app.buttons["finishSetup"], whileScrolling: firstDay, in: app)
    attach(app, name: "Onboarding-week-pinned-footer-largest-text")
    tap(app.buttons["finishSetup"], in: app)
    XCTAssertTrue(app.buttons["fastingAction"].waitForExistence(timeout: 5))
    assertSetupCloudSyncRemainsDisabled(in: app, language: "nb")
  }

  func testGuidedSetupAccessibilityAtLargestText() throws {
    let app = app("onboarding", language: "nb", largeText: true)
    tap(app.buttons["beginSetup"], in: app)
    continueIntroduction(in: app)
    try app.performAccessibilityAudit(for: [.textClipped, .hitRegion])
    previewWeek(in: app)
    try app.performAccessibilityAudit(for: [.textClipped, .hitRegion])
  }

  func testReflectionActionsStayPinnedAtLargestText() throws {
    let app = app("reflection", largeText: true)
    tap(app.buttons["openReflection"], in: app)
    app.buttons["planExperience.changed"].tap()
    assertPinnedAction(
      app.buttons["confirmMealTimes"], whileScrolling: app.staticTexts["reflectionQuestion"],
      in: app)
    XCTAssertTrue(app.buttons["skipMealTimes"].isHittable)
    XCTAssertTrue(app.buttons["reflectionBack"].isHittable)
    attach(app, name: "Reflection-meals-pinned-footer-largest-text")
    tap(app.buttons["skipMealTimes"], in: app)
    tap(app.buttons["feeling.comfortable"], in: app)
    assertPinnedAction(
      app.buttons["saveReflection"], whileScrolling: app.staticTexts["reflectionQuestion"], in: app)
    attach(app, name: "Reflection-feeling-pinned-footer-largest-text")
    tap(app.buttons["saveReflection"], in: app)
    XCTAssertTrue(app.buttons["openReflection"].waitForNonExistence(timeout: 3))
  }

  private func clockMinutes(in element: XCUIElement, app: XCUIApplication) throws -> [Int] {
    XCTAssertTrue(element.waitForExistence(timeout: 3))
    let value = element.value as? String ?? ""
    let text = value.isEmpty ? element.label : value
    let expression = try NSRegularExpression(pattern: #"(?<!\d)(\d{1,2}):(\d{2})(?!\d)"#)
    let matches = expression.matches(in: text, range: NSRange(text.startIndex..., in: text))
    guard matches.count == 2 else {
      XCTFail("Expected two clock times in accessibility text: \(text)")
      throw NSError(domain: "KvilUITests.ClockTimes", code: 1)
    }
    return try matches.map { match in
      let hours = try XCTUnwrap(Range(match.range(at: 1), in: text))
      let minutes = try XCTUnwrap(Range(match.range(at: 2), in: text))
      return try XCTUnwrap(Int(text[hours])) * 60 + XCTUnwrap(Int(text[minutes]))
    }
  }

  private func dragWindow(
    _ slider: XCUIElement, byDayFraction fraction: CGFloat, in app: XCUIApplication
  ) {
    reveal(slider, in: app)
    XCTAssertLessThan(slider.frame.maxY, visibleContent(in: app).maxY)
    slider.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
      forDuration: 0.1,
      thenDragTo: slider.coordinate(withNormalizedOffset: CGVector(dx: 0.5 + fraction, dy: 0.5)))
  }

  private func assertPinnedAction(
    _ action: XCUIElement, whileScrolling content: XCUIElement, in app: XCUIApplication
  ) {
    XCTAssertTrue(action.waitForExistence(timeout: 3))
    XCTAssertTrue(action.isHittable, "The action should be visible before scrolling")
    XCTAssertGreaterThanOrEqual(action.frame.minY, app.frame.minY)
    XCTAssertLessThanOrEqual(action.frame.maxY, app.frame.maxY)
    XCTAssertGreaterThanOrEqual(action.frame.minX, app.frame.minX)
    XCTAssertLessThanOrEqual(action.frame.maxX, app.frame.maxX)
    let actionY = action.frame.minY
    reveal(content, in: app)
    let contentY = content.frame.minY
    let bounds = visibleContent(in: app)
    let distance = min(100, max(30, content.frame.maxY - bounds.minY - 12))
    scrollContent(in: app, towardTop: false, distance: distance)
    if content.exists && abs(content.frame.minY - contentY) <= 20 {
      scrollContent(in: app, towardTop: true, distance: distance)
    }
    XCTAssertTrue(content.exists)
    XCTAssertGreaterThan(
      abs(content.frame.minY - contentY), 20, "The page content must actually scroll")
    XCTAssertTrue(action.isHittable)
    XCTAssertEqual(action.frame.minY, actionY, accuracy: 1)
  }

  func testReflectionChangedTimesAndNote() throws {
    let app = app("reflection", language: "nb")
    tap(app.buttons["openReflection"], in: app)
    tap(app.buttons["planExperience.changed"], in: app)
    XCTAssertFalse(app.buttons["feeling.mixed"].exists)
    XCTAssertTrue(app.pickerWheels.firstMatch.waitForExistence(timeout: 3))
    app.pickerWheels.element(boundBy: 0).adjust(toPickerWheelValue: "09")
    attach(app, name: "Reflection-approximate-meals-norsk")
    tap(app.buttons["confirmMealTimes"], in: app)
    tap(app.buttons["feeling.mixed"], in: app)
    tap(app.buttons["Noe du vil huske?"], in: app)
    let note =
      app.textViews["reflectionNote"].exists
      ? app.textViews["reflectionNote"] : app.textFields["reflectionNote"]
    tap(note, in: app)
    note.typeText("Rolig middag.")
    attach(app, name: "Reflection-feeling-note-norsk")
    tap(app.buttons["saveReflection"], in: app)
    XCTAssertTrue(app.buttons["openReflection"].waitForNonExistence(timeout: 3))
    app.tabBars.buttons["Historikk"].tap()
    tap(app.staticTexts["Rolig middag."].firstMatch, in: app)
    XCTAssertTrue(app.staticTexts["Omtrentlige måltidstider"].waitForExistence(timeout: 3))
    attach(app, name: "Reflection-detail-norsk")
    try app.performAccessibilityAudit(for: [
      .textClipped, .hitRegion, .sufficientElementDescription,
    ])
  }

  func testReflectionUnknownTimesAndCancel() {
    let app = app("reflection")
    tap(app.buttons["openReflection"], in: app)
    tap(app.buttons["planExperience.changed"], in: app)
    tap(app.buttons["skipMealTimes"], in: app)
    tap(app.buttons["feeling.difficult"], in: app)
    tap(app.buttons["cancelReflection"], in: app)
    XCTAssertTrue(app.buttons["openReflection"].waitForExistence(timeout: 3))
    tap(app.buttons["openReflection"], in: app)
    XCTAssertTrue(app.buttons["planExperience.asPlanned"].waitForExistence(timeout: 3))
    tap(app.buttons["planExperience.unsure"], in: app)
    tap(app.buttons["skipMealTimes"], in: app)
    tap(app.buttons["feeling.comfortable"], in: app)
    tap(app.buttons["saveReflection"], in: app)
    XCTAssertTrue(app.buttons["openReflection"].waitForNonExistence(timeout: 3))
  }

  func testReflectionDayOffAtLargestText() throws {
    let app = app("reflectionDayOff", largeText: true)
    tap(app.buttons["openReflection"], in: app)
    XCTAssertFalse(app.buttons["planExperience.asPlanned"].exists)
    XCTAssertFalse(app.pickerWheels.firstMatch.exists)
    tap(app.buttons["feeling.comfortable"], in: app)
    attach(app, name: "Reflection-day-off-largest-text")
    try app.performAccessibilityAudit(for: [
      .textClipped, .hitRegion, .sufficientElementDescription,
    ])
    tap(app.buttons["saveReflection"], in: app)
    XCTAssertTrue(app.buttons["openReflection"].waitForNonExistence(timeout: 3))
  }

  func testDayOffAndResumeFlow() throws {
    let app = app("home")
    app.tabBars.buttons["Schedule"].tap()
    tap(app.buttons["todayMenu"], in: app)
    tap(app.buttons["Take today off"], in: app)
    app.tabBars.buttons["Home"].tap()
    XCTAssertTrue(
      app.descendants(matching: .any).matching(identifier: "homeDayOff").firstMatch
        .waitForExistence(timeout: 3))
    XCTAssertFalse(app.buttons["fastingAction"].exists)
    attach(app, name: "Home-day-off")
    try app.performAccessibilityAudit(for: [
      .textClipped, .hitRegion, .sufficientElementDescription,
    ])
    app.tabBars.buttons["Schedule"].tap()
    attach(app, name: "Schedule-day-off")
    tap(app.buttons["resumeScheduleToday"], in: app)
    app.tabBars.buttons["Home"].tap()
    XCTAssertTrue(app.buttons["fastingAction"].waitForExistence(timeout: 3))
    app.tabBars.buttons["Schedule"].tap()
    tap(app.buttons["planScheduleBreak"], in: app)
    attach(app, name: "Planned-break-sheet")
    tap(app.buttons["saveScheduleBreak"], in: app)
    app.tabBars.buttons["Home"].tap()
    XCTAssertTrue(
      app.descendants(matching: .any).matching(identifier: "homeDayOff").firstMatch
        .waitForExistence(timeout: 3))
  }

  func testUpcomingDaysOffDoNotCountAsFasting() throws {
    let app = app("upcomingDayOff", largeText: true)
    XCTAssertTrue(
      app.descendants(matching: .any).matching(identifier: "homeUpcomingDayOff").firstMatch
        .waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["fastingAction"].exists)
    XCTAssertFalse(app.staticTexts["countdown"].exists)
    attach(app, name: "Upcoming-days-off-largest-text")
    try app.performAccessibilityAudit(for: [.textClipped, .sufficientElementDescription])
  }

  func testNativeConvenienceSettings() throws {
    let app = app("home")
    tap(app.tabBars.buttons["Schedule"], in: app)
    tap(app.buttons["settings"], in: app)
    tap(app.switches["When the window opens"].switches.firstMatch, in: app)
    XCTAssertEqual(app.switches["When the window opens"].value as? String, "1")
    XCTAssertEqual(app.buttons["openingReminderTiming"].value as? String, "At the planned time")
    tap(app.buttons["openingReminderTiming"], in: app)
    tap(app.buttons["15 minutes before"], in: app)
    tap(app.switches["When the window closes"].switches.firstMatch, in: app)
    XCTAssertEqual(app.switches["When the window closes"].value as? String, "1")
    XCTAssertEqual(app.buttons["closingReminderTiming"].value as? String, "15 minutes before")
    attach(app, name: "Default-closing-reminder")
    let closingTiming = app.buttons["closingReminderTiming"]
    closingTiming.staticTexts["15 minutes before"].coordinate(
      withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    XCTAssertTrue(app.buttons["30 minutes before"].waitForExistence(timeout: 3))
    app.buttons["30 minutes before"].tap()
    closingTiming.staticTexts["30 minutes before"].coordinate(
      withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    XCTAssertTrue(app.buttons["15 minutes before"].waitForExistence(timeout: 3))
    app.buttons["15 minutes before"].tap()
    tap(app.switches["liveActivities"].switches.firstMatch, in: app)
    XCTAssertEqual(app.switches["liveActivities"].value as? String, "1")
    attach(app, name: "Advance-reminders-and-Live-Activities")
    try app.performAccessibilityAudit(for: [.textClipped, .hitRegion])
    tap(app.buttons["Done"], in: app)
    tap(app.buttons["settings"], in: app)
    XCTAssertEqual(app.buttons["openingReminderTiming"].value as? String, "15 minutes before")
    XCTAssertEqual(app.buttons["closingReminderTiming"].value as? String, "15 minutes before")
  }

  func testReminderTimingAtLargestText() throws {
    let app = app("home", largeText: true)
    tap(app.tabBars.buttons["Schedule"], in: app)
    tap(app.buttons["settings"], in: app)
    tap(app.switches["When the window closes"].switches.firstMatch, in: app)
    let reminder = app.buttons["closingReminderTiming"]
    XCTAssertEqual(reminder.value as? String, "15 minutes before")
    // The new row starts below the visible content at the largest text size.
    scrollContent(in: app, towardTop: false)
    // Tap the visible menu value within the accessible button.
    let menuLabel = reminder.staticTexts["15 minutes before"]
    XCTAssertTrue(menuLabel.exists)
    menuLabel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    attach(app, name: "Closing-reminder-menu-largest-text")
    XCTAssertTrue(app.buttons["At the planned time"].waitForExistence(timeout: 3))
    app.buttons["At the planned time"].tap()
    XCTAssertEqual(reminder.value as? String, "At the planned time")
    XCTAssertTrue(reminder.isHittable)
    XCTAssertGreaterThanOrEqual(reminder.frame.minX, app.frame.minX)
    XCTAssertLessThanOrEqual(reminder.frame.maxX, app.frame.maxX)
    attach(app, name: "Reminder-timing-largest-text")
    try auditCurrentScreen(app, for: [.textClipped, .hitRegion])
    XCTAssertTrue(reminder.isHittable)
    XCTAssertEqual(reminder.value as? String, "At the planned time")
    attach(app, name: "Reminder-timing-after-text-size-audit")
    let selectedValue = reminder.staticTexts["At the planned time"]
    XCTAssertTrue(
      visibleContent(in: app).contains(
        CGPoint(x: selectedValue.frame.midX, y: selectedValue.frame.midY)))
    selectedValue.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    XCTAssertTrue(app.buttons["30 minutes before"].waitForExistence(timeout: 3))
    app.buttons["30 minutes before"].tap()
    XCTAssertEqual(reminder.value as? String, "30 minutes before")
  }

  func testSettingsWeightSyncAndNavigation() throws {
    let app = app("home")
    tap(app.tabBars.buttons["Schedule"], in: app)
    tap(app.buttons["settings"], in: app)
    let weight = app.switches["Show weight logging"]
    tap(weight.switches.firstMatch, in: app)
    XCTAssertEqual(weight.value as? String, "1")
    let unit = app.buttons["weightUnit"]
    tap(unit, in: app)
    tap(app.buttons["lb"], in: app)
    XCTAssertTrue(unit.staticTexts["lb"].exists)
    attach(app, name: "Settings-weight-unit-menu")
    try auditCurrentScreen(app, for: [.textClipped, .hitRegion, .sufficientElementDescription])

    let cloud = app.switches["cloudScheduleSync"]
    tap(cloud.switches.firstMatch, in: app)
    XCTAssertEqual(cloud.value as? String, "0")
    XCTAssertFalse(app.staticTexts["cloudSyncStatus"].exists)
    tap(cloud.switches.firstMatch, in: app)
    XCTAssertEqual(cloud.value as? String, "1")
    XCTAssertTrue(app.staticTexts["cloudSyncStatus"].exists)
    tap(app.buttons["Privacy"], in: app)
    XCTAssertTrue(app.staticTexts["privacyStorage"].waitForExistence(timeout: 3))
    app.navigationBars["Privacy"].buttons.element(boundBy: 0).tap()
    tap(app.buttons["About Kvil"], in: app)
    XCTAssertTrue(app.navigationBars["About Kvil"].waitForExistence(timeout: 3))
    app.navigationBars["About Kvil"].buttons.element(boundBy: 0).tap()
    attach(app, name: "Settings-data-and-navigation")
    try auditCurrentScreen(app, for: [.textClipped, .hitRegion, .sufficientElementDescription])
    tap(app.buttons["Done"], in: app)
    tap(app.buttons["settings"], in: app)
    reveal(unit, in: app)
    XCTAssertTrue(unit.staticTexts["lb"].exists)
  }

  func testReflectionProgressionAtLargestText() throws {
    let app = app("reflection", largeText: true)
    tap(app.buttons["openReflection"], in: app)
    attach(app, name: "Reflection-plan-largest-text")
    tap(app.buttons["planExperience.changed"], in: app)
    XCTAssertTrue(app.buttons["confirmMealTimes"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.buttons["saveReflection"].exists)
    XCTAssertTrue(app.staticTexts["reflectionQuestion"].isHittable)
    attach(app, name: "Reflection-meals-largest-text")
    tap(app.buttons["skipMealTimes"], in: app)
    XCTAssertTrue(app.buttons["saveReflection"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["reflectionQuestion"].isHittable)
    attach(app, name: "Reflection-feeling-largest-text")
    tap(app.buttons["feeling.comfortable"], in: app)
    tap(app.buttons["saveReflection"], in: app)
    XCTAssertTrue(app.buttons["openReflection"].waitForNonExistence(timeout: 3))
  }

  private func attach(_ app: XCUIApplication, name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
  func testTodayWindowDragLengthAndReset() throws {
    let app = app("home")
    app.tabBars.buttons["Schedule"].tap()
    XCTAssertTrue(app.buttons["todayMenu"].waitForExistence(timeout: 5))
    let today = app.descendants(matching: .any).matching(identifier: "todayWindow").firstMatch
    let original = today.label
    let week = (1...7).map { app.staticTexts["dayTimes.\($0)"].label }
    let bar = app.descendants(matching: .any).matching(identifier: "todayWindowSlider").firstMatch
    let barY = bar.frame.minY
    let timeHeight = today.frame.height
    let weekY = app.buttons["weekOptions"].frame.minY
    app.buttons["todayMenu"].tap()
    app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Window length")).firstMatch
      .tap()
    app.buttons["6 hr"].tap()
    XCTAssertTrue(today.label.contains("4:00"), today.label)
    XCTAssertEqual(bar.frame.minY, barY, accuracy: 1)
    bar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
      forDuration: 0.1,
      thenDragTo: bar.coordinate(withNormalizedOffset: CGVector(dx: 0.625, dy: 0.5)))
    XCTAssertTrue(today.label.contains("1:00"), today.label)
    XCTAssertTrue(today.label.contains("7:00"), today.label)
    XCTAssertEqual(bar.frame.minY, barY, accuracy: 1)
    XCTAssertEqual(today.frame.height, timeHeight, accuracy: 1)
    XCTAssertEqual((1...7).map { app.staticTexts["dayTimes.\($0)"].label }, week)
    attach(app, name: "Today-draggable-window")
    app.buttons["todayMenu"].tap()
    attach(app, name: "Today-window-menu")
    app.buttons["Set exact times"].tap()
    let opening = app.staticTexts["openingTime"]
    XCTAssertTrue(opening.waitForExistence(timeout: 3))
    XCTAssertTrue(opening.label.contains("1:00"), opening.label)
    XCTAssertEqual(app.pickerWheels.count, 0)
    let editorBar = app.descendants(matching: .any).matching(identifier: "editorWindowSlider")
      .firstMatch
    XCTAssertTrue(editorBar.isHittable)
    XCTAssertGreaterThan(app.buttons["saveSchedule"].frame.minY, app.frame.height * 0.4)
    editorBar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
      forDuration: 0.1,
      thenDragTo: editorBar.coordinate(withNormalizedOffset: CGVector(dx: 0.625, dy: 0.5)))
    XCTAssertTrue(opening.label.contains("4:00"), opening.label)
    attach(app, name: "Today-editor-grabber")
    app.buttons["Cancel"].tap()
    XCTAssertTrue(today.label.contains("1:00"), today.label)
    XCTAssertTrue(today.label.contains("7:00"), today.label)
    bar.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.5)).press(
      forDuration: 0.1,
      thenDragTo: bar.coordinate(withNormalizedOffset: CGVector(dx: 0.925, dy: 0.5)))
    XCTAssertTrue(today.label.contains("10:00"), today.label)
    XCTAssertTrue(today.label.contains("4:00"), today.label)
    XCTAssertTrue(today.label.contains("Closes the following day"), today.label)
    XCTAssertEqual(bar.frame.minY, barY, accuracy: 1)
    XCTAssertEqual(today.frame.height, timeHeight, accuracy: 1)
    XCTAssertEqual(app.buttons["weekOptions"].frame.minY, weekY, accuracy: 1)
    attach(app, name: "Today-overnight-window")
    bar.coordinate(withNormalizedOffset: CGVector(dx: 0.925, dy: 0.5)).press(
      forDuration: 0.1,
      thenDragTo: bar.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.5)))
    XCTAssertFalse(today.label.contains("Closes the following day"), today.label)
    XCTAssertEqual(bar.frame.minY, barY, accuracy: 1)
    XCTAssertEqual(app.buttons["weekOptions"].frame.minY, weekY, accuracy: 1)
    app.buttons["todayMenu"].tap()
    app.buttons["Use usual schedule today"].tap()
    XCTAssertEqual(today.label, original)
    XCTAssertEqual((1...7).map { app.staticTexts["dayTimes.\($0)"].label }, week)

    app.tabBars.buttons["Home"].tap()
    app.buttons["changeToday"].tap()
    XCTAssertTrue(editorBar.waitForExistence(timeout: 3))
    app.buttons["editorWindowLength"].tap()
    for hours in 1...5 { XCTAssertFalse(app.buttons["\(hours) hr"].exists) }
    XCTAssertTrue(app.buttons["6 hr"].exists)
    attach(app, name: "Six-hour-minimum-window-menu")
    app.buttons["6 hr"].tap()
    editorBar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
      forDuration: 0.1,
      thenDragTo: editorBar.coordinate(withNormalizedOffset: CGVector(dx: 0.625, dy: 0.5)))
    app.buttons["saveSchedule"].tap()
    app.tabBars.buttons["Schedule"].tap()
    XCTAssertTrue(today.label.contains("1:00"), today.label)
    XCTAssertTrue(today.label.contains("7:00"), today.label)
    XCTAssertEqual((1...7).map { app.staticTexts["dayTimes.\($0)"].label }, week)
    app.buttons["todayMenu"].tap()
    app.buttons["Set exact times"].tap()
    XCTAssertTrue(opening.waitForExistence(timeout: 3))
    XCTAssertTrue(opening.label.contains("1:00"), opening.label)
    XCTAssertTrue(app.staticTexts["closingTime"].label.contains("7:00"))
    app.buttons["Cancel"].tap()
  }

  func testTodayWindowNorwegianAndLargestText() throws {
    for largeText in [false, true] {
      let app = app("home", language: "nb", largeText: largeText)
      app.tabBars.buttons["Plan"].tap()
      XCTAssertTrue(app.buttons["todayMenu"].waitForExistence(timeout: 5))
      attach(app, name: largeText ? "Today-Norwegian-largest-text" : "Today-Norwegian")
      try app.performAccessibilityAudit(for: [.textClipped])
      app.buttons["todayMenu"].tap()
      XCTAssertTrue(
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Vinduslengde")).firstMatch
          .exists)
      app.buttons["Angi nøyaktige tider"].tap()
      XCTAssertTrue(app.buttons["saveSchedule"].waitForExistence(timeout: 3))
      XCTAssertEqual(app.pickerWheels.count, 0)
      attach(app, name: largeText ? "Today-editor-Norwegian-largest-text" : "Today-editor-Norwegian")
      let slider = app.descendants(matching: .any).matching(identifier: "editorWindowSlider")
        .firstMatch
      let sheet = app.scrollViews.containing(.any, identifier: "editorWindowSlider").firstMatch
      for _ in 0..<8 where !slider.isHittable { sheet.swipeUp() }
      XCTAssertTrue(slider.isHittable)
      XCTAssertGreaterThanOrEqual(slider.frame.minX, app.frame.minX)
      XCTAssertLessThanOrEqual(slider.frame.maxX, app.frame.maxX)
      attach(app, name: largeText ? "Today-editor-largest-text-grabber" : "Today-editor-fitted")
      try app.performAccessibilityAudit(for: [.sufficientElementDescription])
      let length = app.buttons["editorWindowLength"]
      for _ in 0..<8 where !length.isHittable { sheet.swipeUp() }
      XCTAssertTrue(length.isHittable)
      attach(app, name: largeText ? "Today-editor-largest-text-length" : "Today-editor-length")
      app.buttons["Avbryt"].tap()
      app.terminate()
    }
  }

  func testDragWindowAndSetLengthsForAllDays() throws {
    let app = app("home")
    app.tabBars.buttons["Schedule"].tap()
    XCTAssertTrue(app.buttons["weekOptions"].waitForExistence(timeout: 5))
    let today = app.descendants(matching: .any).matching(identifier: "todayWindow").firstMatch.label
    tap(app.buttons["dayMenu.1"], in: app)
    app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Window length")).firstMatch
      .tap()
    app.buttons["6 hr"].tap()
    XCTAssertTrue(app.staticTexts["dayTimes.1"].label.contains("4:00"))
    XCTAssertTrue(app.staticTexts["dayTimes.2"].label.contains("6:00"))
    let bar = app.descendants(matching: .any).matching(identifier: "windowSlider.1").firstMatch
    reveal(bar, in: app)
    let start = bar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    let end = bar.coordinate(withNormalizedOffset: CGVector(dx: 0.625, dy: 0.5))
    start.press(forDuration: 0.1, thenDragTo: end)
    XCTAssertTrue(
      app.staticTexts["dayTimes.1"].label.contains("1:00"), app.staticTexts["dayTimes.1"].label)
    XCTAssertTrue(app.staticTexts["dayTimes.1"].label.contains("7:00"))
    XCTAssertEqual(
      app.descendants(matching: .any).matching(identifier: "todayWindow").firstMatch.label, today)
    attach(app, name: "Dragged-six-hour-window")
    tap(app.buttons["dayMenu.1"], in: app)
    app.buttons["Use this length for all days"].tap()
    XCTAssertTrue(app.staticTexts["dayTimes.2"].label.contains("4:00"))
    XCTAssertTrue(app.staticTexts["dayTimes.1"].label.contains("1:00"))
    tap(app.buttons["weekOptions"], in: app)
    app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Window length for all days"))
      .firstMatch.tap()
    attach(app, name: "All-days-window-length-menu")
    app.buttons["7 hr"].tap()
    XCTAssertTrue(app.staticTexts["dayTimes.1"].label.contains("8:00"))
    XCTAssertTrue(app.staticTexts["dayTimes.2"].label.contains("5:00"))
    attach(app, name: "Window-length-for-all-days")

    reveal(bar, in: app)
    bar.coordinate(withNormalizedOffset: CGVector(dx: 0.625, dy: 0.5)).press(
      forDuration: 0.1,
      thenDragTo: bar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
    XCTAssertTrue(app.staticTexts["dayTimes.1"].label.contains("10:00"))
    XCTAssertTrue(app.staticTexts["dayTimes.1"].label.contains("5:00"))
    let times = app.staticTexts["dayTimes.1"].label
    let originalY = bar.frame.minY
    let scrollStart = bar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    scrollStart.press(
      forDuration: 0.1, thenDragTo: scrollStart.withOffset(CGVector(dx: 0, dy: -160)))
    XCTAssertLessThan(bar.frame.minY, originalY - 80)
    XCTAssertEqual(app.staticTexts["dayTimes.1"].label, times)
    attach(app, name: "Draggable-week-scrolled")
  }

  func testExactOvernightTimesAndCopyMenus() throws {
    let app = app("home")
    app.tabBars.buttons["Schedule"].tap()
    XCTAssertTrue(app.buttons["dayMenu.1"].waitForExistence(timeout: 5))
    app.buttons["dayMenu.1"].tap()
    XCTAssertFalse(app.buttons["Paste times"].exists)
    app.buttons["Set exact times"].tap()
    let opening = app.otherElements["openingTime"]
    let closing = app.otherElements["closingTime"]
    XCTAssertTrue(opening.waitForExistence(timeout: 3))
    closing.pickerWheels.element(boundBy: 0).adjust(toPickerWheelValue: "3")
    closing.pickerWheels.element(boundBy: 1).adjust(toPickerWheelValue: "59")
    app.buttons["saveSchedule"].tap()
    XCTAssertEqual(
      app.staticTexts["scheduleValidation"].label,
      "Choose an eating window of at least six hours.")
    attach(app, name: "Exact-window-below-six-hours-rejected")
    closing.pickerWheels.element(boundBy: 0).adjust(toPickerWheelValue: "4")
    closing.pickerWheels.element(boundBy: 1).adjust(toPickerWheelValue: "00")
    app.buttons["saveSchedule"].tap()
    XCTAssertTrue(app.staticTexts["dayTimes.1"].label.contains("4:00"))
    app.buttons["dayMenu.1"].tap()
    app.buttons["Set exact times"].tap()
    XCTAssertTrue(opening.waitForExistence(timeout: 3))
    opening.pickerWheels.element(boundBy: 2).adjust(toPickerWheelValue: "PM")
    closing.pickerWheels.element(boundBy: 2).adjust(toPickerWheelValue: "AM")
    app.buttons["saveSchedule"].tap()
    XCTAssertTrue(app.staticTexts["dayTimes.1"].label.contains("+1 day"))
    attach(app, name: "Overnight-draggable-window")
    app.buttons["dayMenu.1"].tap()
    app.buttons["Copy times"].tap()
    app.buttons["dayMenu.2"].tap()
    app.buttons["Paste times"].tap()
    XCTAssertTrue(app.staticTexts["dayTimes.2"].label.contains("+1 day"))
    app.buttons["dayMenu.2"].tap()
    app.buttons["Copy times to all days"].tap()
    for day in 1...7 {
      XCTAssertTrue(app.staticTexts["dayTimes.\(day)"].label.contains("+1 day"))
    }
    app.buttons["dayMenu.1"].tap()
    app.buttons["Set exact times"].tap()
    XCTAssertTrue(opening.waitForExistence(timeout: 3))
    opening.pickerWheels.element(boundBy: 0).adjust(toPickerWheelValue: "9")
    app.buttons["Cancel"].tap()
    XCTAssertTrue(app.staticTexts["dayTimes.1"].label.contains("10:00"))
  }

  func testWindowMenusNorwegianAndLargestText() throws {
    for largeText in [false, true] {
      let app = app("home", language: "nb", largeText: largeText)
      app.tabBars.buttons["Plan"].tap()
      XCTAssertTrue(app.buttons["weekOptions"].waitForExistence(timeout: 5))
      attach(app, name: largeText ? "Draggable-plan-largest-text" : "Draggable-plan-Norwegian")
      for _ in 0..<8 where !app.buttons["dayMenu.2"].isHittable { app.swipeUp() }
      app.buttons["dayMenu.2"].tap()
      XCTAssertTrue(app.buttons["Angi nøyaktige tider"].waitForExistence(timeout: 3))
      attach(app, name: largeText ? "Day-menu-largest-text" : "Day-menu-Norwegian")
      app.buttons["Angi nøyaktige tider"].tap()
      let opening = app.otherElements["openingTime"]
      XCTAssertTrue(opening.waitForExistence(timeout: 3))
      for _ in 0..<8 where !opening.pickerWheels.firstMatch.isHittable {
        let scroll = app.scrollViews.firstMatch
        scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.8)).press(
          forDuration: 0.1,
          thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.3)))
      }
      XCTAssertGreaterThanOrEqual(opening.frame.minX, app.frame.minX)
      XCTAssertLessThanOrEqual(opening.frame.maxX, app.frame.maxX)
      XCTAssertEqual(opening.pickerWheels.count, 2)
      XCTAssertEqual(opening.pickers.element(boundBy: 0).label, "Time")
      XCTAssertEqual(opening.pickers.element(boundBy: 1).label, "Minutt")
      for wheel in opening.pickerWheels.allElementsBoundByIndex {
        XCTAssertTrue(wheel.isHittable)
        XCTAssertFalse((wheel.value as? String ?? "").isEmpty)
      }
      app.buttons["Avbryt"].tap()
      app.terminate()
    }
  }
}
