import SwiftUI
import ServiceManagement

struct GeneralSettingsView: View {
    @AppStorage("launchAtLogin") var launchAtLogin = false
    @AppStorage("hideMenuBarIcon") var hideMenuBarIcon = false
    @AppStorage("appTheme") var appTheme: String = "System" // System, Light, Dark
    
    var body: some View {
        Form {
            Section {
                Toggle("登录时启动", isOn: $launchAtLogin)
                
                Toggle("隐藏菜单栏图标", isOn: $hideMenuBarIcon)
                    .onChange(of: hideMenuBarIcon) { _, newValue in
                        NotificationCenter.default.post(name: NSNotification.Name("UpdateMenuBarState"), object: nil)
                    }
                
                Picker("外观", selection: $appTheme) {
                    Text("跟随系统").tag("System")
                    Text("浅色模式").tag("Light")
                    Text("深色模式").tag("Dark")
                }
                .pickerStyle(.menu)
                .onChange(of: appTheme) { _, newValue in
                    updateAppearance(newValue)
                }
            }
        }
        .formStyle(.grouped)
    }
    
    private func updateAppearance(_ theme: String) {
        let appearance: NSAppearance?
        switch theme {
        case "Light": appearance = NSAppearance(named: .aqua)
        case "Dark": appearance = NSAppearance(named: .darkAqua)
        default: appearance = nil
        }
        NSApp.appearance = appearance
    }
}
