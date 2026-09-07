import AppKit

/// 集中管理所有 UserDefaults key 和默认值，消除字符串散落。
enum AppSettings {

    // MARK: - UserDefaults Keys

    enum Key {
        static let appTheme = "appTheme"
        static let hideMenuBarIcon = "hideMenuBarIcon"
        static let launchAtLogin = "launchAtLogin"
        static let defaultSavePath = "defaultSavePath"
        static let defaultSavePathBookmark = "defaultSavePathBookmark"
        static let ocrLanguages = "ocrLanguages"
        static let shortcutCapture = "shortcut_capture"
        static let shortcutWindow = "shortcut_window"
        static let shortcutScreen = "shortcut_screen"
        static let shortcutOCR = "shortcut_ocr"
        static let shortcutTranslate = "shortcut_translate"
        static let windowSizeScreenshot = "WindowSize_Screenshot"
        static let selectedJapaneseColor = "SelectedJapaneseColor"
        static let lastSourceLang = "lastSourceLang"
        static let lastTargetLang = "lastTargetLang"
        static let autoTranslateOnPaste = "autoTranslateOnPaste"
        static let showOCRPreview = "showOCRPreview"
        static let showScreenshotEditor = "showScreenshotEditor"
        static let autoCheckForUpdates = "autoCheckForUpdates"
    }

    // MARK: - Default Values

    enum Default {
        static let appTheme = "System"
        static let ocrLanguages = "zh-Hans,en-US"
        static let ocrFallbackLanguages = ["zh-Hans", "en-US"]
        static let autoTranslateOnPaste = true
        static let showOCRPreview = true
        static let showScreenshotEditor = true
        static let autoCheckForUpdates = true
    }

    static func showOCRPreview(in defaults: UserDefaults = .standard) -> Bool {
        if let storedValue = defaults.object(forKey: Key.showOCRPreview) as? Bool {
            return storedValue
        }
        return Default.showOCRPreview
    }

    static func showScreenshotEditor(in defaults: UserDefaults = .standard) -> Bool {
        if let storedValue = defaults.object(forKey: Key.showScreenshotEditor) as? Bool {
            return storedValue
        }
        return Default.showScreenshotEditor
    }

    static func autoTranslateOnPaste(in defaults: UserDefaults = .standard) -> Bool {
        if let storedValue = defaults.object(forKey: Key.autoTranslateOnPaste) as? Bool {
            return storedValue
        }
        return Default.autoTranslateOnPaste
    }

    // MARK: - Appearance

    static func updateAppearance(_ theme: String) {
        let appearance: NSAppearance?
        switch theme {
        case "Light":
            appearance = NSAppearance(named: .aqua)
        case "Dark":
            appearance = NSAppearance(named: .darkAqua)
        default:
            appearance = nil
        }
        NSApp.appearance = appearance
    }
}
