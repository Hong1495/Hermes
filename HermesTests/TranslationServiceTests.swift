import Foundation
import Testing
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
}
