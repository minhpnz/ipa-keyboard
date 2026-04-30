import SwiftUI
import IPACore

enum KeyboardLayer {
    case alpha
    case numbers   // "123" — digits + common punctuation
    case symbols   // "#+=" — symbols
}

struct KeyboardRootView: View {

    let onInsertText: (String) -> Void
    let onDeleteBackward: () -> Void
    let onAdvanceInputMode: () -> Void

    @State private var layer: KeyboardLayer = .alpha
    @State private var isShifted: Bool = false
    @State private var touch = TouchState()
    @State private var popoverKey: Character? = nil
    @State private var popoverVariants: [String] = []
    @State private var popoverKeyFrame: CGRect = .zero
    @State private var popoverSelection: Int? = nil
    @State private var keyboardSize: CGSize = .zero
    @State private var coachMarkVisible: Bool = false

    private let row1: [Character] = Array("qwertyuiop")
    private let row2: [Character] = Array("asdfghjkl")
    private let row3: [Character] = Array("zxcvbnm")
    private static let dotted: Set<Character> = Set(IPAMapping.dottedKeys)

    // Layout constants — same values as the pre-popover-wiring layer
    // (commit bed47dc). Row 1 has 10 letters and 9 gaps; shift/backspace
    // are 1.25× a letter so row 3 letters end up the same width as the
    // others rather than getting squeezed into 1/3 of the row.
    private static let horizontalPadding: CGFloat = 4
    private static let keySpacing: CGFloat = 5
    private static let shiftWidthMultiple: CGFloat = 1.25

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                keyboardBody(in: geo.size)
                if popoverKey != nil {
                    popoverOverlay(in: CGRect(origin: .zero, size: geo.size))
                }
                if coachMarkVisible {
                    VStack {
                        CoachMarkBanner()
                            .padding(.top, 2)
                        Spacer()
                    }
                    .frame(width: geo.size.width)
                    .transition(.opacity)
                    .allowsHitTesting(false)
                }
            }
            .coordinateSpace(name: "keyboardRoot")
            .onAppear { keyboardSize = geo.size }
            .onChange(of: geo.size) { newValue in keyboardSize = newValue }
        }
        .frame(height: totalHeight)
        .background(Color(uiColor: .systemGray6))
        .onReceive(NotificationCenter.default.publisher(for: .ipaKeyboardShouldCancelGesture)) { _ in
            cancelInFlightGesture()
        }
        .onReceive(NotificationCenter.default.publisher(for: .ipaKeyboardActivationCountChanged)) { note in
            handleActivationCount(note.userInfo?["count"] as? Int ?? 0)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            coachMarkVisible = false
        }
    }

    private func handleActivationCount(_ count: Int) {
        guard CoachMarkPolicy.shouldShow(forActivationCount: count) else { return }
        withAnimation(.easeIn(duration: 0.2)) { coachMarkVisible = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + CoachMarkPolicy.autoDismissDelay) {
            withAnimation(.easeOut(duration: 0.2)) { coachMarkVisible = false }
        }
    }

    /// Any user interaction with the keyboard dismisses the banner early.
    /// No-op when the banner isn't visible so it's safe to call on every tap.
    private func dismissCoachMarkIfVisible() {
        guard coachMarkVisible else { return }
        withAnimation(.easeOut(duration: 0.2)) { coachMarkVisible = false }
    }

    private func cancelInFlightGesture() {
        touch.cancel()
        popoverKey = nil
        popoverVariants = []
        popoverSelection = nil
    }

    @ViewBuilder
    private func keyboardBody(in size: CGSize) -> some View {
        switch layer {
        case .alpha:
            alphaContent(in: size)
                .padding(.vertical, 6)
                .padding(.horizontal, Self.horizontalPadding)
        case .numbers:
            NumbersLayerView(
                onInsertText: { dismissCoachMarkIfVisible(); onInsertText($0) },
                onDeleteBackward: { dismissCoachMarkIfVisible(); onDeleteBackward() },
                onSwitchToAlpha: { dismissCoachMarkIfVisible(); layer = .alpha },
                onSwitchToSymbols: { dismissCoachMarkIfVisible(); layer = .symbols }
            )
            .padding(.vertical, 6)
            .padding(.horizontal, Self.horizontalPadding)
        case .symbols:
            SymbolsLayerView(
                onInsertText: { dismissCoachMarkIfVisible(); onInsertText($0) },
                onDeleteBackward: { dismissCoachMarkIfVisible(); onDeleteBackward() },
                onSwitchToAlpha: { dismissCoachMarkIfVisible(); layer = .alpha },
                onSwitchToNumbers: { dismissCoachMarkIfVisible(); layer = .numbers }
            )
            .padding(.vertical, 6)
            .padding(.horizontal, Self.horizontalPadding)
        }
    }

    private func alphaContent(in size: CGSize) -> some View {
        let available = size.width - Self.horizontalPadding * 2
        let letterW = (available - Self.keySpacing * 9) / 10
        let shiftW = letterW * Self.shiftWidthMultiple
        let row2Inset = (letterW + Self.keySpacing) / 2

        return VStack(spacing: 6) {
            row(row1, letterW: letterW)
            row(row2, letterW: letterW)
                .padding(.horizontal, row2Inset)
            row3Bar(letterW: letterW, shiftW: shiftW)
            alphaFunctionRow(letterW: letterW)
        }
    }

    private func row(_ keys: [Character], letterW: CGFloat) -> some View {
        HStack(spacing: Self.keySpacing) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                keyCell(key)
                    .frame(width: letterW)
            }
        }
        .frame(height: rowHeight)
    }

    private func row3Bar(letterW: CGFloat, shiftW: CGFloat) -> some View {
        HStack(spacing: Self.keySpacing) {
            KeyView(label: "⇧", style: .shift, showsDot: false,
                    onTap: { dismissCoachMarkIfVisible(); isShifted.toggle() })
                .frame(width: shiftW)
            row(row3, letterW: letterW)
            KeyView(label: "⌫", style: .function, showsDot: false,
                    onTap: { dismissCoachMarkIfVisible(); onDeleteBackward() })
                .frame(width: shiftW)
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
                onPressBegan: { beginPress(on: key, frame: cellGeo.frame(in: .named("keyboardRoot"))) },
                onDrag: { point in drag(to: point) },
                onPressEnded: { _ in endPress() },
                onTap: {}
            )
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Gesture dispatch

    private func beginPress(on key: Character, frame: CGRect) {
        dismissCoachMarkIfVisible()
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

    private func drag(to point: CGPoint) {
        guard popoverKey != nil else { return }
        let variantCount = popoverVariants.count
        guard variantCount > 0 else { return }
        let origin = LayoutEngine.popoverRect(
            keyFrame: popoverKeyFrame,
            popoverSize: LayoutEngine.popoverSize(variantCount: variantCount),
            keyboardBounds: CGRect(origin: .zero, size: keyboardSize)
        ).origin
        let relX = point.x - origin.x
        let index = Int(relX / LayoutEngine.popoverBucketWidth)
        popoverSelection = (0..<variantCount).contains(index) ? index : nil
    }

    private func endPress() {
        if popoverKey != nil, let sel = popoverSelection {
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
    private func popoverOverlay(in bounds: CGRect) -> some View {
        let rect = LayoutEngine.popoverRect(
            keyFrame: popoverKeyFrame,
            popoverSize: LayoutEngine.popoverSize(variantCount: popoverVariants.count),
            keyboardBounds: bounds
        )
        VariantPopover(variants: popoverVariants, selectedIndex: popoverSelection)
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .allowsHitTesting(false)
    }

    // MARK: - Function row + sizing

    private func alphaFunctionRow(letterW: CGFloat) -> some View {
        // No in-keyboard 🌐: iOS 17+ surfaces the input-mode switcher in the
        // system bar below the keyboard, so a duplicate globe key is wasted
        // real estate. advanceToNextInputMode is still wired on the VC.
        let switchW = letterW * Self.shiftWidthMultiple
        let returnW = letterW * 2
        return HStack(spacing: Self.keySpacing) {
            KeyView(label: "123", style: .function, showsDot: false,
                    onTap: { dismissCoachMarkIfVisible(); layer = .numbers })
                .frame(width: switchW)
            KeyView(label: "space", style: .function, showsDot: false,
                    onTap: { dismissCoachMarkIfVisible(); onInsertText(" ") })
                .frame(maxWidth: .infinity)
            KeyView(label: "return", style: .returnKey, showsDot: false,
                    onTap: { dismissCoachMarkIfVisible(); onInsertText("\n") })
                .frame(width: returnW)
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
