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
        static let extraLarge: CGFloat = 20
    }

    struct Colors {
        static let background = Color(lightHex: "F4F0E8", darkHex: "1D1916")
        static let panelBackground = Color(lightHex: "FBF8F2", darkHex: "29231F")
        static let panelElevated = Color(lightHex: "FFFDFC", darkHex: "342D28")
        static let workspaceBackground = Color(lightHex: "ECE7DE", darkHex: "231F1B")
        static let imageStageBackground = Color(lightHex: "DDD6CB", darkHex: "181411")
        static let glassBackground = panelBackground
        static let glassInputBackground = panelElevated
        static let glassBorder = Color(lightHex: "DED5C8", darkHex: "4B4038")
        static let separator = Color(lightHex: "E6DED2", darkHex: "3D342E")
        static let borderStrong = Color(lightHex: "CDC3B5", darkHex: "625449")

        static let accent = Color(lightHex: "9C6644", darkHex: "D09067")
        static let accentSoft = Color(lightHex: "EAD8CB", darkHex: "4A3428")
        static let accentPressed = Color(lightHex: "7F5237", darkHex: "B77A53")
        static let success = Color(lightHex: "5C7A63", darkHex: "7FA08A")
        static let warning = Color(lightHex: "B07A3F", darkHex: "D59B59")
        static let danger = Color(lightHex: "A94F44", darkHex: "CC7267")

        static let textPrimary = Color(lightHex: "26231E", darkHex: "F3E8DB")
        static let textSecondary = Color(lightHex: "6B645B", darkHex: "BCB0A2")
        static let textTertiary = Color(lightHex: "948C82", darkHex: "8D8175")
    }

    struct Shadows {
        static let panel = ShadowStyle(color: .black.opacity(0.18), radius: 24, x: 0, y: 10)
        static let card = ShadowStyle(color: .black.opacity(0.10), radius: 12, x: 0, y: 4)
    }
}

struct ShadowStyle {
    var color: Color
    var radius: CGFloat
    var x: CGFloat
    var y: CGFloat
}

private extension Color {
    init(lightHex: String, darkHex: String) {
        self.init(
            nsColor: NSColor(name: nil) { appearance in
                let bestMatch = appearance.bestMatch(from: [.darkAqua, .aqua]) ?? .aqua
                return bestMatch == .darkAqua ? NSColor(hex: darkHex) : NSColor(hex: lightHex)
            }
        )
    }
}

private extension NSColor {
    convenience init(hex: String) {
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
            alpha: 1
        )
    }
}
