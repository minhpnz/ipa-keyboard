import XCTest
@testable import IPACore

final class CoachMarkPolicyTests: XCTestCase {

    func test_showOnFirstThreeActivations() {
        XCTAssertTrue(CoachMarkPolicy.shouldShow(forActivationCount: 1))
        XCTAssertTrue(CoachMarkPolicy.shouldShow(forActivationCount: 2))
        XCTAssertTrue(CoachMarkPolicy.shouldShow(forActivationCount: 3))
    }

    func test_hiddenForLaterActivations() {
        XCTAssertFalse(CoachMarkPolicy.shouldShow(forActivationCount: 4))
        XCTAssertFalse(CoachMarkPolicy.shouldShow(forActivationCount: 500))
    }

    func test_hiddenForZeroOrNegative() {
        XCTAssertFalse(CoachMarkPolicy.shouldShow(forActivationCount: 0))
        XCTAssertFalse(CoachMarkPolicy.shouldShow(forActivationCount: -1))
    }

    func test_autoDismissAfterFourSeconds() {
        XCTAssertEqual(CoachMarkPolicy.autoDismissDelay, 4.0, accuracy: 0.01)
    }
}
