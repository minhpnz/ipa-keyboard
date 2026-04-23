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

    // Common Latin-extended characters users might paste (accents, diacritics
    // on plain letters) must NOT trigger IPA detection.
    func test_latinExtendedLookalikesAreNotDetected() {
        XCTAssertFalse(SymbolDetector.containsIPA("naïve"))
        XCTAssertFalse(SymbolDetector.containsIPA("café résumé"))
        XCTAssertFalse(SymbolDetector.containsIPA("El Niño"))
        XCTAssertFalse(SymbolDetector.containsIPA("façade"))
    }
}
