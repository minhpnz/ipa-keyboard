// SymbolReferenceData.swift
// GENERATED — do not edit by hand.
// Run ios/Scripts/generate-ipa-mapping.sh to regenerate.
//
// Source SHA256: bab2c1696cf494bb0ea8114003f103308c362a5c60c418b62eaf4c88c4fa7976

// swiftlint:disable all

import Foundation

public struct SymbolRow: Equatable, Hashable, Sendable {
    public let symbol: String
    public let example: String
    // Explicit public init — Swift's memberwise init is internal by default.
    public init(symbol: String, example: String) {
        self.symbol = symbol
        self.example = example
    }
}

public enum SymbolReferenceData {

    /// SHA256 of companion-app/src/data/ipa-symbols.json at codegen time.
    public static let sourceHash: String = "bab2c1696cf494bb0ea8114003f103308c362a5c60c418b62eaf4c88c4fa7976"

    /// Rows in dottedKeys order, then variant order from default-mappings.json.
    public static let rows: [SymbolRow] = [
        SymbolRow(symbol: "æ", example: "Cat"),
        SymbolRow(symbol: "ʌ", example: "Up"),
        SymbolRow(symbol: "ɑː", example: "Far"),
        SymbolRow(symbol: "ɑ", example: "Father"),
        SymbolRow(symbol: "ə", example: "Teacher"),
        SymbolRow(symbol: "ɜː", example: "Bird"),
        SymbolRow(symbol: "ɪ", example: "Ship"),
        SymbolRow(symbol: "iː", example: "Sheep"),
        SymbolRow(symbol: "i", example: "Happy"),
        SymbolRow(symbol: "ɒ", example: "On"),
        SymbolRow(symbol: "ɔː", example: "Door"),
        SymbolRow(symbol: "ʊ", example: "Good"),
        SymbolRow(symbol: "uː", example: "Shoot"),
        SymbolRow(symbol: "θ", example: "Think"),
        SymbolRow(symbol: "ð", example: "This"),
        SymbolRow(symbol: "ʃ", example: "Shall"),
        SymbolRow(symbol: "dʒ", example: "June"),
        SymbolRow(symbol: "tʃ", example: "Cheese"),
        SymbolRow(symbol: "ŋ", example: "Sing"),
        SymbolRow(symbol: "ʒ", example: "Television"),
    ]
}
