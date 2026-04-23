import CoreGraphics
import Foundation

public enum LayoutEngine {

    public static let popoverDelay: TimeInterval = 0.5
    public static let clipboardDebounceInterval: TimeInterval = 0.3

    /// Compute the popover frame so it is fully inside `keyboardBounds`.
    /// Preference order: above-and-centered → below-and-centered → clamp horizontally.
    public static func popoverRect(
        keyFrame: CGRect,
        popoverSize: CGSize,
        keyboardBounds: CGRect
    ) -> CGRect {
        let padding: CGFloat = 4

        // Vertical: try above; mirror below if it would clip.
        let aboveY = keyFrame.minY - popoverSize.height - padding
        let belowY = keyFrame.maxY + padding
        let y: CGFloat = aboveY >= keyboardBounds.minY ? aboveY : belowY

        // Horizontal: center over key, then clamp to keyboardBounds.
        var x = keyFrame.midX - popoverSize.width / 2
        if x < keyboardBounds.minX { x = keyboardBounds.minX }
        if x + popoverSize.width > keyboardBounds.maxX {
            x = keyboardBounds.maxX - popoverSize.width
        }

        return CGRect(origin: CGPoint(x: x, y: y), size: popoverSize)
    }
}
