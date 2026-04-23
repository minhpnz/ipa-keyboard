import XCTest
@testable import IPACore
import CoreGraphics

final class LayoutEngineTests: XCTestCase {

    // Timing constants — asserted so any accidental change surfaces in review.
    func test_popoverDelayIsFiveHundredMillis() {
        XCTAssertEqual(LayoutEngine.popoverDelay, 0.5, accuracy: 0.001)
    }

    func test_clipboardDebounceIsThreeHundredMillis() {
        XCTAssertEqual(LayoutEngine.clipboardDebounceInterval, 0.3, accuracy: 0.001)
    }

    // Popover positioning: center over key when fully inside the keyboard width.
    func test_popoverCenteredOverKeyWhenMiddleOfKeyboard() {
        let keyFrame = CGRect(x: 160, y: 60, width: 32, height: 48)
        let popoverSize = CGSize(width: 120, height: 52)
        let keyboardSize = CGSize(width: 390, height: 260)

        let rect = LayoutEngine.popoverRect(
            keyFrame: keyFrame,
            popoverSize: popoverSize,
            keyboardBounds: CGRect(origin: .zero, size: keyboardSize)
        )

        XCTAssertEqual(rect.midX, keyFrame.midX, accuracy: 0.5)
        XCTAssertLessThan(rect.maxY, keyFrame.minY, "popover above key")
    }

    // Left-edge key → popover must be shifted right so it stays inside.
    func test_popoverClampedRightAtLeftEdge() {
        let keyFrame = CGRect(x: 2, y: 60, width: 32, height: 48)
        let popoverSize = CGSize(width: 160, height: 52)
        let keyboardSize = CGSize(width: 390, height: 260)

        let rect = LayoutEngine.popoverRect(
            keyFrame: keyFrame,
            popoverSize: popoverSize,
            keyboardBounds: CGRect(origin: .zero, size: keyboardSize)
        )

        XCTAssertGreaterThanOrEqual(rect.minX, 0)
        XCTAssertLessThanOrEqual(rect.maxX, keyboardSize.width)
    }

    // Right-edge key (p) → popover clamped left.
    func test_popoverClampedLeftAtRightEdge() {
        let keyFrame = CGRect(x: 356, y: 60, width: 32, height: 48)
        let popoverSize = CGSize(width: 160, height: 52)
        let keyboardSize = CGSize(width: 390, height: 260)

        let rect = LayoutEngine.popoverRect(
            keyFrame: keyFrame,
            popoverSize: popoverSize,
            keyboardBounds: CGRect(origin: .zero, size: keyboardSize)
        )

        XCTAssertLessThanOrEqual(rect.maxX, keyboardSize.width)
    }

    // iPad floating width (~320pt) — still clamped, no off-screen bleed.
    func test_popoverNeverOffScreenAtNarrowWidth() {
        let keyboardSize = CGSize(width: 320, height: 200)
        let popoverSize = CGSize(width: 160, height: 52)
        for x in stride(from: 0, through: 320 - 32, by: 8) {
            let keyFrame = CGRect(x: CGFloat(x), y: 40, width: 32, height: 40)
            let rect = LayoutEngine.popoverRect(
                keyFrame: keyFrame,
                popoverSize: popoverSize,
                keyboardBounds: CGRect(origin: .zero, size: keyboardSize)
            )
            XCTAssertGreaterThanOrEqual(rect.minX, 0, "off-screen left for x=\(x)")
            XCTAssertLessThanOrEqual(rect.maxX, keyboardSize.width, "off-screen right for x=\(x)")
        }
    }

    // Top row — popover would clip top if placed above; must mirror below.
    func test_popoverMirrorsBelowWhenTopRowWouldClip() {
        let keyFrame = CGRect(x: 160, y: 2, width: 32, height: 48)
        let popoverSize = CGSize(width: 120, height: 52)
        let keyboardSize = CGSize(width: 390, height: 260)

        let rect = LayoutEngine.popoverRect(
            keyFrame: keyFrame,
            popoverSize: popoverSize,
            keyboardBounds: CGRect(origin: .zero, size: keyboardSize)
        )

        XCTAssertGreaterThanOrEqual(rect.minY, keyFrame.maxY,
            "Popover should mirror below when placing above would clip")
    }
}
