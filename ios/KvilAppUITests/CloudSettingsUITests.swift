import XCTest

@MainActor final class CloudSettingsUITests: XCTestCase {
  func testEncryptedCloudSettingsInEnglish() throws {
    try inspectSettings(language: "en", largeText: false)
  }

  func testEncryptedCloudSettingsInNorwegian() throws {
    try inspectSettings(language: "nb", largeText: false)
  }

  func testEncryptedCloudSettingsAtLargestText() throws {
    try inspectSettings(language: "nb", largeText: true)
  }

  private func inspectSettings(language: String, largeText: Bool) throws {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchEnvironment["KVIL_SCENARIO"] = "home"
    app.launchArguments = [
      "-AppleLanguages", "(\(language))", "-AppleLocale", language == "nb" ? "nb_NO" : "en_US",
    ]
    if largeText {
      app.launchArguments += [
        "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
      ]
    }
    app.launch()
    XCTAssertTrue(app.buttons["fastingAction"].waitForExistence(timeout: 10))
    let schedule = app.tabBars.buttons[language == "nb" ? "Plan" : "Schedule"]
    XCTAssertTrue(schedule.waitForExistence(timeout: 10))
    schedule.tap()
    XCTAssertTrue(app.buttons["settings"].waitForExistence(timeout: 5))
    app.buttons["settings"].tap()
    let toggle = app.switches["cloudScheduleSync"]
    for _ in 0..<12 where !toggle.isHittable { scroll(app) }
    XCTAssertTrue(toggle.isHittable)
    let help = app.staticTexts["cloudSyncHelp"]
    for _ in 0..<5 where !help.isHittable { scroll(app) }
    XCTAssertTrue(help.isHittable)
    XCTAssertTrue(
      help.label.contains(language == "nb" ? "krypterte iCloud-felt" : "encrypted iCloud fields"))
    let status = app.staticTexts["cloudSyncStatus"]
    XCTAssertTrue(status.exists)
    XCTAssertTrue(status.label.contains(language == "nb" ? "Venter" : "Waiting"))
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "Encrypted-cloud-settings-\(language)\(largeText ? "-largest" : "")-dark"
    screenshot.lifetime = .keepAlways
    add(screenshot)
    let hierarchy = XCTAttachment(string: app.debugDescription)
    hierarchy.name = "Cloud-settings-layout-\(language)\(largeText ? "-largest" : "")"
    hierarchy.lifetime = .keepAlways
    add(hierarchy)
    // Let XCTest finish the font sweep and report every issue before restoring test behavior.
    continueAfterFailure = true
    defer { continueAfterFailure = false }
    try app.performAccessibilityAudit(for: [.textClipped, .sufficientElementDescription])
    XCTAssertTrue(
      help.isHittable,
      "Settings must preserve access to the current section after text-size changes")
    let afterAudit = XCTAttachment(screenshot: app.screenshot())
    afterAudit.name = "Settings-after-text-size-audit-\(language)\(largeText ? "-largest" : "")"
    afterAudit.lifetime = .keepAlways
    add(afterAudit)
    app.terminate()
  }

  private func scroll(_ app: XCUIApplication) {
    app.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.78)).press(
      forDuration: 0.05,
      thenDragTo: app.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.34)))
  }
}
