import AppKit
import ServiceManagement
import SwiftUI

enum SettingsSectionTab: String, CaseIterable, Identifiable {
    case general
    case shortcuts
    case ocr
    case translation
    case whitelist
    case about

    var id: String { rawValue }
    var title: String {
        switch self {
        case .general: "通用"
        case .shortcuts: "快捷键"
        case .ocr: "OCR 取词"
        case .translation: "翻译设置"
        case .whitelist: "清理白名单"
        case .about: "关于"
        }
    }

    var icon: String {
        switch self {
        case .general: "slider.horizontal.3"
        case .shortcuts: "keyboard"
        case .ocr: "text.viewfinder"
        case .translation: "character.book.closed"
        case .whitelist: "shield"
        case .about: "info.circle"
        }
    }
}

struct UnifiedSettingsView: View {
    @State private var selectedTab: SettingsSectionTab = .general
    @ObservedObject private var whitelistManager = WhitelistManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.large) {
            // 顶栏标题
            VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                Text("偏好设置")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("统一配置 Hermes 的系统自启、全局快捷键、OCR 语种、清理排除规则等。")
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            // 专属独立行分段切换器（舒展排布，彻底杜绝换行）
            LiquidGlassSegmentedControl(
                items: SettingsSectionTab.allCases,
                selection: $selectedTab,
                title: \.title,
                icon: \.icon,
                fillsAvailableWidth: true
            )
            .frame(maxWidth: .infinity)
            .padding(.bottom, 2)

            // 分页内容
            VStack(alignment: .leading, spacing: Theme.Spacing.large) {
                switch selectedTab {
                case .general:
                    GeneralSettingsTab()
                case .shortcuts:
                    ShortcutsSettingsTab()
                case .ocr:
                    OCRSettingsTab()
                case .translation:
                    TranslationSettingsTab()
                case .whitelist:
                    WhitelistSettingsTab(manager: whitelistManager)
                case .about:
                    AboutSettingsTab()
                }
            }
        }
    }
}

// MARK: - General Tab
private struct GeneralSettingsTab: View {
    @AppStorage(AppSettings.Key.launchAtLogin) var launchAtLogin = false
    @AppStorage(AppSettings.Key.hideMenuBarIcon) var hideMenuBarIcon = false
    @AppStorage(AppSettings.Key.appTheme) var appTheme: String = AppSettings.Default.appTheme
    @AppStorage(AppSettings.Key.defaultSavePath) var defaultSavePath: String = ""

    var body: some View {
        VStack(spacing: Theme.Spacing.medium) {
            SettingsCard(title: "系统行为") {
                Toggle("开机时自动启动 Hermes", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = !newValue
                        }
                    }

                Divider()

                Toggle("隐藏顶部菜单栏图标", isOn: $hideMenuBarIcon)
                    .onChange(of: hideMenuBarIcon) { _, _ in
                        NotificationCenter.default.post(name: .updateMenuBarState, object: nil)
                    }
            }

            SettingsCard(title: "外观主题") {
                Picker("界面外观", selection: $appTheme) {
                    Text("跟随系统").tag("System")
                    Text("浅色模式").tag("Light")
                    Text("深色模式").tag("Dark")
                }
                .pickerStyle(.menu)
                .onChange(of: appTheme) { _, newValue in
                    AppSettings.updateAppearance(newValue)
                }
            }

            SettingsCard(title: "截图存储") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("默认保存路径")
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text(defaultSavePath.isEmpty ? "桌面 (~/Desktop)" : defaultSavePath)
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.textTertiary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button("更改...") {
                        selectFolder()
                    }
                    .modernStyle(.secondary)
                    if !defaultSavePath.isEmpty {
                        Button("重置") {
                            defaultSavePath = ""
                            UserDefaults.standard.removeObject(forKey: AppSettings.Key.defaultSavePathBookmark)
                        }
                            .modernStyle(.secondary)
                    }
                }
            }
        }
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "选择保存目录"

        if panel.runModal() == .OK, let url = panel.url {
            defaultSavePath = url.path
            if let data = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                UserDefaults.standard.set(data, forKey: AppSettings.Key.defaultSavePathBookmark)
            }
        }
    }
}

// MARK: - Shortcuts Tab
private struct ShortcutsSettingsTab: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.medium) {
            SettingsCard(title: "截图快捷键") {
                ShortcutSettingRow(title: "选区截图", icon: "viewfinder", key: AppSettings.Key.shortcutCapture, defaultShortcut: Shortcut(key: .x, modifiers: [.command, .shift]))
                Divider()
                ShortcutSettingRow(title: "窗口截图", icon: "macwindow.on.rectangle", key: AppSettings.Key.shortcutWindow, defaultShortcut: Shortcut(key: .w, modifiers: [.command, .shift]))
                Divider()
                ShortcutSettingRow(title: "全屏截图", icon: "rectangle.inset.filled", key: AppSettings.Key.shortcutScreen, defaultShortcut: Shortcut(key: .s, modifiers: [.command, .shift]))
            }

            SettingsCard(title: "效率工具快捷键") {
                ShortcutSettingRow(title: "OCR 复制文字", icon: "text.viewfinder", key: AppSettings.Key.shortcutOCR, defaultShortcut: Shortcut(key: .o, modifiers: [.command, .shift]))
                Divider()
                ShortcutSettingRow(title: "翻译浮窗", icon: "character.book.closed", key: AppSettings.Key.shortcutTranslate, defaultShortcut: Shortcut(key: .t, modifiers: [.command, .shift]))
            }
        }
    }
}

