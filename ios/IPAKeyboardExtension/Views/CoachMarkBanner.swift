import SwiftUI

/// First-run hint pill shown for the first 3 keyboard activations
/// (see `CoachMarkPolicy`). Sits above the keyboard in the prediction-bar
/// zone so it costs no keyboard layout space.
struct CoachMarkBanner: View {
    var body: some View {
        Text("Long-press dotted keys for IPA · Open IPA Keyboard app for help")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.72))
            )
            .accessibilityLabel("Tip: long-press dotted keys to type IPA variants")
    }
}

#Preview {
    CoachMarkBanner()
        .padding()
}
