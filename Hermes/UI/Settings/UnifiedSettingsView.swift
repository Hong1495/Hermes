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
        .onReceive(NotificationCenter.default.publisher(for: .openAboutFromMenu)) { _ in
            selectedTab = .about
        }
    }
}

// MARK: - General Tab
private struct GeneralSettingsTab: View {
    @AppStorage(AppSettings.Key.launchAtLogin) var launchAtLogin = false
    @AppStorage(AppSettings.Key.hideMenuBarIcon) var hideMenuBarIcon = false
    @AppStorage(AppSettings.Key.autoCheckForUpdates) var autoCheckForUpdates = AppSettings.Default.autoCheckForUpdates
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

                Divider()

                Toggle("启动时自动检查新版本", isOn: $autoCheckForUpdates)
            }

            SettingsCard(title: "在线升级") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("当前版本 v\(UpdateManager.shared.currentVersion) (Build \(UpdateManager.shared.currentBuild))")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text("Hermes 自动对接 GitHub 官方发布通道，随时获取最新优化。")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                    Spacer()
                    Button("检查更新...") {
                        UpdateManager.shared.checkForUpdates(isUserInitiated: true)
                    }
                    .modernStyle(.secondary)
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
    @AppStorage(AppSettings.Key.showScreenshotEditor) var showScreenshotEditor: Bool = AppSettings.Default.showScreenshotEditor

    var body: some View {
        VStack(spacing: Theme.Spacing.medium) {
            SettingsCard(title: "截图工作流") {
                Toggle("截图后弹出图片编辑窗口", isOn: $showScreenshotEditor)
                Text("开启后，截图完成后自动呼出图片标注与编辑工作区；关闭后，截图将自动复制至剪贴板并播放提示音，不打扰当前工作。")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

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
    @ObservedObject private var updateManager = UpdateManager.shared
    @AppStorage(AppSettings.Key.autoCheckForUpdates) var autoCheckForUpdates = AppSettings.Default.autoCheckForUpdates

    var body: some View {
        VStack(spacing: Theme.Spacing.medium) {
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
                            Text("版本 \(updateManager.currentVersion) (Build \(updateManager.currentBuild)) · 深度系统维护与空间分析套件")
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

            // 软件更新卡片
            SettingsCard(title: "软件更新与支持") {
                VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 8) {
                                Text("更新状态")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.Colors.textPrimary)

                                updateStatusBadge
                            }

                            if let lastCheck = updateManager.lastCheckDate {
                                Text("上次检查时间: \(lastCheck.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.Colors.textTertiary)
                            } else {
                                Text("尚未执行更新检查")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.Colors.textTertiary)
                            }
                        }

                        Spacer()

                        Button {
                            updateManager.checkForUpdates(isUserInitiated: true)
                        } label: {
                            HStack(spacing: 6) {
                                if updateManager.status == .checking {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                Text(updateManager.status == .checking ? "正在检查..." : "检查更新")
                            }
                        }
                        .modernStyle(.primary)
                        .disabled(updateManager.status == .checking)
                    }

                    if case .available(let release) = updateManager.status {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("发现新版本: \(release.tagName) (\(release.name))")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Theme.Colors.accent)
                                Spacer()
                                Button("立即下载更新") {
                                    updateManager.downloadUpdate(for: release)
                                }
                                .modernStyle(.primary)

                                Button("查看发行说明") {
                                    updateManager.openReleasePage(for: release)
                                }
                                .modernStyle(.secondary)
                            }

                            if !release.body.isEmpty {
                                Text(release.body)
                                    .font(.caption)
                                    .foregroundStyle(Theme.Colors.textSecondary)
                                    .lineLimit(4)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Theme.Colors.panelBackground.opacity(0.6))
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                        }
                        .padding(Theme.Spacing.medium)
                        .background(Theme.Colors.accent.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Theme.Colors.accent.opacity(0.3), lineWidth: 1)
                        }
                    }

                    Divider()

                    Toggle("启动时在后台自动检测新版本", isOn: $autoCheckForUpdates)
                        .font(.subheadline)
                }
            }
        }
    }

    @ViewBuilder
    private var updateStatusBadge: some View {
        switch updateManager.status {
        case .idle:
            Text("就绪")
                .font(.caption2.weight(.medium))
                .foregroundStyle(Theme.Colors.textTertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.12))
                .clipShape(Capsule())
        case .checking:
            Text("检查中...")
                .font(.caption2.weight(.medium))
                .foregroundStyle(Theme.Colors.accent)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Theme.Colors.accent.opacity(0.15))
                .clipShape(Capsule())
        case .upToDate:
            Text("已是最新版")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Theme.Colors.success)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Theme.Colors.success.opacity(0.15))
                .clipShape(Capsule())
        case .available(let release):
            Text("有新版 \(release.tagName)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Theme.Colors.accent)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Theme.Colors.accent.opacity(0.18))
                .clipShape(Capsule())
        case .failed:
            Text("检查失败")
                .font(.caption2.weight(.medium))
                .foregroundStyle(Theme.Colors.warning)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Theme.Colors.warning.opacity(0.15))
                .clipShape(Capsule())
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
