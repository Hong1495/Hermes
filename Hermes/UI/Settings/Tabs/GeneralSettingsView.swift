import SwiftUI
import ServiceManagement

struct GeneralSettingsView: View {
    @AppStorage(AppSettings.Key.launchAtLogin) var launchAtLogin = false
    @AppStorage(AppSettings.Key.hideMenuBarIcon) var hideMenuBarIcon = false
    @AppStorage(AppSettings.Key.appTheme) var appTheme: String = AppSettings.Default.appTheme // System, Light, Dark
    @AppStorage(AppSettings.Key.defaultSavePath) var defaultSavePath: String = ""
    @AppStorage(AppSettings.Key.ocrLanguages) var ocrLanguages: String = AppSettings.Default.ocrLanguages

    /// OCR 语言选择的镜像数组（从 ocrLanguages 字符串解析）
    @State private var selectedOCRLanguages: Set<String> = []

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
                            // Revert the toggle if operation failed
                            launchAtLogin = !newValue
                        }
                    }

                Toggle("隐藏菜单栏图标", isOn: $hideMenuBarIcon)
                    .onChange(of: hideMenuBarIcon) { _, newValue in
                        NotificationCenter.default.post(name: .updateMenuBarState, object: nil)
                    }

                Picker("外观", selection: $appTheme) {
                    Text("跟随系统").tag("System")
                    Text("浅色模式").tag("Light")
                    Text("深色模式").tag("Dark")
                }
                .pickerStyle(.menu)
                .onChange(of: appTheme) { _, newValue in
                    AppSettings.updateAppearance(newValue)
                }
            }

            Section("OCR 取词") {
                Text("选择静默 OCR（⌘⇧O）支持识别的语言，建议按常用程度勾选以提升准确率。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                ForEach(OCRService.supportedLanguages, id: \.code) { language in
                    Toggle(language.label, isOn: Binding(
                        get: { selectedOCRLanguages.contains(language.code) },
                        set: { isSelected in
                            if isSelected {
                                selectedOCRLanguages.insert(language.code)
                            } else {
                                selectedOCRLanguages.remove(language.code)
                            }
                            persistOCRLanguages()
                        }
                    ))
                }
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
                        UserDefaults.standard.removeObject(forKey: AppSettings.Key.defaultSavePathBookmark)
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .formStyle(.grouped)
        .hideScrollIndicators()
        .onAppear {
            selectedOCRLanguages = Set(ocrLanguages.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) })
            // 兜底：若全部被清空，保留默认中英文
            if selectedOCRLanguages.isEmpty {
                selectedOCRLanguages = ["zh-Hans", "en-US"]
                persistOCRLanguages()
            }
        }
    }

    /// 将多选结果写回 AppStorage（逗号分隔）
    private func persistOCRLanguages() {
        if selectedOCRLanguages.isEmpty {
            ocrLanguages = AppSettings.Default.ocrLanguages
        } else {
            // 按 supportedLanguages 的固定顺序输出，避免每次保存顺序抖动
            let ordered = OCRService.supportedLanguages
                .map(\.code)
                .filter { selectedOCRLanguages.contains($0) }
            ocrLanguages = ordered.joined(separator: ",")
        }
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
                    UserDefaults.standard.set(bookmarkData, forKey: AppSettings.Key.defaultSavePathBookmark)
                } catch {
                    // 创建 bookmark 失败时仅保留路径，不影响保存功能
                }
            }
        }
    }
}
