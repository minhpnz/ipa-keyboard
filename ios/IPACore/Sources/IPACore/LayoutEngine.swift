import CoreGraphics
import Foundation

public enum LayoutEngine {

    public static let popoverDelay: TimeInterval = 0.5
    public static let clipboardDebounceInterval: TimeInterval = 0.3
    public static let popoverPadding: CGFloat = 4

    /// Per-variant horizontal slot inside the popover, used both for layout
    /// and as the hit-test bucket width while dragging across variants.
    public static let popoverBucketWidth: CGFloat = 44
    /// Total popover height (matches `VariantPopover` content + chrome).
    public static let popoverHeight: CGFloat = 52
    /// Horizontal chrome (popover container padding ×2) added to the
    /// summed bucket widths when sizing the popover.
    public static let popoverHorizontalChrome: CGFloat = 16

    /// Convenience: the popover's outer rect size for `variantCount` items.
    public static func popoverSize(variantCount: Int) -> CGSize {
        CGSize(
            width: CGFloat(variantCount) * popoverBucketWidth + popoverHorizontalChrome,
            height: popoverHeight
        )
    }

    /// Compute the popover frame so it is fully inside `keyboardBounds`.
    /// Preference order: above-and-centered → below-and-centered → clamp horizontally.
    public static func popoverRect(
        keyFrame: CGRect,
        popoverSize: CGSize,
        keyboardBounds: CGRect
    ) -> CGRect {
        let padding = popoverPadding

        // Vertical: try above; mirror below if above would clip.
        // Then clamp so the popover always lies within keyboardBounds —
        // covers the case where neither above nor below fully fits.
        let aboveY = keyFrame.minY - popoverSize.height - padding
        let belowY = keyFrame.maxY + padding
        var y: CGFloat = aboveY >= keyboardBounds.minY ? aboveY : belowY
        if y < keyboardBounds.minY { y = keyboardBounds.minY }
        if y + popoverSize.height > keyboardBounds.maxY {
            y = keyboardBounds.maxY - popoverSize.height
        }

        // Horizontal: center over key, then clamp to keyboardBounds.
        var x = keyFrame.midX - popoverSize.width / 2
        if x < keyboardBounds.minX { x = keyboardBounds.minX }
        if x + popoverSize.width > keyboardBounds.maxX {
            x = keyboardBounds.maxX - popoverSize.width
        }

        return CGRect(origin: CGPoint(x: x, y: y), size: popoverSize)
    }
}
