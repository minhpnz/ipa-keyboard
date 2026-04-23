import XCTest
@testable import IPACore

final class IPAMappingSetsTests: XCTestCase {

    func test_dottedKeySetMatchesDottedKeysArray() {
        XCTAssertEqual(IPAMapping.dottedKeySet, Set(IPAMapping.dottedKeys))
    }

    func test_dottedKeySetHasElevenEntries() {
        XCTAssertEqual(IPAMapping.dottedKeySet.count, 11)
    }

    func test_dottedKeySetContainsExpectedCharacters() {
        for char in ["a", "e", "i", "o", "u", "t", "s", "d", "c", "n", "z"] as [Character] {
            XCTAssertTrue(IPAMapping.dottedKeySet.contains(char),
                          "dottedKeySet missing expected char \(char)")
        }
    }
}
