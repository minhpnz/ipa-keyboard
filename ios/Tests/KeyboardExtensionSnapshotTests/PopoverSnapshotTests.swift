import XCTest
import SwiftUI
import SnapshotTesting
import IPACore

/// Visual regression for the variant popover at corner-most key positions.
/// Composes the real `KeyboardRootView` background with a `VariantPopover`
/// placed by the real `LayoutEngine.popoverRect` so the snapshot exercises
/// the same layout path used at runtime in `KeyboardRootView.popoverOverlay`.
///
/// Key frames are hardcoded approximations: changing keyboard layout will
/// shift the popover relative to the underlying keys, which is exactly what
/// these snapshots exist to flag.
final class PopoverSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // isRecording = true    // Uncomment temporarily to regenerate baselines.
    }

    private func compose(
        size: CGSize,
        keyFrame: CGRect,
        variants: [String],
        selectedIndex: Int? = nil
    ) -> some View {
        let popoverSize = CGSize(width: CGFloat(variants.count) * 44 + 16, height: 52)
        let rect = LayoutEngine.popoverRect(
            keyFrame: keyFrame,
            popoverSize: popoverSize,
            keyboardBounds: CGRect(origin: .zero, size: size)
        )
        return ZStack(alignment: .topLeading) {
            KeyboardRootView(
                onInsertText: { _ in },
                onDeleteBackward: {},
                onAdvanceInputMode: {}
            )
            VariantPopover(variants: variants, selectedIndex: selectedIndex)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .allowsHitTesting(false)
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: - Left-edge clamp: 'a' (3 variants → widest popover) on iPhone 13.
    // Row-2 leftmost letter; popover above the key, horizontally clamped right
    // so it stays inside `keyboardBounds`.
    func test_popover_leftEdge_a_iPhone13_light() {
        let view = compose(
            size: CGSize(width: 393, height: 260),
            keyFrame: CGRect(x: 22, y: 56, width: 34, height: 44),
            variants: ["æ", "ʌ", "ɑː"]
        )
        assertSnapshot(of: UIHostingController(rootView: view),
                       as: .image(on: .iPhone13, traits: .init(userInterfaceStyle: .light)))
    }

    // MARK: - Right-edge + top-row: 'o' on iPhone 13 (row 1 → mirrors below).
    // Row 1 keys can't fit the popover above (would clip top), so LayoutEngine
    // mirrors below; near the right edge it also clamps left.
    func test_popover_rightEdge_o_topRow_iPhone13_light() {
        let view = compose(
            size: CGSize(width: 393, height: 260),
            keyFrame: CGRect(x: 316, y: 6, width: 34, height: 44),
            variants: ["ɒ", "ɔː"]
        )
        assertSnapshot(of: UIHostingController(rootView: view),
                       as: .image(on: .iPhone13, traits: .init(userInterfaceStyle: .light)))
    }

    // MARK: - Bottom-left: 'z' on iPhone 13. Row-3 leftmost letter (1 variant).
    // Standard above-key placement; tests the narrow popover near a corner.
    func test_popover_bottomLeft_z_iPhone13_light() {
        let view = compose(
            size: CGSize(width: 393, height: 260),
            keyFrame: CGRect(x: 60, y: 106, width: 34, height: 44),
            variants: ["ʒ"]
        )
        assertSnapshot(of: UIHostingController(rootView: view),
                       as: .image(on: .iPhone13, traits: .init(userInterfaceStyle: .light)))
    }

    // MARK: - Narrow width + 3-variant clamp: 'a' on iPhone SE (320pt).
    // Tightest left-edge clamp scenario in the supported device matrix.
    func test_popover_a_iPhoneSE_narrow_light() {
        let view = compose(
            size: CGSize(width: 320, height: 216),
            keyFrame: CGRect(x: 22, y: 56, width: 28, height: 44),
            variants: ["æ", "ʌ", "ɑː"]
        )
        assertSnapshot(of: UIHostingController(rootView: view),
                       as: .image(on: .iPhoneSe, traits: .init(userInterfaceStyle: .light)))
    }

    // MARK: - Selection highlight: middle variant of 'a' selected.
    // Catches regressions in `VariantPopover` selectedIndex styling.
    func test_popover_a_withSelection_iPhone13_light() {
        let view = compose(
            size: CGSize(width: 393, height: 260),
            keyFrame: CGRect(x: 22, y: 56, width: 34, height: 44),
            variants: ["æ", "ʌ", "ɑː"],
            selectedIndex: 1
        )
        assertSnapshot(of: UIHostingController(rootView: view),
                       as: .image(on: .iPhone13, traits: .init(userInterfaceStyle: .light)))
    }
}
