import Cocoa

/// 统一管理 5 个全局 Carbon 快捷键的注册与更新。
final class ShortcutRegistry {

    struct Handlers {
        var onCaptureArea: (() -> Void)?
        var onCaptureWindow: (() -> Void)?
        var onCaptureScreen: (() -> Void)?
        var onOCR: (() -> Void)?
        var onTranslate: (() -> Void)?
    }

    private var handlers: Handlers = Handlers()

    func registerAll(with handlers: Handlers) {
        self.handlers = handlers

        // 1. Capture Area (X)
        register(key: AppSettings.Key.shortcutCapture, defaultKey: .x, defaultMods: [.command, .shift], handler: { [weak self] in
            self?.handlers.onCaptureArea?()
        })

        // 2. Capture Window (W)
        register(key: AppSettings.Key.shortcutWindow, defaultKey: .w, defaultMods: [.command, .shift], handler: { [weak self] in
            self?.handlers.onCaptureWindow?()
        })

        // 3. Capture Fullscreen (S)
        register(key: AppSettings.Key.shortcutScreen, defaultKey: .s, defaultMods: [.command, .shift], handler: { [weak self] in
            self?.handlers.onCaptureScreen?()
        })

        // 4. OCR Capture (O)
        register(key: AppSettings.Key.shortcutOCR, defaultKey: .o, defaultMods: [.command, .shift], handler: { [weak self] in
            self?.handlers.onOCR?()
        })

        // 5. Translate (T)
        register(key: AppSettings.Key.shortcutTranslate, defaultKey: .t, defaultMods: [.command, .shift], handler: { [weak self] in
            self?.handlers.onTranslate?()
        })
    }

    private func register(key: String, defaultKey: KeyCode, defaultMods: NSEvent.ModifierFlags, handler: @escaping () -> Void) {
        let defaultShortcut = Shortcut(key: defaultKey, modifiers: defaultMods)

        if let data = UserDefaults.standard.data(forKey: key),
           let shortcut = try? JSONDecoder().decode(Shortcut.self, from: data) {
            if shortcut.isSystemScreenshotShortcut || !shortcut.hasGlobalModifier {
                if let encoded = try? JSONEncoder().encode(defaultShortcut) {
                    UserDefaults.standard.set(encoded, forKey: key)
                }
                HotKeyManager.shared.register(key: key, shortcut: defaultShortcut, handler: handler)
            } else {
                HotKeyManager.shared.register(key: key, shortcut: shortcut, handler: handler)
            }
        } else {
            HotKeyManager.shared.register(key: key, shortcut: defaultShortcut, handler: handler)
        }
    }
}
