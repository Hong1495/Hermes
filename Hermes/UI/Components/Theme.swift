import AppKit
import SwiftUI

struct Theme {
    struct Spacing {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let extraLarge: CGFloat = 24
        static let xxLarge: CGFloat = 32
    }

    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let extraLarge: CGFloat = 22
        static let superLarge: CGFloat = 28
    }

    struct Colors {
        // macOS 27 Golden Gate 飘逸灵动液态玻璃规范配色
        static let background = Color(
            lightHex: "F6F4EF",
            darkHex: "1A1815",
            lightAlpha: 0.92,
            darkAlpha: 0.94
        )

        static let sidebarBackground = Color(
            lightHex: "EFECE5",
            darkHex: "161412",
            lightAlpha: 0.88,
            darkAlpha: 0.90
        )

        static let panelBackground = Color(
            lightHex: "FFFFFF",
            darkHex: "26221E",
            lightAlpha: 0.72,
            darkAlpha: 0.65
        )

        static let panelElevated = Color(
            lightHex: "FFFFFF",
            darkHex: "2E2924",
            lightAlpha: 0.85,
            darkAlpha: 0.80
        )

        static let workspaceBackground = Color(
            lightHex: "EFECE6",
            darkHex: "201C19",
            lightAlpha: 0.85,
            darkAlpha: 0.85
        )

        static let imageStageBackground = Color(
            lightHex: "E2DCD3",
            darkHex: "15120F",
            lightAlpha: 0.85,
            darkAlpha: 0.85
        )

        static let glassBackground = panelBackground
        static let glassInputBackground = panelElevated

        // 高光微晶玻璃描边
        static let glassBorder = Color(
            lightHex: "FFFFFF",
            darkHex: "FFFFFF",
            lightAlpha: 0.60,
            darkAlpha: 0.16
        )

        static let separator = Color(
            lightHex: "000000",
            darkHex: "FFFFFF",
            lightAlpha: 0.06,
            darkAlpha: 0.08
        )

        static let borderStrong = Color(
            lightHex: "000000",
            darkHex: "FFFFFF",
            lightAlpha: 0.12,
            darkAlpha: 0.18
        )

        // 品牌陶土琥珀金强调色
        static let accent = Color(lightHex: "9C6644", darkHex: "E09B70")
        static let accentSoft = Color(
            lightHex: "9C6644",
            darkHex: "E09B70",
            lightAlpha: 0.12,
            darkAlpha: 0.18
        )
        static let accentPressed = Color(lightHex: "7F5237", darkHex: "C48157")

        static let success = Color(lightHex: "437A54", darkHex: "68B080")
        static let warning = Color(lightHex: "B8722D", darkHex: "E0984E")
        static let danger = Color(lightHex: "B83D33", darkHex: "E56358")

        static let textPrimary = Color(lightHex: "221F1B", darkHex: "F6EFE7")
        static let textSecondary = Color(lightHex: "635D56", darkHex: "B6ABA0")
        static let textTertiary = Color(lightHex: "928B83", darkHex: "847B72")
    }

    struct Shadows {
        static let panel = ShadowStyle(color: .black.opacity(0.14), radius: 28, x: 0, y: 12)
        static let card = ShadowStyle(color: .black.opacity(0.06), radius: 14, x: 0, y: 4)
    }
}

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = Theme.CornerRadius.medium
    var padding: CGFloat = Theme.Spacing.large

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.Colors.panelElevated)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.45), Color.white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: Theme.Shadows.card.color, radius: Theme.Shadows.card.radius, x: Theme.Shadows.card.x, y: Theme.Shadows.card.y)
    }
}

struct GlassCardElevatedModifier: ViewModifier {
    var cornerRadius: CGFloat = Theme.CornerRadius.medium
    var padding: CGFloat = Theme.Spacing.large

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.Colors.panelElevated)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .glassEffect(.regular.tint(Theme.Colors.accent.opacity(0.06)), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.55), Color.white.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: Theme.Shadows.panel.color, radius: Theme.Shadows.panel.radius, x: Theme.Shadows.panel.x, y: Theme.Shadows.panel.y)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = Theme.CornerRadius.medium, padding: CGFloat = Theme.Spacing.large) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, padding: padding))
    }

    func glassCardElevated(cornerRadius: CGFloat = Theme.CornerRadius.medium, padding: CGFloat = Theme.Spacing.large) -> some View {
        modifier(GlassCardElevatedModifier(cornerRadius: cornerRadius, padding: padding))
    }
}

struct ShadowStyle {
    var color: Color
    var radius: CGFloat
    var x: CGFloat
    var y: CGFloat
}

private extension Color {
    init(lightHex: String, darkHex: String, lightAlpha: CGFloat = 1.0, darkAlpha: CGFloat = 1.0) {
        self.init(
            nsColor: NSColor(name: nil) { appearance in
                let bestMatch = appearance.bestMatch(from: [.darkAqua, .aqua]) ?? .aqua
                return bestMatch == .darkAqua
                    ? NSColor(hex: darkHex, alpha: darkAlpha)
                    : NSColor(hex: lightHex, alpha: lightAlpha)
            }
        )
    }
}

private extension NSColor {
    convenience init(hex: String, alpha: CGFloat = 1.0) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64

        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }

        self.init(
            srgbRed: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: alpha
        )
    }
}
