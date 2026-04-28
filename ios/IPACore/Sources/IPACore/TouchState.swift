import Foundation

public struct TouchState: Equatable {

    public struct Active: Equatable {
        public let key: Character
        let token: UUID    // opaque handle; only IPACore internals compare it
    }

    public private(set) var current: Active? = nil

    public init() {}

    /// Begin a new touch. Returns the token — pass it to the popover timer callback.
    @discardableResult
    public mutating func begin(key: Character) -> UUID {
        let token = UUID()
        current = Active(key: key, token: token)
        return token
    }

    /// Late timer callback: is this token still the active one?
    public func shouldShowPopover(for token: UUID) -> Bool {
        current?.token == token
    }

    /// Touch ended normally. Returns the captured key (or nil if no touch was active).
    /// Callers that showed a popover should discard the returned key; it is the raw
    /// base key, not the selected variant.
    @discardableResult
    public mutating func end() -> Character? {
        let key = current?.key
        current = nil
        return key
    }

    /// Touch cancelled (system interruption, drag off, etc.)
    public mutating func cancel() {
        current = nil
    }
}
