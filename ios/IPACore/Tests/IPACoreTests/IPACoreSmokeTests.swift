import XCTest
@testable import IPACore

final class IPACoreSmokeTests: XCTestCase {
    func test_packageLoads() {
        XCTAssertEqual(IPACore.version, "0.1.0")
    }
}
