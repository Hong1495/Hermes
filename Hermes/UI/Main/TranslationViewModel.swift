import SwiftUI
import Combine
import Translation

/// TranslationView 的业务逻辑层，管理语言选择、防抖、语言包检查与翻译 session。
@MainActor
final class TranslationViewModel: ObservableObject {
    private let appState: AppState

    @Published var sourceLang = "auto"
    @Published var targetLang = "zh-CN"
    @Published var translationConfig: TranslationSession.Configuration?
    private var pendingTranslationTask: Task<Void, Never>?
    private(set) var translationRequestID = UUID()
    private(set) var targetSelectionWasManual = false
    private var isApplyingAutomaticTargetSelection = false

    let languages: [(label: String, code: String)] = [
        ("自动识别", "auto"),
        ("中文", "zh-CN"),
        ("英语", "en"),
        ("日语", "ja"),
        ("韩语", "ko")
    ]

    init(appState: AppState) {
        self.appState = appState
        sourceLang = UserDefaults.standard.string(forKey: AppSettings.Key.lastSourceLang) ?? "auto"
        targetLang = UserDefaults.standard.string(forKey: AppSettings.Key.lastTargetLang) ?? "zh-CN"
        if sourceLang != "auto" {
            targetSelectionWasManual = true
        }
    }

    var autoTranslateOnPaste: Bool {
        UserDefaults.standard.bool(forKey: AppSettings.Key.autoTranslateOnPaste)
    }

    func langOptions(includeAuto: Bool) -> [(label: String, code: String)] {
        includeAuto ? languages : languages.filter { $0.code != "auto" }
    }

    func convertToLanguage(_ code: String) -> Locale.Language {
        if code == "zh-CN" {
            return Locale.Language(identifier: "zh_Hans")
        }
        return Locale.Language(identifier: code)
    }

    // MARK: - Language Resolution

    func resolveLanguages(for text: String) -> (source: Locale.Language, target: Locale.Language, suggestedTargetCode: String?) {
        if sourceLang == "auto" {
            let service = TranslationService.shared
            let detected = service.detectLanguage(for: text)

            if service.isChinese(detected) {
                let automaticTarget = targetSelectionWasManual ? targetLang : "en"
                return (detected, convertToLanguage(automaticTarget), targetSelectionWasManual ? nil : automaticTarget)
            } else {
                let automaticTarget = targetSelectionWasManual ? targetLang : "zh-CN"
                return (detected, convertToLanguage(automaticTarget), targetSelectionWasManual ? nil : automaticTarget)
            }
        }
        return (convertToLanguage(sourceLang), convertToLanguage(targetLang), nil)
    }

    // MARK: - Debounced Translation

    func scheduleTranslation(immediate: Bool = false) {
        pendingTranslationTask?.cancel()

        let trimmed = appState.translationInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            translationRequestID = UUID()
            appState.translatedText = ""
            appState.translationError = nil
            appState.isTranslating = false
            return
        }

        translationRequestID = UUID()

        let delay: UInt64 = immediate ? 0 : 450_000_000

        pendingTranslationTask = Task { [weak self] in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }
            guard let self, !Task.isCancelled else { return }

            appState.isTranslating = true
            appState.translationError = nil
            triggerTranslation(for: trimmed, requestID: translationRequestID)
        }
    }

    // MARK: - Translation Trigger

    private func triggerTranslation(for text: String, requestID: UUID) {
        let (source, target, suggestedTargetCode) = resolveLanguages(for: text)

        Task { [weak self] in
            let status = await LanguageAvailability().status(from: source, to: target)
            guard let self, self.translationRequestID == requestID else { return }
            guard status == .installed else {
                appState.translatedText = ""
                appState.translationError = "未安装「\(source.languageCode?.identifier ?? "?") → \(target.languageCode?.identifier ?? "?")」翻译语言包，请在系统设置 → 通用 → 翻译与实时翻译中下载。"
                appState.isTranslating = false
                return
            }

            await MainActor.run { [weak self] in
                guard let self, self.translationRequestID == requestID else { return }
                self.applyTranslationConfig(source: source, target: target, suggestedTargetCode: suggestedTargetCode)
            }
        }
    }

    private func applyTranslationConfig(source: Locale.Language, target: Locale.Language, suggestedTargetCode: String?) {
        if let suggestedTargetCode,
           suggestedTargetCode != targetLang {
            isApplyingAutomaticTargetSelection = true
            withAnimation(.easeInOut(duration: 0.2)) {
                targetLang = suggestedTargetCode
            }
            DispatchQueue.main.async {
                self.isApplyingAutomaticTargetSelection = false
            }
            return
        }

        if let existing = translationConfig,
           existing.source == source,
           existing.target == target {
            translationConfig?.invalidate()
        } else {
            translationConfig = .init(source: source, target: target)
        }
    }

    // MARK: - Perform Translation

    func performTranslation(session: TranslationSession) async {
        let trimmed = appState.translationInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            appState.isTranslating = false
            return
        }

        let requestID = translationRequestID

        do {
            let result = try await TranslationService.shared.translate(
                text: trimmed,
                using: session
            )

            guard translationRequestID == requestID else { return }
            appState.translatedText = result.text
            appState.translationError = nil
            appState.isTranslating = false
        } catch {
            guard !Task.isCancelled else { return }

            guard translationRequestID == requestID else { return }
            appState.translatedText = ""
            appState.translationError = error.localizedDescription
            appState.isTranslating = false
        }
    }

    // MARK: - Actions

    func swapLanguages() {
        guard sourceLang != "auto" else { return }
        let originalSource = sourceLang
        sourceLang = targetLang
        targetLang = originalSource
        targetSelectionWasManual = true
        persistLanguagePair()
    }

    func pasteFromClipboard() {
        if let text = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            appState.translationInput = text
            if autoTranslateOnPaste {
                scheduleTranslation(immediate: true)
            }
        }
    }

    func copyTranslatedText() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(appState.translatedText, forType: .string)
    }

    func clearTranslation() {
        pendingTranslationTask?.cancel()
        appState.translationInput = ""
        appState.translatedText = ""
        appState.translationError = nil
        appState.isTranslating = false
        translationConfig = nil
        sourceLang = "auto"
        targetLang = "zh-CN"
        targetSelectionWasManual = false
        persistLanguagePair()
    }

    func onSourceLangChanged() {
        targetSelectionWasManual = false
        persistLanguagePair()
        scheduleTranslation(immediate: true)
    }

    func onTargetLangChanged() {
        if !isApplyingAutomaticTargetSelection {
            targetSelectionWasManual = true
        }
        persistLanguagePair()
        scheduleTranslation(immediate: true)
    }

    func onDisappear() {
        pendingTranslationTask?.cancel()
        persistLanguagePair()
    }

    private func persistLanguagePair() {
        UserDefaults.standard.set(sourceLang, forKey: AppSettings.Key.lastSourceLang)
        UserDefaults.standard.set(targetLang, forKey: AppSettings.Key.lastTargetLang)
    }
}
