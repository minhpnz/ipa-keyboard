import XCTest
@testable import IPACore

final class IPAMappingTests: XCTestCase {

    func test_elevenDottedKeys() {
        XCTAssertEqual(IPAMapping.dottedKeys.count, 11)
        XCTAssertEqual(Set(IPAMapping.dottedKeys), Set("aeioutsdcnz"))
    }

    func test_eighteenTotalVariants() {
        XCTAssertEqual(IPAMapping.allVariants.count, 18)
    }

    func test_aMapsToThreeVariantsInOrder() {
        XCTAssertEqual(IPAMapping.variants["a"], ["æ", "ʌ", "ɑː"])
    }

    func test_everyDottedKeyHasVariants() {
        for key in IPAMapping.dottedKeys {
            let variants = IPAMapping.variants[key]
            XCTAssertNotNil(variants, "No variants entry for key '\(key)'")
            XCTAssertFalse(variants!.isEmpty, "Empty variants array for key '\(key)'")
        }
    }

    func test_sourceHashIsSixtyFourHexChars() {
        let hash = IPAMapping.sourceHash
        XCTAssertEqual(hash.count, 64)
        XCTAssertTrue(hash.allSatisfy { $0.isHexDigit }, "sourceHash contains non-hex characters")
    }
}
