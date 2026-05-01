// IPAMapping.swift
// GENERATED — do not edit by hand.
// Run ios/Scripts/generate-ipa-mapping.sh to regenerate.
//
// Source SHA256: f41aac1d19532ecae20797e03d4cbd351f3e6fb33c851daa311e532c1aec8465

// swiftlint:disable all

import Foundation

public enum IPAMapping {

    /// SHA256 of shared-config/default-mappings.json at codegen time.
    public static let sourceHash: String = "f41aac1d19532ecae20797e03d4cbd351f3e6fb33c851daa311e532c1aec8465"

    /// Maps each dotted key to its ordered IPA variants.
    public static let variants: [Character: [String]] = [
        "a": ["æ", "ʌ", "ɑː", "ɑ"],
        "e": ["ə", "ɜː"],
        "i": ["ɪ", "iː", "i"],
        "o": ["ɒ", "ɔː"],
        "u": ["ʊ", "uː"],
        "t": ["θ", "ð"],
        "s": ["ʃ"],
        "d": ["dʒ"],
        "c": ["tʃ"],
        "n": ["ŋ"],
        "z": ["ʒ"],
    ]

    /// Dotted-key characters in JSON insertion order.
    public static let dottedKeys: [Character] = [
        "a",
        "e",
        "i",
        "o",
        "u",
        "t",
        "s",
        "d",
        "c",
        "n",
        "z",
    ]

    /// All unique IPA variant strings across every key.
    public static let allVariants: Set<String> = [
        "dʒ",
        "i",
        "iː",
        "tʃ",
        "uː",
        "æ",
        "ð",
        "ŋ",
        "ɑ",
        "ɑː",
        "ɒ",
        "ɔː",
        "ə",
        "ɜː",
        "ɪ",
        "ʃ",
        "ʊ",
        "ʌ",
        "ʒ",
        "θ",
    ]
}
