import SwiftUI
import IPACore

struct KeyRow: View {
    let keys: [Character]
    let isShifted: Bool
    let keyWidth: CGFloat
    let spacing: CGFloat
    let onTap: (Character) -> Void

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                KeyView(
                    label: isShifted ? String(key).uppercased() : String(key),
                    style: .letter,
                    showsDot: IPAMapping.dottedKeySet.contains(key),
                    onTap: { onTap(key) }
                )
                .frame(width: keyWidth)
            }
        }
    }
}
