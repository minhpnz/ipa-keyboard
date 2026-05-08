import SwiftUI

struct ToastModifier: ViewModifier {
    let message: String?

    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content
            if let message {
                Text(message)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.black.opacity(0.78))
                    )
                    .padding(.bottom, 80)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .accessibilityLabel(message)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: message)
    }
}

extension View {
    func ipaToast(message: String?) -> some View {
        modifier(ToastModifier(message: message))
    }
}
