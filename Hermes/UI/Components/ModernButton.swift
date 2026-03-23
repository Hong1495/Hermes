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
            .font(.system(size: type == .icon ? 15 : 13, weight: .medium))
            .padding(.horizontal, type == .icon ? 8 : 12)
            .padding(.vertical, type == .icon ? 8 : 7)
            .background(backgroundView(isPressed: configuration.isPressed))
            .foregroundColor(foregroundColor(isPressed: configuration.isPressed))
            .overlay(borderView)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
    
    @ViewBuilder
    private func backgroundView(isPressed: Bool) -> some View {
        switch type {
        case .primary:
            (isPressed ? Theme.Colors.accentPressed : Theme.Colors.accent)
        case .secondary:
            (isPressed ? Theme.Colors.accentSoft.opacity(0.85) : Theme.Colors.panelElevated)
        case .ghost:
            Theme.Colors.accentSoft.opacity(isPressed ? 0.7 : 0.0)
        case .icon:
            Theme.Colors.accentSoft.opacity(isPressed ? 0.7 : 0.0)
        }
    }
    
    private func foregroundColor(isPressed: Bool) -> Color {
        switch type {
        case .primary: return .white
        case .secondary: return Theme.Colors.textPrimary
        case .ghost: return Theme.Colors.textSecondary
        case .icon: return isPressed ? Theme.Colors.textPrimary : Theme.Colors.textSecondary
        }
    }

    @ViewBuilder
    private var borderView: some View {
        RoundedRectangle(cornerRadius: Theme.CornerRadius.small, style: .continuous)
            .stroke(borderColor, lineWidth: 1)
    }

    private var borderColor: Color {
        switch type {
        case .primary:
            return Theme.Colors.accent.opacity(0.2)
        case .secondary, .ghost, .icon:
            return Theme.Colors.glassBorder
        }
    }
}

extension Button {
    func modernStyle(_ type: ModernButtonStyleType = .primary) -> some View {
        self.buttonStyle(ModernButtonStyle(type: type))
    }
}
