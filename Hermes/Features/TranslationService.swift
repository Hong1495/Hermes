import Foundation
import Translation
import NaturalLanguage

@available(macOS 15.0, *)
final class TranslationService {
    static let shared = TranslationService()

    private init() {}

    struct TranslationResult {
        let text: String
        let detectedSourceLanguage: Locale.Language?
    }

    enum ServiceError: LocalizedError {
        case translationFailed(String)
        case emptyResult
        case unsupportedLanguagePair

        var errorDescription: String? {
            switch self {
            case .translationFailed(let message):
                return "翻译失败：\(message)"
            case .emptyResult:
                return "未返回可用的翻译结果。"
            case .unsupportedLanguagePair:
                return "不支持的语言对，请在「系统设置 → 通用 → 翻译与实时翻译」中下载对应语言包。"
            }
        }
    }

    // MARK: - Language Detection

    /// 使用 NaturalLanguage 框架检测输入文本的语言
    func detectLanguage(for text: String) -> Locale.Language {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        if let dominant = recognizer.dominantLanguage {
            return Locale.Language(identifier: dominant.rawValue)
        }

        // Fallback: 检查是否包含 CJK 字符（中文）
        let cjkRange = text.rangeOfCharacter(from: CharacterSet(charactersIn: "\u{4E00}"..."\u{9FFF}"))
        if cjkRange != nil {
            return Locale.Language(identifier: "zh_Hans")
        }

        return Locale.Language(identifier: "en")
    }

    /// 判断给定语言是否为中文
    func isChinese(_ language: Locale.Language) -> Bool {
        let code = language.languageCode?.identifier.lowercased() ?? ""
        return code.hasPrefix("zh") || code.hasPrefix("chi")
    }

    // MARK: - Translation

    /// 使用 SwiftUI .translationTask 注入的 session 进行翻译
    func translate(text: String, using session: TranslationSession) async throws -> TranslationResult {
        let response = try await session.translate(text)

        let translated = response.targetText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !translated.isEmpty else {
            throw ServiceError.emptyResult
        }

        return TranslationResult(
            text: translated,
            detectedSourceLanguage: response.sourceLanguage
        )
    }
}
