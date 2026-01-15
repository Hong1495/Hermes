import SwiftUI

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage())
                .resizable()
                .frame(width: 64, height: 64)
            
            Text("Hermes")
                .font(.title)
                .bold()
            
            Text("版本 1.0.0")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
