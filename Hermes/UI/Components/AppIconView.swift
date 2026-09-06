import AppKit
import SwiftUI

struct AppIconView: View {
    let path: String
    var size: CGFloat = 36

    var body: some View {
        if let image = appIcon(for: path) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 2, x: 0, y: 1)
        } else {
            Image(systemName: "app.fill")
                .resizable()
                .foregroundStyle(Theme.Colors.accent)
                .frame(width: size, height: size)
        }
    }

    private func appIcon(for path: String) -> NSImage? {
        if FileManager.default.fileExists(atPath: path) {
            return NSWorkspace.shared.icon(forFile: path)
        }
        return nil
    }
}
