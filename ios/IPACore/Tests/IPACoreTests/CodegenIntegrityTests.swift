import XCTest
@testable import IPACore

final class CodegenIntegrityTests: XCTestCase {

    func test_referenceRowsAreInDottedKeyOrder() {
        // For each row, find the dottedKey whose variants array contains row.symbol,
        // and the index of row.symbol within that array. The resulting (keyIdx, variantIdx)
        // pairs must be strictly increasing across rows.
        var lastKey = -1
        var lastVariantInKey = -1
        for row in SymbolReferenceData.rows {
            var foundKey = -1
            var foundVariant = -1
            for (i, k) in IPAMapping.dottedKeys.enumerated() {
                if let variants = IPAMapping.variants[k],
                   let j = variants.firstIndex(of: row.symbol) {
                    foundKey = i
                    foundVariant = j
                    break
                }
            }
            XCTAssertGreaterThanOrEqual(foundKey, 0, "row symbol \(row.symbol) not in any mapping")
            if foundKey == lastKey {
                XCTAssertGreaterThan(foundVariant, lastVariantInKey, "variant order regressed within key")
            } else {
                XCTAssertGreaterThan(foundKey, lastKey, "dottedKey order regressed at \(row.symbol)")
                lastVariantInKey = -1
            }
            lastKey = foundKey
            lastVariantInKey = foundVariant
        }
    }

    func test_everyReferenceEntryIsInAllVariants() {
        for row in SymbolReferenceData.rows {
            XCTAssertTrue(IPAMapping.allVariants.contains(row.symbol),
                          "row symbol \(row.symbol) not in IPAMapping.allVariants")
        }
    }

    func test_everyMappingVariantHasNonTrivialEnglishName() {
        for variant in IPAMapping.allVariants {
            let name = LocalizedSymbolNames.english[variant]
            XCTAssertNotNil(name, "no English name for \(variant)")
            XCTAssertFalse((name ?? "").isEmpty, "empty English name for \(variant)")
            // "non-trivial" = at least a few characters
            XCTAssertGreaterThan((name ?? "").count, 3, "suspiciously short name for \(variant): \(name ?? "nil")")
        }
    }

    func test_referenceRowCountMatchesAllVariantsCount() {
        XCTAssertEqual(SymbolReferenceData.rows.count, IPAMapping.allVariants.count)
    }
}
