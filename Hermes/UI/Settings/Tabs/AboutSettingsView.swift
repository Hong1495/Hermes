import SwiftUI

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: NSImage(named: "AppIcon") ?? NSImage(systemSymbolName: "cursorarrow.click.2", accessibilityDescription: nil)!)
                .resizable()
                .frame(width: 64, height: 64)
            
            Text("Hermes")
                .font(.title)
                .bold()
            
            Text("版本 1.0.0")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Link("产品社区", destination: URL(string: "https://github.com/sakyahong/hermes")!)
                .font(.caption)
        }
    }
}
