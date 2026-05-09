import XCTest
@testable import IPACore

final class IPAMappingTests: XCTestCase {

    func test_elevenDottedKeys() {
        XCTAssertEqual(IPAMapping.dottedKeys.count, 11)
        XCTAssertEqual(Set(IPAMapping.dottedKeys), Set("aeioutsdcnz"))
    }

    func test_twentyTotalVariants() {
        XCTAssertEqual(IPAMapping.allVariants.count, 20)
    }

    func test_aMapsToFourVariantsInOrder() {
        XCTAssertEqual(IPAMapping.variants["a"], ["æ", "ʌ", "ɑː", "ɑ"])
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
