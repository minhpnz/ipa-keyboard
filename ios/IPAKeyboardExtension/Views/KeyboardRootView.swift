import SwiftUI
import IPACore

struct KeyboardRootView: View {

    let onInsertText: (String) -> Void
    let onDeleteBackward: () -> Void
    let onAdvanceInputMode: () -> Void

    @State private var isShifted: Bool = false

    private let row1: [Character] = Array("qwertyuiop")
    private let row2: [Character] = Array("asdfghjkl")
    private let row3: [Character] = Array("zxcvbnm")

    private let keySpacing: CGFloat = 5
    private let horizontalPadding: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            let available = geo.size.width - horizontalPadding * 2
            // Row 1 has 10 letters and 9 gaps.
            let letterW = (available - keySpacing * 9) / 10
            let shiftW = letterW * 1.25
            let row2Inset = (letterW + keySpacing) / 2

            VStack(spacing: 6) {
                KeyRow(keys: row1, isShifted: isShifted,
                       keyWidth: letterW, spacing: keySpacing,
                       onTap: insert)
                    .frame(height: rowHeight)

                KeyRow(keys: row2, isShifted: isShifted,
                       keyWidth: letterW, spacing: keySpacing,
                       onTap: insert)
                    .padding(.horizontal, row2Inset)
                    .frame(height: rowHeight)

                HStack(spacing: keySpacing) {
                    KeyView(label: "⇧", style: .shift, showsDot: false,
                            onTap: { isShifted.toggle() })
                        .frame(width: shiftW)
                    KeyRow(keys: row3, isShifted: isShifted,
                           keyWidth: letterW, spacing: keySpacing,
                           onTap: insert)
                    KeyView(label: "⌫", style: .function, showsDot: false,
                            onTap: { onDeleteBackward() })
                        .frame(width: shiftW)
                }
                .frame(height: rowHeight)

                functionRow(letterW: letterW)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, horizontalPadding)
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .systemGray6))
        }
        .frame(height: totalHeight)
    }

    private func functionRow(letterW: CGFloat) -> some View {
        // 123 / globe / space / IPA / return — keep 123/globe/IPA at ~1.5×
        // letter width (matches shift/backspace above), return slightly wider.
        let functionW = letterW * 1.5
        let returnW = letterW * 2
        return HStack(spacing: keySpacing) {
            KeyView(label: "123", style: .function, showsDot: false, onTap: { /* Phase 4 */ })
                .frame(width: functionW)
            KeyView(label: "🌐", style: .function, showsDot: false, onTap: onAdvanceInputMode)
                .frame(width: functionW)
            KeyView(label: "space", style: .function, showsDot: false, onTap: { onInsertText(" ") })
                .frame(maxWidth: .infinity)
            KeyView(label: "IPA", style: .function, showsDot: false, onTap: { /* future */ })
                .frame(width: functionW)
                .opacity(0.5)
                .disabled(true)
            KeyView(label: "return", style: .returnKey, showsDot: false, onTap: { onInsertText("\n") })
                .frame(width: returnW)
        }
        .frame(height: rowHeight)
    }

    private func insert(_ key: Character) {
        let s = isShifted ? String(key).uppercased() : String(key)
        onInsertText(s)
        if isShifted { isShifted = false }
    }

    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.verticalSizeClass) private var vSize

    private var rowHeight: CGFloat {
        if hSize == .regular { return 54 }
        if vSize == .compact { return 38 }
        return 44
    }

    private var totalHeight: CGFloat {
        rowHeight * 4 + 30
    }
}
