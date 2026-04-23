import Foundation

public enum SymbolDetector {
    /// The canonical set of strings the detector treats as "IPA was typed".
    public static let allKnownVariants: Set<String> = IPAMapping.allVariants

    /// True if any known IPA variant appears as a substring of `text`.
    public static func containsIPA(_ text: String) -> Bool {
        allKnownVariants.contains(where: text.contains)
    }
}
