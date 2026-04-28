import SwiftUI

struct VariantPopover: View {
    let variants: [String]
    let selectedIndex: Int?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(variants.enumerated()), id: \.offset) { index, variant in
                let isSelected = selectedIndex == index
                Text(variant)
                    .font(.system(size: 22, weight: .regular, design: .serif))
                    .foregroundColor(isSelected ? .black : .primary)
                    .frame(minWidth: 36, minHeight: 44)
                    .padding(.horizontal, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(
                                isSelected
                                    ? Color.ipaAccent
                                    : Color(uiColor: .systemGray4)
                            )
                    )
                    .accessibilityLabel(variant)
                    .accessibilityAddTraits(.isButton)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 3)
        )
    }
}

#Preview {
    VariantPopover(variants: ["æ", "ʌ", "ɑː"], selectedIndex: 0)
        .padding()
}
