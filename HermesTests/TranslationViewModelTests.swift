import Foundation
import Testing
@testable import Hermes

/// TranslationViewModel 单元测试 — 使用注入的独立 AppState，不依赖全局单例。
@MainActor
@Suite struct TranslationViewModelTests {

    private func makeViewModel() -> TranslationViewModel {
        // 清除 UserDefaults，避免语言记忆泄漏影响测试
        UserDefaults.standard.removeObject(forKey: AppSettings.Key.lastSourceLang)
        UserDefaults.standard.removeObject(forKey: AppSettings.Key.lastTargetLang)
        return TranslationViewModel(appState: AppState())
    }

    private func makeViewModelWithContent() -> (TranslationViewModel, AppState) {
        let appState = AppState()
        appState.translationInput = "hello"
        UserDefaults.standard.removeObject(forKey: AppSettings.Key.lastSourceLang)
        UserDefaults.standard.removeObject(forKey: AppSettings.Key.lastTargetLang)
        return (TranslationViewModel(appState: appState), appState)
    }

    // MARK: - Initial State

    @Test func autoDetectModeDefaults() {
        let vm = makeViewModel()
        #expect(vm.sourceLang == "auto")
        #expect(vm.targetLang == "zh-CN")
    }

    @Test func targetSelectionWasManualIsFalseByDefault() {
        let vm = makeViewModel()
        #expect(vm.targetSelectionWasManual == false)
    }

    // MARK: - Language Resolution Strategy

    @Test func onSourceLangChangedResetsManualTarget() {
        let vm = makeViewModel()
        vm.onTargetLangChanged()
        #expect(vm.targetSelectionWasManual == true)

        vm.onSourceLangChanged()
        #expect(vm.targetSelectionWasManual == false)
    }

    @Test func swapLanguagesExchangesCorrectly() {
        let vm = makeViewModel()
        vm.sourceLang = "zh-CN"
        vm.targetLang = "en"
        vm.swapLanguages()
        #expect(vm.sourceLang == "en")
        #expect(vm.targetLang == "zh-CN")
        #expect(vm.targetSelectionWasManual == true)
    }

    @Test func swapLanguagesNoopInAutoMode() {
        let vm = makeViewModel()
        vm.targetLang = "en"
        vm.swapLanguages()
        #expect(vm.sourceLang == "auto")
        #expect(vm.targetLang == "en")
    }

    // MARK: - Code Conversion

    @Test func convertChineseHans() {
        let vm = makeViewModel()
        let lang = vm.convertToLanguage("zh-CN")
        #expect(lang.languageCode?.identifier == "zh")
    }

    @Test func convertEnglish() {
        let vm = makeViewModel()
        let lang = vm.convertToLanguage("en")
        #expect(lang.languageCode?.identifier == "en")
    }

    // MARK: - Clear / Reset

    @Test func clearResetsToDefaults() {
        let vm = makeViewModel()
        vm.sourceLang = "en"
        vm.targetLang = "ja"
        vm.clearTranslation()
        #expect(vm.sourceLang == "auto")
        #expect(vm.targetLang == "zh-CN")
        #expect(vm.translationConfig == nil)
    }

    @Test func clearResetsManualFlag() {
        let vm = makeViewModel()
        vm.onTargetLangChanged()
        #expect(vm.targetSelectionWasManual == true)
        vm.clearTranslation()
        #expect(vm.targetSelectionWasManual == false)
    }

    // MARK: - Schedule / Debounce

    @Test func scheduleTranslationUpdatesRequestIDWithContent() {
        let (vm, _) = makeViewModelWithContent()
        let oldID = vm.translationRequestID
        vm.scheduleTranslation(immediate: true)
        #expect(vm.translationRequestID != oldID)
    }

    @Test func emptyInputDoesNotTriggerIsTranslating() {
        let appState = AppState()
        appState.translationInput = ""
        let vm = TranslationViewModel(appState: appState)
        vm.scheduleTranslation(immediate: true)
        #expect(appState.isTranslating == false)
        #expect(appState.translatedText == "")
        #expect(appState.translationError == nil)
    }

    // MARK: - Lang Options

    @Test func langOptionsFiltersAutoCorrectly() {
        let vm = makeViewModel()
        #expect(vm.langOptions(includeAuto: true).count == 5)
        #expect(vm.langOptions(includeAuto: false).count == 4)
        #expect(vm.langOptions(includeAuto: false).allSatisfy { $0.code != "auto" })
    }
}
