import Foundation

public extension IPAMapping {
    /// The dotted-key characters as a Set, for O(1) membership tests in hot paths
    /// (e.g., per-render "does this key have variants?" check in the keyboard view).
    static let dottedKeySet: Set<Character> = Set(dottedKeys)
}
