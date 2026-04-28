import SwiftUI
import IPACore

struct KeyboardRootView: View {

    let onInsertText: (String) -> Void
    let onDeleteBackward: () -> Void
    let onAdvanceInputMode: () -> Void

    @State private var isShifted: Bool = false
    @State private var touch = TouchState()
    @State private var popoverKey: Character? = nil
    @State private var popoverVariants: [String] = []
    @State private var popoverKeyFrame: CGRect = .zero
    @State private var popoverSelection: Int? = nil

    private let row1: [Character] = Array("qwertyuiop")
    private let row2: [Character] = Array("asdfghjkl")
    private let row3: [Character] = Array("zxcvbnm")
    private static let dotted: Set<Character> = Set(IPAMapping.dottedKeys)

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                keyboardBody(in: geo.size)
                if let key = popoverKey {
                    popoverOverlay(key: key, in: CGRect(origin: .zero, size: geo.size))
                }
            }
        }
        .frame(height: totalHeight)
        .background(Color(uiColor: .systemGray6))
    }

    private func keyboardBody(in size: CGSize) -> some View {
        VStack(spacing: 6) {
            row(row1, rowIndex: 0)
            HStack {
                Spacer(minLength: 18)
                row(row2, rowIndex: 1)
                Spacer(minLength: 18)
            }
            row3Bar
            functionRow
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
    }

    private func row(_ keys: [Character], rowIndex: Int) -> some View {
        HStack(spacing: 5) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                keyCell(key)
            }
        }
        .frame(height: rowHeight)
    }

    private var row3Bar: some View {
        HStack(spacing: 5) {
            KeyView(label: "⇧", style: .shift, showsDot: false, onTap: { isShifted.toggle() })
            HStack(spacing: 5) {
                ForEach(Array(row3.enumerated()), id: \.offset) { _, key in
                    keyCell(key)
                }
            }
            KeyView(label: "⌫", style: .function, showsDot: false, onTap: onDeleteBackward)
        }
        .frame(height: rowHeight)
    }

    @ViewBuilder
    private func keyCell(_ key: Character) -> some View {
        let dotted = Self.dotted.contains(key)
        GeometryReader { cellGeo in
            KeyView(
                label: isShifted ? String(key).uppercased() : String(key),
                style: .letter,
                showsDot: dotted,
                onPressBegan: { beginPress(on: key, frame: cellGeo.frame(in: .local)) },
                onDrag: { point in drag(to: point, cellOrigin: cellGeo.frame(in: .global).origin) },
                onPressEnded: { _ in endPress() },
                onTap: { tap(key) }
            )
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Gesture dispatch

    private func tap(_ key: Character) {
        // Tap fires iff no popover is visible. The plain-tap path is
        // already taken care of by onPressEnded -> endPress; this is here
        // for future-proofing when onTap fires without any drag.
        if popoverKey == nil {
            let s = isShifted ? String(key).uppercased() : String(key)
            onInsertText(s)
            if isShifted { isShifted = false }
        }
    }

    private func beginPress(on key: Character, frame: CGRect) {
        let token = touch.begin(key: key)
        if Self.dotted.contains(key), let variants = IPAMapping.variants[key] {
            popoverVariants = variants
            popoverKeyFrame = frame
            popoverSelection = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + LayoutEngine.popoverDelay) {
                if touch.shouldShowPopover(for: token) {
                    popoverKey = key
                }
            }
        }
    }

    private func drag(to point: CGPoint, cellOrigin: CGPoint) {
        guard popoverKey != nil else { return }
        let variantCount = popoverVariants.count
        guard variantCount > 0 else { return }
        let bucketWidth: CGFloat = 44
        let origin = LayoutEngine.popoverRect(
            keyFrame: popoverKeyFrame,
            popoverSize: CGSize(width: CGFloat(variantCount) * bucketWidth + 16, height: 52),
            keyboardBounds: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: totalHeight)
        ).origin
        let relX = point.x - origin.x
        let index = Int((relX) / bucketWidth)
        popoverSelection = (0..<variantCount).contains(index) ? index : nil
    }

    private func endPress() {
        if let key = popoverKey, let sel = popoverSelection {
            let variant = popoverVariants[sel]
            onInsertText(variant)
            HapticsService.shared.selection()
        } else if popoverKey == nil, let key = touch.end() {
            let s = isShifted ? String(key).uppercased() : String(key)
            onInsertText(s)
            if isShifted { isShifted = false }
        }
        popoverKey = nil
        popoverVariants = []
        popoverSelection = nil
        touch.cancel()
    }

    // MARK: - Overlay

    @ViewBuilder
    private func popoverOverlay(key: Character, in bounds: CGRect) -> some View {
        let popoverSize = CGSize(
            width: CGFloat(popoverVariants.count) * 44 + 16,
            height: 52
        )
        let rect = LayoutEngine.popoverRect(
            keyFrame: popoverKeyFrame,
            popoverSize: popoverSize,
            keyboardBounds: bounds
        )
        VariantPopover(variants: popoverVariants, selectedIndex: popoverSelection)
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .allowsHitTesting(false)
    }

    // MARK: - Function row + sizing

    private var functionRow: some View {
        HStack(spacing: 5) {
            KeyView(label: "123", style: .function, showsDot: false, onTap: {})
                .frame(maxWidth: 44, maxHeight: .infinity)
            KeyView(label: "🌐", style: .function, showsDot: false, onTap: onAdvanceInputMode)
                .frame(maxWidth: 44, maxHeight: .infinity)
            KeyView(label: "space", style: .function, showsDot: false, onTap: { onInsertText(" ") })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            KeyView(label: "return", style: .returnKey, showsDot: false, onTap: { onInsertText("\n") })
                .frame(maxWidth: 64, maxHeight: .infinity)
        }
        .frame(height: rowHeight)
    }

    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.verticalSizeClass) private var vSize
    private var rowHeight: CGFloat {
        if hSize == .regular { return 54 }
        if vSize == .compact { return 38 }
        return 44
    }
    private var totalHeight: CGFloat { rowHeight * 4 + 30 }
}
