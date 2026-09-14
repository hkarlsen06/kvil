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
  func testHomeScheduleAndReflectionFlow() {
    let app = app("reflection")
    XCTAssertTrue(app.buttons["changeToday"].waitForExistence(timeout: 10))
    app.buttons["changeToday"].tap()
    XCTAssertTrue(app.buttons["saveSchedule"].waitForExistence(timeout: 3))
    app.buttons["saveSchedule"].tap()
    if app.buttons["openReflection"].exists { app.buttons["openReflection"].tap() }
    XCTAssertTrue(app.buttons["feeling.comfortable"].waitForExistence(timeout: 3))
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
    try app.performAccessibilityAudit(for: [.textClipped, .hitRegion, .sufficientElementDescription])
    action.tap()
    XCTAssertTrue(app.staticTexts["Spisevinduet\ner åpent"].waitForExistence(timeout: 3))
    XCTAssertEqual(action.label, "Start fasten nå")
    XCTAssertTrue(undo.isHittable)
    XCTAssertEqual(undo.label, "Angre tidlig fastebrudd")
    XCTAssertGreaterThan(undo.frame.minX, action.frame.maxX)
    XCTAssertEqual(undo.frame.midY, action.frame.midY, accuracy: 1)
    attach(app, name: "Eating-action-norsk")
    try app.performAccessibilityAudit(for: [.textClipped, .hitRegion, .sufficientElementDescription])
    app.tabBars.buttons["Plan"].tap()
    app.tabBars.buttons["Hjem"].tap()
    XCTAssertTrue(undo.isHittable)
    undo.tap()
    XCTAssertTrue(undo.waitForNonExistence(timeout: 3))
    XCTAssertEqual(action.label, "Bryt fasten tidlig")
    action.tap()
    action.tap()
    XCTAssertEqual(action.label, "Bryt fasten tidlig")
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
    try app.performAccessibilityAudit(for: [.textClipped, .hitRegion, .sufficientElementDescription])
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
    try app.performAccessibilityAudit(for: [.textClipped, .sufficientElementDescription])
    XCTAssertFalse(app.scrollViews.firstMatch.exists)
    XCTAssertLessThanOrEqual(action.frame.maxY, app.tabBars.firstMatch.frame.minY)
    attach(app, name: "Started-fast-largest-text")
    let reflection = app.buttons["openReflection"]
    XCTAssertTrue(reflection.isHittable)
    XCTAssertLessThanOrEqual(reflection.frame.maxY, app.tabBars.firstMatch.frame.minY)
    reflection.tap()
    let feeling = app.buttons["feeling.comfortable"]
    XCTAssertTrue(feeling.waitForExistence(timeout: 3))
    for _ in 0..<5 where !feeling.isHittable { app.swipeUp() }
    XCTAssertTrue(feeling.isHittable)
    feeling.tap()
    XCTAssertTrue(reflection.waitForNonExistence(timeout: 3))
    XCTAssertFalse(app.scrollViews.firstMatch.exists)
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
    let dateBeforeSwipe = app.staticTexts["homeDate"].frame
    app.swipeUp()
    XCTAssertEqual(app.staticTexts["homeDate"].frame, dateBeforeSwipe)
    XCTAssertTrue(action.isHittable)
    try app.performAccessibilityAudit(for: [.contrast, .textClipped, .hitRegion])
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
    app.buttons["finishSetup"].tap()
    XCTAssertTrue(app.buttons["changeToday"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["settings"].exists)
    XCTAssertFalse(app.buttons["logWeight"].exists)
    attach(app, name: "Home-weight-disabled")
    app.tabBars.buttons["History"].tap()
    app.buttons["Add weight logging, if you like"].tap()
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
    app.buttons["Weight"].tap()
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
    attach(open, name: "Open-window")
    try open.performAccessibilityAudit(for: [.contrast, .textClipped, .hitRegion])
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
    let app = app("onboarding")
    XCTAssertTrue(app.buttons["beginSetup"].waitForExistence(timeout: 10))
    attach(app, name: "Welcome")
    app.terminate()
    let home = self.app("home")
    XCTAssertTrue(home.buttons["changeToday"].waitForExistence(timeout: 10))
    attach(home, name: "Home-release")
    home.tabBars.buttons["Schedule"].tap()
    XCTAssertTrue(home.buttons["weekOptions"].waitForExistence(timeout: 3))
    attach(home, name: "Schedule-release")
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
    app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Window length")).firstMatch.tap()
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
    let opening = app.otherElements["openingTime"]
    XCTAssertTrue(opening.waitForExistence(timeout: 3))
    XCTAssertEqual(opening.pickerWheels.element(boundBy: 0).value as? String, "1")
    XCTAssertEqual(opening.pickerWheels.element(boundBy: 2).value as? String, "PM")
    app.buttons["Cancel"].tap()
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
  }

  func testTodayWindowNorwegianAndLargestText() throws {
    for largeText in [false, true] {
      let app = app("home", language: "nb", largeText: largeText)
      app.tabBars.buttons["Plan"].tap()
      XCTAssertTrue(app.buttons["todayMenu"].waitForExistence(timeout: 5))
      attach(app, name: largeText ? "Today-Norwegian-largest-text" : "Today-Norwegian")
      try app.performAccessibilityAudit(for: [.textClipped])
      app.buttons["todayMenu"].tap()
      XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Vinduslengde")).firstMatch.exists)
      app.buttons["Angi nøyaktige tider"].tap()
      XCTAssertTrue(app.buttons["saveSchedule"].waitForExistence(timeout: 3))
      app.buttons["Avbryt"].tap()
      app.terminate()
    }
  }

  func testDragWindowAndSetLengthsForAllDays() throws {
    let app = app("home")
    app.tabBars.buttons["Schedule"].tap()
    XCTAssertTrue(app.buttons["weekOptions"].waitForExistence(timeout: 5))
    let today = app.descendants(matching: .any).matching(identifier: "todayWindow").firstMatch.label
    app.buttons["dayMenu.1"].tap()
    app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Window length")).firstMatch.tap()
    app.buttons["6 hr"].tap()
    XCTAssertTrue(app.staticTexts["dayTimes.1"].label.contains("4:00"))
    XCTAssertTrue(app.staticTexts["dayTimes.2"].label.contains("6:00"))
    let bar = app.descendants(matching: .any).matching(identifier: "windowSlider.1").firstMatch
    if bar.frame.maxY > app.tabBars.firstMatch.frame.minY { app.swipeUp() }
    let start = bar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    let end = bar.coordinate(withNormalizedOffset: CGVector(dx: 0.625, dy: 0.5))
    start.press(forDuration: 0.1, thenDragTo: end)
    XCTAssertTrue(app.staticTexts["dayTimes.1"].label.contains("1:00"), app.staticTexts["dayTimes.1"].label)
    XCTAssertTrue(app.staticTexts["dayTimes.1"].label.contains("7:00"))
    XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "todayWindow").firstMatch.label, today)
    attach(app, name: "Dragged-six-hour-window")
    app.buttons["dayMenu.1"].tap()
    app.buttons["Use this length for all days"].tap()
    XCTAssertTrue(app.staticTexts["dayTimes.2"].label.contains("4:00"))
    XCTAssertTrue(app.staticTexts["dayTimes.1"].label.contains("1:00"))
    for _ in 0..<4 where !app.buttons["weekOptions"].isHittable { app.swipeDown() }
    app.buttons["weekOptions"].tap()
    app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Window length for all days")).firstMatch.tap()
    attach(app, name: "All-days-window-length-menu")
    app.buttons["4 hr"].tap()
    XCTAssertTrue(app.staticTexts["dayTimes.1"].label.contains("5:00"))
    XCTAssertTrue(app.staticTexts["dayTimes.2"].label.contains("2:00"))
    attach(app, name: "Window-length-for-all-days")

    bar.coordinate(withNormalizedOffset: CGVector(dx: 0.625, dy: 0.5)).press(
      forDuration: 0.1,
      thenDragTo: bar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
    XCTAssertTrue(app.staticTexts["dayTimes.1"].label.contains("10:00"))
    XCTAssertTrue(app.staticTexts["dayTimes.1"].label.contains("2:00"))
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
