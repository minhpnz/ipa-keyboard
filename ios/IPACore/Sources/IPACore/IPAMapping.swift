// IPAMapping.swift
// GENERATED — do not edit by hand.
// Run ios/Scripts/generate-ipa-mapping.sh to regenerate.
//
// Source SHA256: 29e9c46a0b50b5e43291eb170fb073414206cf36f9ab6fcb348eb2290e64966b

// swiftlint:disable all

public enum IPAMapping {

    /// SHA256 of shared-config/default-mappings.json at codegen time.
    public static let sourceHash: String = "29e9c46a0b50b5e43291eb170fb073414206cf36f9ab6fcb348eb2290e64966b"

    /// Maps each dotted key to its ordered IPA variants.
    public static let variants: [Character: [String]] = [
        "a": ["æ", "ʌ", "ɑː"],
        "e": ["ə", "ɜː"],
        "i": ["ɪ", "iː"],
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
        "iː",
        "tʃ",
        "uː",
        "æ",
        "ð",
        "ŋ",
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
