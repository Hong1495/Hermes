import SwiftUI
import Translation

struct TranslationView: View {
    @ObservedObject private var appState = AppState.shared

    @State private var sourceLang = "auto"
    @State private var targetLang = "zh-CN"
    @State private var pendingTranslationTask: Task<Void, Never>?
    @State private var translationRequestID = UUID()
    @State private var translationConfig: TranslationSession.Configuration?
    @FocusState private var isInputFocused: Bool

    private let languages: [(label: String, code: String)] = [
        ("自动识别", "auto"),
        ("中文", "zh-CN"),
        ("英语", "en"),
        ("日语", "ja"),
        ("韩语", "ko")
    ]

    private func convertToLanguage(_ code: String) -> Locale.Language {
        if code == "zh-CN" {
            return Locale.Language(identifier: "zh_Hans")
        }
        return Locale.Language(identifier: code)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Controls row with language selectors
            controlsRow
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()
                .foregroundStyle(Theme.Colors.separator)

            // Content area
            GeometryReader { geometry in
                let isWideLayout = geometry.size.width >= 800

                if isWideLayout {
                    HStack(spacing: 0) {
                        inputPane
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        Divider()

                        resultPane
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    VStack(spacing: 0) {
                        inputPane
                            .frame(maxHeight: .infinity)

                        Divider()

                        resultPane
                            .frame(maxHeight: .infinity)
                    }
                }
            }

            Divider()
                .foregroundStyle(Theme.Colors.separator)

            // Footer
            footerBar
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .translationTask(translationConfig) { session in
            await performTranslation(session: session)
        }
        .hideScrollIndicators()
        .onAppear {
            focusInputSoon()
        }
        .onChange(of: appState.translationFocusRequestID) { _, _ in
            focusInputSoon()
        }
        .onChange(of: appState.translationInput) { _, _ in
            scheduleTranslation()
        }
        .onChange(of: sourceLang) { _, _ in
            scheduleTranslation(immediate: true)
        }
        .onChange(of: targetLang) { _, _ in
            scheduleTranslation(immediate: true)
        }
        .onDisappear {
            pendingTranslationTask?.cancel()
        }
    }

    private var controlsRow: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.small) {
            languageField(title: "源语言", selection: $sourceLang, includeAuto: true)

            Button(action: swapLanguages) {
                Image(systemName: "arrow.left.arrow.right")
                    .frame(width: 26, height: 26)
            }
            .modernStyle(.icon)
            .disabled(sourceLang == "auto")

            languageField(title: "目标语言", selection: $targetLang, includeAuto: false)

            Spacer(minLength: 8)

            Button(action: {
                scheduleTranslation(immediate: true)
            }) {
                Label("翻译", systemImage: "arrow.right.circle")
            }
            .modernStyle(.primary)
            .disabled(appState.translationInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    // MARK: - Input Pane (no card wrapper, direct content)
    private var inputPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("原文")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                Text("支持粘贴或直接输入")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $appState.translationInput)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.hidden)
                    .hideScrollIndicators()
                    .padding(8)
                    .focused($isInputFocused)

