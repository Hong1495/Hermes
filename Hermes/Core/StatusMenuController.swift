import Cocoa

/// 管理 NSStatusItem 的创建、图标加载、菜单构建和可见性切换。
final class StatusMenuController {
    private var statusItem: NSStatusItem?

    func setup(target: AnyObject) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            if let image = NSImage(named: "MenuBarIcon") {
                image.size = NSSize(width: 16, height: 16)
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
        let settingsItem = NSMenuItem(title: "设置...", action: #selector(AppDelegate.showSettings), keyEquivalent: ",")
        settingsItem.target = target
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem.separator())
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
    }
}
