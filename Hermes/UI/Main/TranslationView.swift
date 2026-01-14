import SwiftUI

struct TranslationView: View {
    @ObservedObject var appState = AppState.shared
    @State private var inputText = ""
    @State private var sourceLang = "auto"
    @State private var targetLang = "zh-CN"
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("翻译", systemImage: "character.book.closed")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.large)
            .padding(.top, Theme.Spacing.medium)
            .padding(.bottom, Theme.Spacing.small)
            
            // Input Area
            ZStack(alignment: .topLeading) {
                if inputText.isEmpty {
                    Text("输入或粘贴文本...")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(Theme.Spacing.medium)
                }
                
                TextEditor(text: $inputText)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 60, maxHeight: .infinity)
                    .padding(Theme.Spacing.small)
                    .focused($isInputFocused)
                    .onChange(of: inputText) { _, newValue in
                        // Debounce auto-translate
                        Task {
                            try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s debounce
                            if newValue == inputText && !newValue.isEmpty {
                                translate()
                            }
                        }
                    }
            }
            .background(Theme.Colors.glassInputBackground)
            .cornerRadius(Theme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(Theme.Colors.glassBorder, lineWidth: 1)
            )
            .padding(.horizontal, Theme.Spacing.large)
            
            // Language Selection & Action
            HStack {
                // Settings
                HStack(spacing: 8) {
                    Picker("", selection: $sourceLang) {
                        Text("自动检测").tag("auto")
                        Text("中文").tag("zh-CN")
                        Text("英语").tag("en")
                        Text("日语").tag("ja")
                        Text("韩语").tag("ko")
                    }
                    .labelsHidden()
                    .frame(width: 80)
                    
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    
                    Picker("", selection: $targetLang) {
                        Text("中文").tag("zh-CN")
                        Text("英语").tag("en")
                        Text("日语").tag("ja")
                        Text("韩语").tag("ko")
                    }
                    .labelsHidden()
                    .frame(width: 80)
                }
                
                Spacer()
                
                Button(action: {
                    translate()
                }) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Theme.Colors.accent)
                        .background(Circle().fill(Color.white).padding(2))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal, Theme.Spacing.large)
            .padding(.vertical, Theme.Spacing.small)
            
            Divider()
                .foregroundStyle(Theme.Colors.separator)
                .padding(.horizontal, Theme.Spacing.large)
            
            // Output Area
            ScrollView {
                if appState.isTranslating {
                    HStack {
                        Spacer()
                        ProgressView()
                            .controlSize(.small)
                        Spacer()
                    }
                    .padding()
                } else {
                    Text(appState.translatedText.isEmpty ? "翻译结果..." : appState.translatedText)
                        .font(.body)
                        .foregroundStyle(appState.translatedText.isEmpty ? .tertiary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Theme.Spacing.medium)
                        .textSelection(.enabled)
                }
            }
            .frame(minHeight: 60, maxHeight: .infinity)
            .background(Theme.Colors.glassBackground)
            .cornerRadius(Theme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(Theme.Colors.glassBorder, lineWidth: 1)
            )
            .padding(.horizontal, Theme.Spacing.large)
            .padding(.bottom, Theme.Spacing.large)
            
            // Footer Actions
            if !appState.translatedText.isEmpty {
                HStack {
                    Spacer()
                    Button(action: {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(appState.translatedText, forType: .string)
                    }) {
                        Label("复制结果", systemImage: "doc.on.doc")
                    }
                    .modernStyle(.ghost)
                }
                .padding(.horizontal, Theme.Spacing.large)
                .padding(.bottom, Theme.Spacing.medium)
            }
        }
        .onAppear {
            isInputFocused = true
        }
    }
    
    private func translate() {
        guard !inputText.isEmpty else { return }
        appState.isTranslating = true
        TranslationService.shared.translate(text: inputText, source: sourceLang, target: targetLang) { result in
            appState.translatedText = result
            appState.isTranslating = false
        }
    }
}
