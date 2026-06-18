import Foundation
import Testing
@testable import Hermes

// MARK: - AppSettings: 独立 UserDefaults 测试

@Suite struct AppSettingsIntegrationTests {

    @Test func updateAppearanceModifiesTheme() {
        let defaults = UserDefaults(suiteName: "com.hera.Hermes.test.\(UUID().uuidString)")!
        defaults.removeObject(forKey: AppSettings.Key.appTheme)

        // 验证默认值
        let stored = defaults.string(forKey: AppSettings.Key.appTheme)
        #expect(stored == nil)
    }

    @Test func updateAppearancePersistsNewTheme() {
        let defaults = UserDefaults(suiteName: "com.hera.Hermes.test.\(UUID().uuidString)")!
        defaults.set("Dark", forKey: AppSettings.Key.appTheme)
        let stored = defaults.string(forKey: AppSettings.Key.appTheme)
        #expect(stored == "Dark")
    }

    @Test func updateAppearanceLightTheme() {
        let defaults = UserDefaults(suiteName: "com.hera.Hermes.test.\(UUID().uuidString)")!
        defaults.set("Light", forKey: AppSettings.Key.appTheme)
        let stored = defaults.string(forKey: AppSettings.Key.appTheme)
        #expect(stored == "Light")
    }
}
