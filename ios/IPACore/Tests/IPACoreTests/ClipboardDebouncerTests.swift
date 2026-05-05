import XCTest
@testable import IPACore

final class ClipboardDebouncerTests: XCTestCase {

    func test_firstTapAccepted() {
        var d = ClipboardDebouncer()
        XCTAssertTrue(d.accept(value: "æ", at: 0.0))
    }

    func test_sameValueWithinWindowRejected() {
        var d = ClipboardDebouncer()
        XCTAssertTrue(d.accept(value: "æ", at: 0.0))
        XCTAssertFalse(d.accept(value: "æ", at: 0.1))
        XCTAssertFalse(d.accept(value: "æ", at: 0.29))
    }

    func test_sameValueAfterWindowAccepted() {
        var d = ClipboardDebouncer()
        XCTAssertTrue(d.accept(value: "æ", at: 0.0))
        XCTAssertTrue(d.accept(value: "æ", at: LayoutEngine.clipboardDebounceInterval + 0.01))
    }

    func test_differentValueImmediatelyAccepted() {
        var d = ClipboardDebouncer()
        XCTAssertTrue(d.accept(value: "æ", at: 0.0))
        XCTAssertTrue(d.accept(value: "ʌ", at: 0.1))
        // And it now treats ʌ as the new reference for its own window.
        XCTAssertFalse(d.accept(value: "ʌ", at: 0.2))
    }

    func test_usesLayoutEngineWindow() {
        var d = ClipboardDebouncer()
        _ = d.accept(value: "æ", at: 0)
        // Exactly at the window boundary: rejected (strict <).
        XCTAssertFalse(d.accept(value: "æ", at: LayoutEngine.clipboardDebounceInterval - 0.01))
    }
}
