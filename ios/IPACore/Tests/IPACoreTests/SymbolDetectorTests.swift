import XCTest
@testable import IPACore

final class SymbolDetectorTests: XCTestCase {

    func test_plainAsciiIsNotDetected() {
        XCTAssertFalse(SymbolDetector.containsIPA("hello world"))
        XCTAssertFalse(SymbolDetector.containsIPA(""))
        XCTAssertFalse(SymbolDetector.containsIPA("AEIOU aeiou 123"))
    }

    func test_everyMappingVariantIsDetected() {
        for variant in IPAMapping.allVariants {
            XCTAssertTrue(
                SymbolDetector.containsIPA("prefix \(variant) suffix"),
                "Should detect \(variant)"
            )
        }
    }

    func test_pastedSentenceIsDetected() {
        XCTAssertTrue(SymbolDetector.containsIPA("the cat is /kæt/"))
        XCTAssertTrue(SymbolDetector.containsIPA("/ðɪs/"))
    }

    func test_allKnownVariantsMatchesIPAMapping() {
        XCTAssertEqual(SymbolDetector.allKnownVariants, IPAMapping.allVariants)
    }
}
