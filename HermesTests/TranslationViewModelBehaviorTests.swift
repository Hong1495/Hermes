import Foundation
import Testing
import Translation
@testable import Hermes

// MARK: - TranslationViewModel: 真实行为测试

@MainActor
@Suite struct TranslationViewModelBehaviorTests {

    private func makeVM() -> (TranslationViewModel, AppState) {
        UserDefaults.standard.removeObject(forKey: AppSettings.Key.lastSourceLang)
        UserDefaults.standard.removeObject(forKey: AppSettings.Key.lastTargetLang)
        let appState = AppState()
        return (TranslationViewModel(appState: appState), appState)
    }

    private func makeVMWithContent() -> (TranslationViewModel, AppState) {
        UserDefaults.standard.removeObject(forKey: AppSettings.Key.lastSourceLang)
        UserDefaults.standard.removeObject(forKey: AppSettings.Key.lastTargetLang)
        let appState = AppState()
        appState.translationInput = "hello"
        return (TranslationViewModel(appState: appState), appState)
    }

    // MARK: - 防抖取消

    @Test func scheduleThenCancelBeforeFireDoesNotSetIsTranslating() async {
        let (vm, appState) = makeVMWithContent()
        vm.scheduleTranslation(immediate: false)
        // 立即取消：pendingTranslationTask 未 trigger 前就取消
        vm.scheduleTranslation(immediate: false)
        // 防抖 debounce 450ms，等待一下让 task 有机会跑
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(appState.isTranslating == false)
    }

    @Test func immediateTranslationSetsIsTranslating() async {
        let (vm, appState) = makeVMWithContent()
        vm.scheduleTranslation(immediate: true)
        try? await Task.sleep(nanoseconds: 10_000_000)
        #expect(appState.isTranslating == true)
    }

    @Test func multipleRapidCallsDoNotDuplicate() async {
        let (vm, appState) = makeVMWithContent()
        // 连续触发三次 immediate
        vm.scheduleTranslation(immediate: true)
        vm.scheduleTranslation(immediate: true)
        vm.scheduleTranslation(immediate: true)
        try? await Task.sleep(nanoseconds: 20_000_000)
        // isTranslating 应该为 true（最后一次触发生效）
        #expect(appState.isTranslating == true)
    }

    // MARK: - 空输入清理

    @Test func setInputThenClearResetsAllState() async {
        let (vm, appState) = makeVMWithContent()
        // 先触发翻译
        vm.scheduleTranslation(immediate: true)
        try? await Task.sleep(nanoseconds: 10_000_000)

        // 清空输入
        appState.translationInput = ""
        vm.scheduleTranslation(immediate: true)
        try? await Task.sleep(nanoseconds: 10_000_000)

        #expect(appState.isTranslating == false)
        #expect(appState.translatedText == "")
        #expect(appState.translationError == nil)
    }

    // MARK: - 语言解析策略

    @Test func autoDetectChineseDefaultsToTargetEnglish() {
        let (vm, _) = makeVM()
        let result = vm.resolveLanguages(for: "你好世界")
        // 中文检测到 → 自动目标 = en
        #expect(result.suggestedTargetCode == "en")
        #expect(result.target.languageCode?.identifier == "en")
    }

    @Test func autoDetectNonChineseDefaultsToTargetZhCN() {
        let (vm, _) = makeVM()
        let result = vm.resolveLanguages(for: "Hello, world")
        // 非中文检测到 → 自动目标 = zh-CN
        #expect(result.suggestedTargetCode == "zh-CN")
        #expect(result.target.languageCode?.identifier == "zh")
    }

    @Test func manualTargetPreservesSelectedLanguage() {
        let (vm, _) = makeVM()
        vm.onTargetLangChanged() // 设置为手动模式
        vm.targetLang = "ja"

        let result = vm.resolveLanguages(for: "Hello")
        // 手动选择了日语后，自动检测不应覆盖
        #expect(result.suggestedTargetCode == nil)
        #expect(vm.targetLang == "ja")
    }

    @Test func explicitSourceLangSkipsAutoDetection() {
        let (vm, _) = makeVM()
        vm.sourceLang = "zh-CN"
        vm.targetLang = "en"

        let result = vm.resolveLanguages(for: "任意文本")
        #expect(result.suggestedTargetCode == nil)
        #expect(result.source.languageCode?.identifier == "zh")
        #expect(result.target.languageCode?.identifier == "en")
    }

    @Test func supportedLanguagePairCanPrepareTranslation() {
        #expect(TranslationViewModel.canPrepareTranslation(with: .installed))
        #expect(TranslationViewModel.canPrepareTranslation(with: .supported))
        #expect(!TranslationViewModel.canPrepareTranslation(with: .unsupported))
    }
}
