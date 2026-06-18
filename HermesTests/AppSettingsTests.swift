import Foundation
import Testing
@testable import Hermes

@Suite struct AppSettingsTests {
    @Test func defaultThemeIsSystem() {
        #expect(AppSettings.Default.appTheme == "System")
    }

    @Test func defaultOCRLanguages() {
        #expect(AppSettings.Default.ocrLanguages == "zh-Hans,en-US")
    }

    @Test func defaultOCRFallback() {
        #expect(AppSettings.Default.ocrFallbackLanguages == ["zh-Hans", "en-US"])
    }

    @Test func keysAreUnique() {
        let keys = [
            AppSettings.Key.appTheme,
            AppSettings.Key.hideMenuBarIcon,
            AppSettings.Key.launchAtLogin,
            AppSettings.Key.defaultSavePath,
            AppSettings.Key.defaultSavePathBookmark,
            AppSettings.Key.ocrLanguages,
            AppSettings.Key.shortcutCapture,
            AppSettings.Key.shortcutWindow,
            AppSettings.Key.shortcutScreen,
            AppSettings.Key.shortcutOCR,
            AppSettings.Key.shortcutTranslate,
            AppSettings.Key.windowSizeScreenshot,
            AppSettings.Key.selectedJapaneseColor,
        ]
        let uniqueKeys = Set(keys)
        #expect(keys.count == uniqueKeys.count, "All UserDefaults keys must be unique")
    }
}