                if appState.translationInput.isEmpty {
                    Text("输入或粘贴文本...")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.Colors.background)
    }

    // MARK: - Result Pane (no card wrapper, direct content)
    private var resultPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("结果")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                if appState.isTranslating {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)

            ScrollView(showsIndicators: false) {
                Group {
                    if let translationError = appState.translationError {
                        Text(translationError)
                            .foregroundStyle(Theme.Colors.danger)
                    } else if appState.translatedText.isEmpty {
                        Text("翻译结果会显示在这里。")
                            .foregroundStyle(Theme.Colors.textTertiary)
                    } else {
                        Text(appState.translatedText)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .textSelection(.enabled)
                            .lineSpacing(5)
                    }
                }
                .font(.system(size: 14, weight: .regular))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(Theme.Colors.panelBackground)
    }

    private var footerBar: some View {
        HStack(spacing: 6) {
            Button(action: pasteFromClipboard) {
                Label("粘贴", systemImage: "doc.on.clipboard")
            }
            .modernStyle(.ghost)

            Button(action: copyTranslatedText) {
                Label("复制结果", systemImage: "doc.on.doc")
            }
            .modernStyle(.secondary)
            .disabled(appState.translatedText.isEmpty)

            Button(action: clearTranslation) {
                Label("清空", systemImage: "xmark")
            }
            .modernStyle(.ghost)

            Spacer()
        }
    }

    private func languageField(title: String, selection: Binding<String>, includeAuto: Bool) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.Colors.textSecondary)

            Picker(title, selection: selection) {
                ForEach(filteredLanguages(includeAuto: includeAuto), id: \.code) { language in
                    Text(language.label).tag(language.code)
                }
            }
            .labelsHidden()
            .frame(width: 100)
        }
    }

    private func filteredLanguages(includeAuto: Bool) -> [(label: String, code: String)] {
        includeAuto ? languages : languages.filter { $0.code != "auto" }
    }

    // MARK: - Translation Logic

    private func resolveLanguages(for text: String) -> (source: Locale.Language, target: Locale.Language, newTargetCode: String?) {
        if #available(macOS 15.0, *) {
            if sourceLang == "auto" {
                let service = TranslationService.shared
                let detected = service.detectLanguage(for: text)

                if service.isChinese(detected) {
                    let newTarget = "en"
                    return (detected, Locale.Language(identifier: "en"), targetLang != newTarget ? newTarget : nil)
                } else {
                    let newTarget = "zh-CN"
                    return (detected, Locale.Language(identifier: "zh_Hans"), targetLang != newTarget ? newTarget : nil)
                }
            }
        }
        return (convertToLanguage(sourceLang), convertToLanguage(targetLang), nil)
    }

    private func scheduleTranslation(immediate: Bool = false) {
        pendingTranslationTask?.cancel()

        let trimmed = appState.translationInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            appState.translatedText = ""
            appState.translationError = nil
            appState.isTranslating = false
            return
        }

        let delay: UInt64 = immediate ? 0 : 450_000_000

        pendingTranslationTask = Task {
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }
            guard !Task.isCancelled else { return }

            await MainActor.run {
                appState.isTranslating = true
                appState.translationError = nil
                triggerTranslation(for: trimmed)
            }
        }
    }

    private func triggerTranslation(for text: String) {
        let (source, target, newTargetCode) = resolveLanguages(for: text)

        if let newCode = newTargetCode {
            withAnimation(.easeInOut(duration: 0.2)) {
                targetLang = newCode
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

    private func performTranslation(session: TranslationSession) async {
        let trimmed = appState.translationInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            await MainActor.run {
                appState.isTranslating = false
            }
            return
        }

        let requestID = translationRequestID

        do {
            if #available(macOS 15.0, *) {
                let result = try await TranslationService.shared.translate(
                    text: trimmed,
                    using: session
                )

                await MainActor.run {
                    guard translationRequestID == requestID else { return }
                    appState.translatedText = result.text
                    appState.translationError = nil
                    appState.isTranslating = false
                }
            } else {
                await MainActor.run {
                    appState.translationError = "原生翻译需要 macOS 15.0 或更高版本。"
                    appState.isTranslating = false
                }
            }
        } catch {
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard translationRequestID == requestID else { return }
                appState.translatedText = ""
                appState.translationError = error.localizedDescription
                appState.isTranslating = false
            }
        }
    }

    private func swapLanguages() {
        guard sourceLang != "auto" else { return }
        let originalSource = sourceLang
        sourceLang = targetLang
        targetLang = originalSource
    }

    private func pasteFromClipboard() {
        if let text = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            appState.translationInput = text
            scheduleTranslation(immediate: true)
        }
    }

    private func focusInputSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isInputFocused = true
        }
    }

    private func copyTranslatedText() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(appState.translatedText, forType: .string)
    }

    private func clearTranslation() {
        pendingTranslationTask?.cancel()
        appState.translationInput = ""
        appState.translatedText = ""
        appState.translationError = nil
        appState.isTranslating = false
        translationConfig = nil
    }
}
