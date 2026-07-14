import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var windowController: FloatingWindowController?
    var settingsWindowController: SettingsWindowController?

    private let statusMenuController = StatusMenuController()
    private let shortcutRegistry = ShortcutRegistry()
    private let captureCoordinator = CaptureCoordinator(appState: .shared)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AppSettings.updateAppearance(
            UserDefaults.standard.string(forKey: AppSettings.Key.appTheme) ?? AppSettings.Default.appTheme
        )

        windowController = FloatingWindowController(appState: .shared)
        captureCoordinator.windowController = windowController

        statusMenuController.setup(target: self)

        // 窗口关闭通知
        NotificationCenter.default.addObserver(forName: .closeFloatingWindow, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.windowController?.closeWindow()
            }
        }

        // 注册全部快捷键
        shortcutRegistry.registerAll(with: .init(
            onCaptureArea: { [weak self] in self?.captureCoordinator.capture(mode: .area) },
            onCaptureWindow: { [weak self] in self?.captureCoordinator.capture(mode: .window) },
            onCaptureScreen: { [weak self] in self?.captureCoordinator.capture(mode: .screen) },
            onOCR: { [weak self] in self?.captureCoordinator.ocrCaptureSilent() },
            onTranslate: { [weak self] in self?.captureCoordinator.openTranslationWorkspace() }
        ))
    }

    @objc func showApp() {
        windowController?.showWindow()
    }

    @objc func captureArea() {
        captureCoordinator.capture(mode: .area)
    }

    @objc func captureOCR() {
        captureCoordinator.ocrCaptureSilent()
    }

    @objc func showTranslation() {
        captureCoordinator.openTranslationWorkspace()
    }

    @objc func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}
