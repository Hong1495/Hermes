import Cocoa

/// 管理 NSStatusItem 的创建、图标加载、菜单构建和可见性切换。
final class StatusMenuController {
    private var statusItem: NSStatusItem?

    func setup(target: AnyObject) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            if let image = NSImage(named: "MenuBarIcon") {
                image.size = NSSize(width: 18, height: 18)
                image.isTemplate = true
                button.image = image
            } else {
                let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
                if let symbol = NSImage(systemSymbolName: "shoe.fill", accessibilityDescription: "Hermes")?.withSymbolConfiguration(config) {
                    symbol.isTemplate = true
                    button.image = symbol
                } else {
                    button.title = "H"
                }
            }
        }

        let menu = NSMenu()

        let openItem = NSMenuItem(title: "打开 Hermes", action: #selector(AppDelegate.showApp), keyEquivalent: "")
        openItem.target = target
        menu.addItem(openItem)

        let cleanupItem = NSMenuItem(title: "空间清理", action: #selector(AppDelegate.showCleanup), keyEquivalent: "")
        cleanupItem.target = target
        menu.addItem(cleanupItem)
        menu.addItem(NSMenuItem.separator())

        let captureItem = NSMenuItem(title: "选区截图", action: #selector(AppDelegate.captureArea), keyEquivalent: "x")
        captureItem.keyEquivalentModifierMask = [.command, .shift]
        captureItem.target = target
        menu.addItem(captureItem)

        let windowItem = NSMenuItem(title: "窗口截图", action: #selector(AppDelegate.captureWindow), keyEquivalent: "w")
        windowItem.keyEquivalentModifierMask = [.command, .shift]
        windowItem.target = target
        menu.addItem(windowItem)

        let screenItem = NSMenuItem(title: "全屏截图", action: #selector(AppDelegate.captureScreen), keyEquivalent: "s")
        screenItem.keyEquivalentModifierMask = [.command, .shift]
        screenItem.target = target
        menu.addItem(screenItem)

        let ocrItem = NSMenuItem(title: "OCR 取词", action: #selector(AppDelegate.captureOCR), keyEquivalent: "o")
        ocrItem.keyEquivalentModifierMask = [.command, .shift]
        ocrItem.target = target
        menu.addItem(ocrItem)

        let translationItem = NSMenuItem(title: "翻译", action: #selector(AppDelegate.showTranslation), keyEquivalent: "t")
        translationItem.keyEquivalentModifierMask = [.command, .shift]
        translationItem.target = target
        menu.addItem(translationItem)

        menu.addItem(NSMenuItem.separator())
        let settingsItem = NSMenuItem(title: "设置...", action: #selector(AppDelegate.showSettings), keyEquivalent: ",")
        settingsItem.target = target
        menu.addItem(settingsItem)
        let quitItem = NSMenuItem(title: "退出", action: #selector(AppDelegate.quitApp), keyEquivalent: "q")
        quitItem.target = target
        menu.addItem(quitItem)

        statusItem?.menu = menu
        statusItem?.isVisible = true
        updateVisibility()

        NotificationCenter.default.addObserver(self, selector: #selector(updateVisibility), name: .updateMenuBarState, object: nil)
    }

    @objc func updateVisibility() {
        let shouldHide = UserDefaults.standard.bool(forKey: AppSettings.Key.hideMenuBarIcon)
        statusItem?.isVisible = !shouldHide
        // LSUIElement 应用隐藏状态栏图标后仍需保留可恢复入口：显示 Dock 图标，
        // 点击 Dock 图标时由 AppDelegate 打开设置窗口。
        NSApp.setActivationPolicy(shouldHide ? .regular : .accessory)
    }
}
