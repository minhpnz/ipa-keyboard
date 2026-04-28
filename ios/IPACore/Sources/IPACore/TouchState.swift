import Foundation

public struct TouchState: Equatable {

    public struct Active: Equatable {
        public let key: Character
        public let token: UUID
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

    /// Touch ended normally. Returns the key so the caller can insert it (if no popover was open).
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
