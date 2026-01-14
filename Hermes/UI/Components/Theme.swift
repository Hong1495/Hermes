import SwiftUI

struct Theme {
    struct Spacing {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let extraLarge: CGFloat = 24
    }
    
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
    }
    
    struct Colors {
        static let background = Color.clear
        // Adaptive glass backgrounds - more transparent for system theme visibility
        static let glassBackground = Color.primary.opacity(0.03)
        static let glassInputBackground = Color.primary.opacity(0.05)
        static let glassBorder = Color.primary.opacity(0.1)
        static let separator = Color.primary.opacity(0.08)
        
        static let accent = Color.blue
        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary
    }
    
    struct Shadows {
        static let panel = ShadowStyle(color: .black.opacity(0.2), radius: 20, x: 0, y: 5)
    }
}

struct ShadowStyle {
    var color: Color
    var radius: CGFloat
    var x: CGFloat
    var y: CGFloat
}
