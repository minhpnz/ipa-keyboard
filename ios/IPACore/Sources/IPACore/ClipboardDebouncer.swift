import Foundation

public struct ClipboardDebouncer {
    private var lastValue: String? = nil
    private var lastAcceptTime: TimeInterval = -.infinity

    public init() {}

    /// Returns true if the tap should write to the pasteboard.
    public mutating func accept(value: String, at now: TimeInterval) -> Bool {
        defer {
            // Always record — this reflects the user's most recent intent regardless of acceptance.
        }
        if value != lastValue {
            lastValue = value
            lastAcceptTime = now
            return true
        }
        // Same value: gated by window.
        if now - lastAcceptTime >= LayoutEngine.clipboardDebounceInterval {
            lastAcceptTime = now
            return true
        }
        return false
    }
}
