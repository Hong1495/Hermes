import SwiftUI
import ServiceManagement

struct GeneralSettingsView: View {
    @AppStorage("launchAtLogin") var launchAtLogin = false
    @AppStorage("hideMenuBarIcon") var hideMenuBarIcon = false
    @AppStorage("appTheme") var appTheme: String = "System" // System, Light, Dark
    @AppStorage("defaultSavePath") var defaultSavePath: String = ""
    @AppStorage("autoTranslateMode") var autoTranslateMode = false
    
    var body: some View {
        Form {
            Section {
                Toggle("登录时启动", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            print("Failed to update login item: \(error)")
                            // Revert the toggle if operation failed
                            launchAtLogin = !newValue
                        }
                    }
                
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
            
            Section("翻译设置") {
                Toggle("智能模式 (自动检测)", isOn: $autoTranslateMode)
                Text("开启后, 输入中文将自动翻译为英文, 输入英文或其他语言将自动翻译为中文。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("保存设置") {
                HStack {
                    Text("默认保存路径")
                    Spacer()
                    Text(defaultSavePath.isEmpty ? "桌面 (默认)" : (URL(fileURLWithPath: defaultSavePath).lastPathComponent))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Button("选择...") {
                        selectFolder()
                    }
                }
                
                if !defaultSavePath.isEmpty {
                    Button("重置为桌面") {
                        defaultSavePath = ""
                    }
                    .foregroundColor(.red)
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
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.title = "选择默认保存目录"
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                defaultSavePath = url.path
                
                // Create Security Scoped Bookmark
                do {
                    let bookmarkData = try url.bookmarkData(
                        options: .withSecurityScope,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                    UserDefaults.standard.set(bookmarkData, forKey: "defaultSavePathBookmark")
                } catch {
                    print("Failed to create bookmark: \(error)")
                }
            }
        }
    }
}
