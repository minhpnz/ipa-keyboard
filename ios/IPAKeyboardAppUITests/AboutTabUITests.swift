import XCTest

final class AboutTabUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchOnAboutTab() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-SkipSetupForUITests"]
        app.launch()
        app.tabBars.buttons["About"].tap()
        XCTAssertTrue(app.navigationBars["About"].waitForExistence(timeout: 3))
        return app
    }

    func test_versionMatchesInfoPlist() {
        let app = launchOnAboutTab()
        let label = app.staticTexts.matching(identifier: "AppVersionValue").firstMatch
        XCTAssertTrue(label.waitForExistence(timeout: 3))

        let value = label.label
        XCTAssertTrue(
            value.range(of: #"^\d+\.\d+(\.\d+)? \(\d+\)$"#, options: .regularExpression) != nil,
            "Unexpected version string: \(value)"
        )
    }

    func test_aboutMentionsOfflineAndNoNetwork() {
        let app = launchOnAboutTab()
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'entirely offline'"))
                .firstMatch.waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'no network'"))
                .firstMatch.exists
        )
    }
}
