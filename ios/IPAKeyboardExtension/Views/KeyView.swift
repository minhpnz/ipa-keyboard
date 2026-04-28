import SwiftUI

struct KeyView: View {
    enum Style { case letter, function, returnKey, shift }

    let label: String
    let style: Style
    let showsDot: Bool
    var onPressBegan: () -> Void = {}
    var onDrag: (CGPoint) -> Void = { _ in }
    var onPressEnded: (Bool) -> Void = { _ in }
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
                    .fill(Color.ipaAccent)
                    .frame(width: 5, height: 5)
                    .offset(x: -5, y: 5)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .scaleEffect(isPressed ? 0.96 : 1)
        .animation(.easeOut(duration: 0.08), value: isPressed)
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    if !isPressed {
                        isPressed = true
                        onPressBegan()
                    }
                    onDrag(value.location)
                }
                .onEnded { value in
                    isPressed = false
                    onPressEnded(value.translation == .zero)
                    if value.translation == .zero {
                        onTap()
                    }
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
        case .returnKey: return Color.ipaAccent
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

    // TODO(phase-3): dotted keys (showsDot=true) should announce "Key a, has variants".
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
