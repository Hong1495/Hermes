import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var windowController: FloatingWindowController?
    var mainWindowController: MainWindowController?
    var settingsWindowController: SettingsWindowController?

    private let statusMenuController = StatusMenuController()
    private let shortcutRegistry = ShortcutRegistry()
    private let captureCoordinator = CaptureCoordinator(appState: .shared)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        AppSettings.updateAppearance(
            UserDefaults.standard.string(forKey: AppSettings.Key.appTheme) ?? AppSettings.Default.appTheme
        )

        windowController = FloatingWindowController(appState: .shared)
        mainWindowController = MainWindowController()
        captureCoordinator.windowController = windowController
        setupApplicationMenu()

        statusMenuController.setup(target: self)
        setupToolNotifications()

        // 启动时静默常驻在系统菜单栏与 Dock，主界面仅在用户由菜单或 Dock 触发时呼出
        let shouldAutoCheck = UserDefaults.standard.object(forKey: AppSettings.Key.autoCheckForUpdates) as? Bool ?? AppSettings.Default.autoCheckForUpdates
        if shouldAutoCheck {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                UpdateManager.shared.checkForUpdates(isUserInitiated: false)
            }
        }

        // 窗口关闭通知
        NotificationCenter.default.addObserver(forName: .closeFloatingWindow, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.windowController?.closeWindow()
            }
        }

        // 等应用完成首轮 RunLoop 后注册，避免启动阶段首个 Carbon 事件与窗口初始化竞争。
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.shortcutRegistry.registerAll(with: .init(
                onCaptureArea: { [weak self] in self?.captureCoordinator.capture(mode: .area) },
                onCaptureWindow: { [weak self] in self?.captureCoordinator.capture(mode: .window) },
                onCaptureScreen: { [weak self] in self?.captureCoordinator.capture(mode: .screen) },
                onOCR: { [weak self] in self?.captureCoordinator.ocrCaptureSilent() },
                onTranslate: { [weak self] in self?.captureCoordinator.openTranslationWorkspace() }
            ))
        }
    }

    @objc func showApp() {
        mainWindowController?.showWindow(nil)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showApp()
        return true
    }

    @objc func showCleanup() {
        showApp()
        NotificationCenter.default.post(name: .openCleanupFromMenu, object: nil)
    }

    @objc func checkForUpdates() {
        UpdateManager.shared.checkForUpdates(isUserInitiated: true)
    }

    @objc func showAbout() {
        showApp()
        NotificationCenter.default.post(name: .openAboutFromMenu, object: nil)
    }

    @objc func captureArea() {
        captureCoordinator.capture(mode: .area)
    }

    @objc func captureWindow() {
        captureCoordinator.capture(mode: .window)
    }

    @objc func captureScreen() {
        captureCoordinator.capture(mode: .screen)
    }

    @objc func captureOCR() {
        captureCoordinator.ocrCaptureSilent()
    }

    @objc func showTranslation() {
        captureCoordinator.openTranslationWorkspace()
    }

    @objc func showSettings() {
        showApp()
        NotificationCenter.default.post(name: .openSettingsFromMenu, object: nil)
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    private func setupToolNotifications() {
        NotificationCenter.default.addObserver(forName: .openScreenshotTool, object: nil, queue: .main) { [weak self] _ in
            self?.captureArea()
        }
        NotificationCenter.default.addObserver(forName: .openScreenshotWindowTool, object: nil, queue: .main) { [weak self] _ in
            self?.captureWindow()
        }
        NotificationCenter.default.addObserver(forName: .openScreenshotScreenTool, object: nil, queue: .main) { [weak self] _ in
            self?.captureScreen()
        }
        NotificationCenter.default.addObserver(forName: .openOCRTool, object: nil, queue: .main) { [weak self] _ in
            self?.captureOCR()
        }
        NotificationCenter.default.addObserver(forName: .openTranslationTool, object: nil, queue: .main) { [weak self] _ in
            self?.showTranslation()
        }
        NotificationCenter.default.addObserver(forName: .checkForUpdates, object: nil, queue: .main) { [weak self] _ in
            self?.checkForUpdates()
        }
    }

    private func setupApplicationMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()

        let aboutItem = NSMenuItem(title: "关于 Hermes", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        appMenu.addItem(aboutItem)

        let updateItem = NSMenuItem(title: "检查更新...", action: #selector(checkForUpdates), keyEquivalent: "")
        updateItem.target = self
        appMenu.addItem(updateItem)

        appMenu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "设置...", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出 Hermes", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        appMenu.addItem(quitItem)

        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        NSApp.mainMenu = mainMenu
    }
}
