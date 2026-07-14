import Foundation
import Testing
import Translation
@testable import Hermes

@Suite struct TranslationServiceTests {
    @Test func isChineseIdentifiesChineseCorrectly() {
        let service = TranslationService.shared

        let zhHans = Locale.Language(identifier: "zh_Hans")
        #expect(service.isChinese(zhHans))

        let zhHant = Locale.Language(identifier: "zh_Hant")
        #expect(service.isChinese(zhHant))

        let en = Locale.Language(identifier: "en")
        #expect(!service.isChinese(en))

        let ja = Locale.Language(identifier: "ja")
        #expect(!service.isChinese(ja))
    }

    @Test func detectLanguageFallsBackForEmptyText() {
        let service = TranslationService.shared
        let detected = service.detectLanguage(for: "")
        // Empty text should fall back to English
        #expect(detected.languageCode?.identifier == "en")
    }

    @Test func detectsChineseAndEnglishForAutomaticTranslation() {
        let service = TranslationService.shared
        #expect(service.isChinese(service.detectLanguage(for: "今天天气很好")))
        #expect(service.detectLanguage(for: "The weather is good today").languageCode?.identifier == "en")
    }

    @Test func translatesInstalledEnglishAndChinesePairs() async throws {
        let service = TranslationService.shared

        let englishSession = TranslationSession(
            installedSource: Locale.Language(identifier: "en"),
            target: Locale.Language(identifier: "zh_Hans")
        )
        let chinese = try await service.translate(text: "Good morning", using: englishSession)
        #expect(!chinese.text.isEmpty)
        #expect(chinese.text != "Good morning")

        let chineseSession = TranslationSession(
            installedSource: Locale.Language(identifier: "zh_Hans"),
            target: Locale.Language(identifier: "en")
        )
        let english = try await service.translate(text: "今天天气很好", using: chineseSession)
        #expect(!english.text.isEmpty)
        #expect(english.text != "今天天气很好")
    }
}
