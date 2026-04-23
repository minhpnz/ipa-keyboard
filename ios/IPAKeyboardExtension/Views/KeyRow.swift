import SwiftUI
import IPACore

struct KeyRow: View {
    let keys: [Character]
    let isShifted: Bool
    let onTap: (Character) -> Void

    private static let dotted: Set<Character> = Set(IPAMapping.dottedKeys)

    var body: some View {
        HStack(spacing: 5) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                KeyView(
                    label: isShifted ? String(key).uppercased() : String(key),
                    style: .letter,
                    showsDot: Self.dotted.contains(key),
                    onTap: { onTap(key) }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
