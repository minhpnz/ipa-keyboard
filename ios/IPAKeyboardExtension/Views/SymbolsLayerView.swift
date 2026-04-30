import SwiftUI

/// "#+=" layer — symbols. Mirrors stock iOS layout minus the in-keyboard 🌐.
struct SymbolsLayerView: View {
    let onInsertText: (String) -> Void
    let onDeleteBackward: () -> Void
    let onSwitchToAlpha: () -> Void
    let onSwitchToNumbers: () -> Void

    private let row1: [String] = ["[","]","{","}","#","%","^","*","+","="]
    private let row2: [String] = ["_","\\","|","~","<",">","€","£","¥","•"]
    private let row3: [String] = [".",",","?","!","'"]

    private static let horizontalPadding: CGFloat = 4
    private static let keySpacing: CGFloat = 5
    private static let switchMultiple: CGFloat = 1.25

    var body: some View {
        GeometryReader { geo in
            let available = geo.size.width - Self.horizontalPadding * 2
            let letterW = (available - Self.keySpacing * 9) / 10
            let switchW = letterW * Self.switchMultiple
            let returnW = letterW * 2

            VStack(spacing: 6) {
                cellRow(row1, letterW: letterW)
                cellRow(row2, letterW: letterW)
                HStack(spacing: Self.keySpacing) {
                    KeyView(label: "123", style: .function, showsDot: false,
                            onTap: onSwitchToNumbers)
                        .frame(width: switchW)
                    HStack(spacing: Self.keySpacing) {
                        ForEach(row3, id: \.self) { c in punctCell(c) }
                    }
                    KeyView(label: "⌫", style: .function, showsDot: false,
                            onTap: onDeleteBackward)
                        .frame(width: switchW)
                }
                .frame(height: rowHeight)
                HStack(spacing: Self.keySpacing) {
                    KeyView(label: "ABC", style: .function, showsDot: false,
                            onTap: onSwitchToAlpha)
                        .frame(width: switchW)
                    KeyView(label: "space", style: .function, showsDot: false,
                            onTap: { onInsertText(" ") })
                        .frame(maxWidth: .infinity)
                    KeyView(label: "return", style: .returnKey, showsDot: false,
                            onTap: { onInsertText("\n") })
                        .frame(width: returnW)
                }
                .frame(height: rowHeight)
            }
        }
        .frame(height: totalHeight)
    }

    private func cellRow(_ cells: [String], letterW: CGFloat) -> some View {
        HStack(spacing: Self.keySpacing) {
            ForEach(cells, id: \.self) { c in
                KeyView(label: c, style: .letter, showsDot: false,
                        onTap: { onInsertText(c) })
                    .frame(width: letterW)
            }
        }
        .frame(height: rowHeight)
    }

    private func punctCell(_ c: String) -> some View {
        KeyView(label: c, style: .letter, showsDot: false,
                onTap: { onInsertText(c) })
            .frame(maxWidth: .infinity)
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

#Preview {
    SymbolsLayerView(
        onInsertText: { _ in },
        onDeleteBackward: {},
        onSwitchToAlpha: {},
        onSwitchToNumbers: {}
    )
    .background(Color(uiColor: .systemGray6))
}
