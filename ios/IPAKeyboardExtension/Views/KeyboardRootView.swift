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

    var body: some View {
        VStack(spacing: 6) {
            KeyRow(keys: row1, isShifted: isShifted, onTap: insert)
                .frame(height: rowHeight)

            HStack {
                Spacer(minLength: sideInset)
                KeyRow(keys: row2, isShifted: isShifted, onTap: insert)
                    .frame(height: rowHeight)
                Spacer(minLength: sideInset)
            }

            HStack(spacing: 5) {
                KeyView(label: "⇧", style: .shift, showsDot: false, onTap: { isShifted.toggle() })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                KeyRow(keys: row3, isShifted: isShifted, onTap: insert)
                    .frame(height: rowHeight)
                KeyView(label: "⌫", style: .function, showsDot: false, onTap: { onDeleteBackward() })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: rowHeight)

            functionRow
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .frame(height: totalHeight)
        .background(Color(uiColor: .systemGray6))
    }

    private var functionRow: some View {
        HStack(spacing: 5) {
            KeyView(label: "123", style: .function, showsDot: false, onTap: { /* Phase 4 */ })
                .frame(maxWidth: 44, maxHeight: .infinity)
            KeyView(label: "🌐", style: .function, showsDot: false, onTap: onAdvanceInputMode)
                .frame(maxWidth: 44, maxHeight: .infinity)
            KeyView(label: "space", style: .function, showsDot: false, onTap: { onInsertText(" ") })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            KeyView(label: "IPA", style: .function, showsDot: false, onTap: { /* future */ })
                .frame(maxWidth: 44, maxHeight: .infinity)
                .opacity(0.5)
                .disabled(true)
            KeyView(label: "return", style: .returnKey, showsDot: false, onTap: { onInsertText("\n") })
                .frame(maxWidth: 64, maxHeight: .infinity)
        }
        .frame(height: rowHeight)
    }

    private func insert(_ key: Character) {
        let s = isShifted ? String(key).uppercased() : String(key)
        onInsertText(s)
        if isShifted { isShifted = false }
    }

    // Size-class-adaptive sizing. Actual iOS keyboard heights.
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.verticalSizeClass) private var vSize

    private var rowHeight: CGFloat {
        if hSize == .regular { return 54 }            // iPad
        if vSize == .compact { return 38 }            // iPhone landscape
        return 44                                     // iPhone portrait
    }

    private var totalHeight: CGFloat {
        rowHeight * 4 + 30
    }

    private var sideInset: CGFloat { 18 }
}
