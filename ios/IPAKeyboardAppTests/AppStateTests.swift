import XCTest
@testable import IPAKeyboardApp

final class AppStateTests: XCTestCase {
    private let testSuite = "ipa.tests.\(UUID().uuidString)"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: testSuite)!
        defaults.removePersistentDomain(forName: testSuite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: testSuite)
        super.tearDown()
    }

    func test_defaultsOnFirstLaunch() {
        let s = AppState(defaults: defaults)
        XCTAssertFalse(s.hasConfirmedSetup)
        XCTAssertEqual(s.defaultTab, .setup)
        XCTAssertFalse(s.sawIpaCharacterInTestField)
    }

    func test_confirmingSetupFlipsDefaultTab() {
        let s = AppState(defaults: defaults)
        s.confirmSetup()
        XCTAssertTrue(s.hasConfirmedSetup)
        XCTAssertEqual(s.defaultTab, .reference)
    }

    func test_confirmationPersistsAcrossInstances() {
        let first = AppState(defaults: defaults)
        first.confirmSetup()
        let second = AppState(defaults: defaults)
        XCTAssertTrue(second.hasConfirmedSetup)
        XCTAssertEqual(second.defaultTab, .reference)
    }

    func test_sawIpaOnceThenStaysTrue() {
        let s = AppState(defaults: defaults)
        s.noteTextFieldChanged("æ is nice")
        XCTAssertTrue(s.sawIpaCharacterInTestField)
        s.noteTextFieldChanged("hello")    // irrelevant content
        XCTAssertTrue(s.sawIpaCharacterInTestField, "should not un-flip")
    }

    func test_sawIpaStaysFalseForPlainText() {
        let s = AppState(defaults: defaults)
        s.noteTextFieldChanged("hello world")
        XCTAssertFalse(s.sawIpaCharacterInTestField)
    }
}