private struct ShortcutSettingRow: View {
    let title: String
    let icon: String
    let key: String
    let defaultShortcut: Shortcut

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(Theme.Colors.accent)
                .frame(width: 24)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
            ShortcutRecorder(key: key, defaultShortcut: defaultShortcut)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - OCR Tab
private struct OCRSettingsTab: View {
    @AppStorage(AppSettings.Key.showOCRPreview) var showOCRPreview: Bool = AppSettings.Default.showOCRPreview
    @AppStorage(AppSettings.Key.ocrLanguages) var ocrLanguages: String = AppSettings.Default.ocrLanguages
    @State private var selectedOCRLanguages: Set<String> = []

    var body: some View {
        VStack(spacing: Theme.Spacing.medium) {
            SettingsCard(title: "取词预览") {
                Toggle("取词后显示悬浮预览窗口", isOn: $showOCRPreview)
            }

            SettingsCard(title: "识别语言支持") {
                Text("勾选常用的识别语种，Vision 神经引擎将自动进行多语言混合推断。")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)

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
        }
        .onAppear {
            selectedOCRLanguages = Set(ocrLanguages.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) })
            if selectedOCRLanguages.isEmpty {
                selectedOCRLanguages = ["zh-Hans", "en-US"]
                persistOCRLanguages()
            }
        }
    }

    private func persistOCRLanguages() {
        ocrLanguages = selectedOCRLanguages.joined(separator: ",")
    }
}

// MARK: - Translation Tab
private struct TranslationSettingsTab: View {
    @AppStorage(AppSettings.Key.autoTranslateOnPaste) var autoTranslateOnPaste: Bool = AppSettings.Default.autoTranslateOnPaste

    var body: some View {
        SettingsCard(title: "翻译偏好") {
            Toggle("在翻译窗口中粘贴文本时立即翻译", isOn: $autoTranslateOnPaste)
            Text("启用后，当您向翻译框中粘贴长文本或段落时，无需按回车即可自动触发翻译。")
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }
}

// MARK: - Whitelist Tab
private struct WhitelistSettingsTab: View {
    @ObservedObject var manager: WhitelistManager

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            SettingsCard(title: "安全白名单与排除规则") {
                Text("位于白名单路径内的文件与目录，在系统空间清理与应用扫描时将被完全跳过。")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)

                HStack {
                    Spacer()
                    Button("添加排除目录...") {
                        selectFolder()
                    }
                    .modernStyle(.primary)
                }

                if manager.excludedPaths.isEmpty {
                    Text("当前未添加任何排除路径。")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 4) {
                        ForEach(manager.excludedPaths, id: \.self) { path in
                            HStack {
                                Image(systemName: "folder")
                                    .foregroundStyle(Theme.Colors.accent)
                                Text(path)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                                Button {
                                    manager.removePath(path)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(Theme.Colors.danger)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Theme.Colors.panelBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                    }
                }
            }
        }
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "添加至白名单"

        if panel.runModal() == .OK {
            for url in panel.urls {
                manager.addPath(url.path)
            }
        }
    }
}

// MARK: - About Tab
private struct AboutSettingsTab: View {
    var body: some View {
        SettingsCard(title: "关于 Hermes") {
            VStack(spacing: Theme.Spacing.large) {
                HStack(spacing: Theme.Spacing.large) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
                        .overlay {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("Hermes")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Text("macOS 27 Liquid")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Theme.Colors.accent)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Theme.Colors.accent.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        Text("版本 1.2.0 · 深度系统维护与空间分析套件")
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.textSecondary)
                        Text("深度对标 Mole 性能调优哲学，开箱即用的系统清理、磁盘分析、自愈维护与快捷键浮动工具链。")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                    Spacer()
                }

                Divider()

                // 特性卡片四宫格
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.medium) {
                    FeatureHighlightCard(
                        icon: "sparkles",
                        title: "10+ 维度深度清理",
                        detail: "系统缓存、浏览器、开发产物、包管理器与模型权重，移入废纸篓安全不误删。"
                    )
                    FeatureHighlightCard(
                        icon: "waveform.path.ecg",
                        title: "系统实时状态雷达",
                        detail: "CPU 负载、内存压力与分布、电源健康度及系统运行时间秒级侦测。"
                    )
                    FeatureHighlightCard(
                        icon: "shield.lefthalf.filled",
                        title: "macOS 原生自愈维护",
                        detail: "安全重置 DNS、QuickLook、字体缓存及内存释放，无需第三方常驻守护。"
                    )
                    FeatureHighlightCard(
                        icon: "command",
                        title: "独立快捷键工具链",
                        detail: "⌘⇧X 选区截图 · ⌘⇧W 窗口截图 · ⌘⇧O 离线OCR · ⌘⇧T 神经翻译，随时呼出浮窗。"
                    )
                }
            }
        }
    }
}

private struct FeatureHighlightCard: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.medium) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Theme.Colors.accent)
                .frame(width: 28, height: 28)
                .background(Theme.Colors.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Theme.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.panelBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Theme.Colors.glassBorder.opacity(0.35), lineWidth: 1)
        }
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: Theme.CornerRadius.medium, padding: Theme.Spacing.large)
    }
}
