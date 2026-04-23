import SwiftUI

struct KeyView: View {
    enum Style { case letter, function, returnKey, shift }

    let label: String
    let style: Style
    let showsDot: Bool
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(background)
                .overlay(
                    Text(label)
                        .font(font)
                        .foregroundColor(foreground)
                )
            if showsDot {
                Circle()
                    .fill(Color(red: 0.40, green: 0.67, blue: 1.0))
                    .frame(width: 5, height: 5)
                    .offset(x: -5, y: 5)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .scaleEffect(isPressed ? 0.96 : 1)
        .animation(.easeOut(duration: 0.08), value: isPressed)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in
                    isPressed = false
                    onTap()
                }
        )
        .accessibilityElement()
        .accessibilityLabel(accessibilityName)
        .accessibilityAddTraits(.isKeyboardKey)
    }

    private var background: Color {
        switch style {
        case .letter: return Color(uiColor: .systemGray4)
        case .function: return Color(uiColor: .systemGray3)
        case .returnKey: return Color(red: 0.40, green: 0.67, blue: 1.0)
        case .shift: return Color(uiColor: .systemGray3)
        }
    }

    private var foreground: Color {
        style == .returnKey ? .black : .primary
    }

    private var font: Font {
        switch style {
        case .letter: return .system(size: 22, weight: .regular)
        case .function, .shift: return .system(size: 14, weight: .regular)
        case .returnKey: return .system(size: 14, weight: .semibold)
        }
    }

    private var accessibilityName: String {
        switch style {
        case .letter: return "Key \(label)"
        case .function:
            if label == "space" { return "Space" }
            if label == "🌐" { return "Next keyboard" }
            if label == "123" { return "Numbers" }
            return label
        case .returnKey: return "Return"
        case .shift: return "Shift"
        }
    }
}

#Preview {
    HStack(spacing: 8) {
        KeyView(label: "q", style: .letter, showsDot: false, onTap: {})
        KeyView(label: "a", style: .letter, showsDot: true, onTap: {})
        KeyView(label: "⌫", style: .function, showsDot: false, onTap: {})
        KeyView(label: "return", style: .returnKey, showsDot: false, onTap: {})
    }
    .padding()
    .frame(height: 60)
}
