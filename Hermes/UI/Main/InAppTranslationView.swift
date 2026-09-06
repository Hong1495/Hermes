import AppKit
import SwiftUI
import Translation

struct InAppTranslationView: View {
    @StateObject private var viewModel = TranslationViewModel(appState: .shared)
    @ObservedObject private var appState = AppState.shared

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.large) {
            // 顶栏标题
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    Text("快速翻译")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("搭载 macOS 原生神经翻译引擎，支持自动语种识别与双向极速翻译。")
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()

                // 快捷键提示
                HStack(spacing: 4) {
                    Image(systemName: "command")
                    Image(systemName: "shift")
                    Text("T 呼出悬浮窗")
                }
                .font(.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.Colors.panelElevated)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

            // 语言控制条
            HStack(spacing: Theme.Spacing.medium) {
                Picker("源语言", selection: $viewModel.sourceLang) {
                    ForEach(viewModel.langOptions(includeAuto: true), id: \.code) { item in
                        Text(item.label).tag(item.code)
                    }
                }
                .frame(width: 140)

                Button {
                    viewModel.swapLanguages()
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.Colors.accent)
                }
                .modernStyle(.secondary)
                .disabled(viewModel.sourceLang == "auto")

                Picker("目标语言", selection: $viewModel.targetLang) {
                    ForEach(viewModel.langOptions(includeAuto: false), id: \.code) { item in
                        Text(item.label).tag(item.code)
                    }
                }
                .frame(width: 140)

                Spacer()

                if appState.isTranslating {
                    ProgressView()
                        .controlSize(.small)
                }

                if !appState.translationInput.isEmpty {
                    Button("清空") {
                        viewModel.clearTranslation()
                    }
                    .modernStyle(.secondary)
                    .controlSize(.small)
                }
            }
            .padding(Theme.Spacing.medium)
            .background(Theme.Colors.panelElevated)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small, style: .continuous))

            // 双栏编辑器
            HStack(spacing: Theme.Spacing.large) {
                // 左侧输入框
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    HStack {
                        Text("原文")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.Colors.textSecondary)
                        Spacer()
                        Text("\(appState.translationInput.count) 字")
                            .font(.caption2)
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }

                    TextEditor(text: $appState.translationInput)
                        .font(.system(size: 14))
                        .scrollContentBackground(.hidden)
                        .padding(Theme.Spacing.small)
                        .background(Theme.Colors.panelElevated)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.small, style: .continuous)
                                .stroke(Theme.Colors.glassBorder, lineWidth: 1)
                        }
                        .onChange(of: appState.translationInput) { _, _ in
                            viewModel.scheduleTranslation()
                        }
                }

                // 右侧译文框
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    HStack {
                        Text("译文")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.Colors.textSecondary)
                        Spacer()
                        if !appState.translatedText.isEmpty {
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(appState.translatedText, forType: .string)
                            } label: {
                                Label("复制译文", systemImage: "doc.on.doc")
                                    .font(.caption)
                            }
                            .modernStyle(.ghost)
                        }
                    }

                    ScrollView {
                        Text(appState.translatedText.isEmpty ? (appState.translationInput.isEmpty ? "译文将在此实时显示…" : (appState.isTranslating ? "翻译中…" : "准备翻译")) : appState.translatedText)
                            .font(.system(size: 14))
                            .foregroundStyle(appState.translatedText.isEmpty ? Theme.Colors.textTertiary : Theme.Colors.textPrimary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .padding(Theme.Spacing.medium)
                    }
                    .background(Theme.Colors.panelElevated)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.small, style: .continuous)
                            .stroke(Theme.Colors.glassBorder, lineWidth: 1)
                    }
                }
            }
            .frame(minHeight: 280)
        }
        .translationTask(viewModel.translationConfig) { session in
            await viewModel.performTranslation(session: session)
        }
    }
}
