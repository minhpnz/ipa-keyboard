import XCTest
@testable import IPACore

final class TouchStateTests: XCTestCase {

    func test_newTouchAssignsTokenAndKey() {
        var s = TouchState()
        let t = s.begin(key: "a")
        XCTAssertEqual(s.current?.key, "a")
        XCTAssertEqual(s.current?.token, t)
    }

    func test_timerCallbackWithMatchingTokenIsAcceptedForPopover() {
        var s = TouchState()
        let t = s.begin(key: "a")
        XCTAssertTrue(s.shouldShowPopover(for: t))
    }

    func test_timerCallbackWithStaleTokenIsRejected() {
        var s = TouchState()
        let t1 = s.begin(key: "a")
        _ = s.begin(key: "e")    // stomps t1
        XCTAssertFalse(s.shouldShowPopover(for: t1))
        XCTAssertEqual(s.current?.key, "e")
    }

    func test_cancelClearsState() {
        var s = TouchState()
        let t = s.begin(key: "a")
        s.cancel()
        XCTAssertNil(s.current)
        XCTAssertFalse(s.shouldShowPopover(for: t))
    }

    func test_endReleasesTokenButKeepsKeyForInsert() {
        var s = TouchState()
        _ = s.begin(key: "a")
        let ended = s.end()
        XCTAssertEqual(ended, "a")
        XCTAssertNil(s.current)
    }

    func test_endOnEmptyStateReturnsNil() {
        var s = TouchState()
        XCTAssertNil(s.end())
    }
}
