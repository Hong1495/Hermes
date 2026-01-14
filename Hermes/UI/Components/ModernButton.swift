import SwiftUI

enum ModernButtonStyleType {
    case primary
    case secondary
    case ghost
    case icon
}

struct ModernButtonStyle: ButtonStyle {
    var type: ModernButtonStyleType
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: type == .icon ? 18 : 13, weight: .medium))
            .padding(.horizontal, type == .icon ? 8 : 12)
            .padding(.vertical, type == .icon ? 8 : 6)
            .background(backgroundView(isPressed: configuration.isPressed))
            .foregroundColor(foregroundColor(isPressed: configuration.isPressed))
            .cornerRadius(Theme.CornerRadius.small)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
    
    @ViewBuilder
    private func backgroundView(isPressed: Bool) -> some View {
        switch type {
        case .primary:
            Theme.Colors.accent.opacity(isPressed ? 0.8 : 1.0)
        case .secondary:
            Theme.Colors.glassBackground
                .opacity(isPressed ? 2.0 : 1.0) // Double opacity visually on press
        case .ghost:
            Theme.Colors.glassBackground.opacity(isPressed ? 0.5 : 0.0)
        case .icon:
            Theme.Colors.glassBackground.opacity(isPressed ? 0.5 : 0.0)
        }
    }
    
    private func foregroundColor(isPressed: Bool) -> Color {
        switch type {
        case .primary: return .white
        case .secondary: return .primary
        case .ghost: return .secondary
        case .icon: return isPressed ? .primary : .secondary
        }
    }
}

extension Button {
    func modernStyle(_ type: ModernButtonStyleType = .primary) -> some View {
        self.buttonStyle(ModernButtonStyle(type: type))
    }
}
