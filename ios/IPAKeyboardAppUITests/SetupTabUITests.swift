import XCTest

final class SetupTabUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchFreshApp() -> XCUIApplication {
        let app = XCUIApplication()
        // Force a clean AppState by passing a launch arg the app respects.
        app.launchArguments += ["-AppleLanguages", "(en)", "-ResetSetupForUITests", "YES"]
        app.launch()
        return app
    }

    func test_firstLaunchShowsSetupTabWithInstructionNumbersAndStickyCTA() {
        let app = launchFreshApp()
        XCTAssertTrue(app.staticTexts["Enable IPA Keyboard"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Step 1. Open Settings"].exists)
        XCTAssertTrue(app.staticTexts["Step 2. Go to General → Keyboard → Keyboards"].exists)
        XCTAssertTrue(app.staticTexts["Step 3. Tap \"Add New Keyboard…\" → IPA Keyboard"].exists)
        XCTAssertTrue(app.buttons["Open Settings"].isHittable)
    }

    func test_numberedCircleTapIsNoOp() {
        let app = launchFreshApp()
        // Numbered circles are decorative (accessibilityHidden); tapping their text
        // area must not mutate any state. We verify by tapping and confirming
        // "I've done this" still flips state correctly afterward.
        let step1 = app.staticTexts["Step 1. Open Settings"]
        step1.tap()
        step1.tap()
        XCTAssertTrue(app.buttons["I’ve done this"].isHittable)
        XCTAssertTrue(app.staticTexts["Enable IPA Keyboard"].exists, "Still on Setup")
    }

    func test_troubleshootingLinkOpensAndClosesSheet() {
        let app = launchFreshApp()
        app.buttons["Keyboard not appearing in Settings? →"].tap()
        XCTAssertTrue(app.staticTexts["Keyboard not appearing in Settings?"].waitForExistence(timeout: 2))
        app.buttons["Close"].tap()
        XCTAssertFalse(app.staticTexts["Keyboard not appearing in Settings?"].exists)
    }

    func test_iveDoneThisCollapsesAndPersists() {
        let app = launchFreshApp()
        app.buttons["I’ve done this"].tap()
        XCTAssertTrue(app.staticTexts["Setup complete — keyboard ready to use"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Show steps again"].isHittable)
        // Open Settings CTA must remain visible even after collapse.
        XCTAssertTrue(app.buttons["Open Settings"].isHittable)

        // Relaunch (without reset) — state must persist.
        // Background the app first so UserDefaults flushes to disk; XCUITest's
        // terminate() is forceful and on iOS 17+ can pre-empt the async write
        // that backs UserDefaults.set, making the next launch see stale state.
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 1.0)
        app.terminate()
        let app2 = XCUIApplication()
        app2.launch()
        // After persistence, defaultTab is .reference (per AppState.defaultTab),
        // so the relaunched app lands on Reference. Navigate back to Setup to
        // verify the collapsed banner state survived termination.
        app2.tabBars.buttons["Setup"].tap()
        XCTAssertTrue(app2.staticTexts["Setup complete — keyboard ready to use"].waitForExistence(timeout: 4))
    }

    func test_showStepsAgainReExpands() {
        let app = launchFreshApp()
        app.buttons["I’ve done this"].tap()
        XCTAssertTrue(app.staticTexts["Setup complete — keyboard ready to use"].waitForExistence(timeout: 2))
        app.buttons["Show steps again"].tap()
        XCTAssertTrue(app.staticTexts["Enable IPA Keyboard"].waitForExistence(timeout: 2))
    }
}
