import XCTest

final class ReferenceTabUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchOnReferenceTab() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-SkipSetupForUITests"]
        app.launch()
        let tab = app.tabBars.buttons["Reference"]
        if tab.exists { tab.tap() }
        XCTAssertTrue(app.navigationBars["Reference"].waitForExistence(timeout: 3))
        return app
    }

    func test_tapVariantCopiesAndShowsToast() {
        let app = launchOnReferenceTab()
        let aeCell = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'æ, '")
        ).firstMatch
        XCTAssertTrue(aeCell.waitForExistence(timeout: 3))
        aeCell.tap()

        let toast = app.staticTexts["Copied æ"]
        XCTAssertTrue(toast.waitForExistence(timeout: 0.5))

        let notExist = NSPredicate(format: "exists == false")
        expectation(for: notExist, evaluatedWith: toast)
        waitForExpectations(timeout: 2.5)
    }

    func test_rapidSameValueTapsWriteOnce() {
        let app = launchOnReferenceTab()
        let aeCell = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'æ, '")).firstMatch
        XCTAssertTrue(aeCell.waitForExistence(timeout: 3))

        for _ in 0..<5 { aeCell.tap() }
        let toasts = app.staticTexts.matching(NSPredicate(format: "label == 'Copied æ'"))
        XCTAssertEqual(toasts.count, 1)
    }

    func test_differentValueResetsDebounceImmediately() {
        let app = launchOnReferenceTab()
        let ae = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'æ, '")).firstMatch
        let wedge = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'ʌ, '")).firstMatch
        XCTAssertTrue(ae.waitForExistence(timeout: 3))
        XCTAssertTrue(wedge.exists)

        ae.tap()
        wedge.tap()

        let wedgeToast = app.staticTexts["Copied ʌ"]
        XCTAssertTrue(wedgeToast.waitForExistence(timeout: 0.5))
    }
}
