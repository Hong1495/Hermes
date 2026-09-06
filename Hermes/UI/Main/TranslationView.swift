import SwiftUI
import Translation

struct TranslationView: View {
    @ObservedObject private var appState: AppState
    @StateObject private var viewModel: TranslationViewModel
    @FocusState private var isInputFocused: Bool

    private let editorHorizontalInset: CGFloat = 12
    private let editorVerticalInset: CGFloat = 10

    init(appState: AppState) {
        self.appState = appState
        self._viewModel = StateObject(wrappedValue: TranslationViewModel(appState: appState))
    }

    var body: some View {
        VStack(spacing: 0) {
            controlsRow
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()
                .foregroundStyle(Theme.Colors.separator)

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

            footerBar
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .translationTask(viewModel.translationConfig) { session in
            await viewModel.performTranslation(session: session)
        }
        .hideScrollIndicators()
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isInputFocused = true
            }
        }
        .onChange(of: appState.translationFocusRequestID) { _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isInputFocused = true
            }
        }
        .onChange(of: appState.translationInput) { _, _ in
            viewModel.scheduleTranslation()
        }
        .onChange(of: viewModel.sourceLang) { _, _ in
            viewModel.onSourceLangChanged()
        }
        .onChange(of: viewModel.targetLang) { _, _ in
            viewModel.onTargetLangChanged()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
    }

    // MARK: - Controls Row

    private var controlsRow: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.small) {
            languageField(title: "源语言", selection: $viewModel.sourceLang, includeAuto: true)

            Button(action: { viewModel.swapLanguages() }) {
                Image(systemName: "arrow.left.arrow.right")
                    .frame(width: 26, height: 26)
            }
            .modernStyle(.icon)
            .disabled(viewModel.sourceLang == "auto")

            languageField(title: "目标语言", selection: $viewModel.targetLang, includeAuto: false)
                .disabled(viewModel.sourceLang == "auto")

            Spacer(minLength: 8)

            Button(action: {
                viewModel.scheduleTranslation(immediate: true)
            }) {
                Label("翻译", systemImage: "arrow.right.circle")
            }
            .modernStyle(.primary)
            .disabled(appState.translationInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    // MARK: - Input Pane

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
                AlignedTextEditor(
                    text: $appState.translationInput,
                    isFocused: isInputFocused,
                    font: .systemFont(ofSize: 14, weight: .regular),
                    textColor: NSColor(Theme.Colors.textPrimary),
                    contentInset: NSSize(width: editorHorizontalInset, height: editorVerticalInset)
                )
                .hideScrollIndicators()
                    .focused($isInputFocused)

                if appState.translationInput.isEmpty {
                    Text("输入或粘贴文本...")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .padding(.leading, editorHorizontalInset)
                        .padding(.top, editorVerticalInset)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(.ultraThinMaterial)
        .glassEffect(.regular, in: Rectangle())
    }

    // MARK: - Result Pane

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
                .padding(.horizontal, editorHorizontalInset)
                .padding(.top, editorVerticalInset)
                .padding(.bottom, editorVerticalInset)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(.ultraThinMaterial)
        .glassEffect(.regular, in: Rectangle())
    }

    // MARK: - Footer Bar

    private var footerBar: some View {
        HStack(spacing: 6) {
            Button(action: { viewModel.pasteFromClipboard() }) {
                Label("粘贴", systemImage: "doc.on.clipboard")
            }
            .modernStyle(.ghost)

            Button(action: { viewModel.copyTranslatedText() }) {
                Label("复制结果", systemImage: "doc.on.doc")
            }
            .modernStyle(.secondary)
            .disabled(appState.translatedText.isEmpty)

            Button(action: { viewModel.clearTranslation() }) {
                Label("清空", systemImage: "xmark")
            }
            .modernStyle(.ghost)

            Spacer()

            Toggle("粘贴后自动翻译", isOn: .init(
                get: { viewModel.autoTranslateOnPaste },
                set: { UserDefaults.standard.set($0, forKey: AppSettings.Key.autoTranslateOnPaste) }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
            .font(.system(size: 11))
        }
    }

    // MARK: - Helpers

    private func languageField(title: String, selection: Binding<String>, includeAuto: Bool) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.Colors.textSecondary)

            Picker(title, selection: selection) {
                ForEach(viewModel.langOptions(includeAuto: includeAuto), id: \.code) { language in
                    Text(language.label).tag(language.code)
                }
            }
            .labelsHidden()
            .frame(width: 100)
        }
    }
}

#if DEBUG
#Preview("Translation — Empty") {
    TranslationView(appState: AppState())
        .frame(width: 820, height: 640)
}

#Preview("Translation — With Input") {
    let appState = AppState()
    appState.prepareForTranslationWorkspace()
    appState.translationInput = "こんにちは世界"
    appState.translatedText = "Hello, world"
    return TranslationView(appState: appState)
        .frame(width: 820, height: 640)
}
#endif
