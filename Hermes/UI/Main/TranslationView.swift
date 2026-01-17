import SwiftUI

struct TranslationView: View {
    @ObservedObject var appState = AppState.shared
    @State private var inputText = ""
    @State private var sourceLang = "auto"
    @State private var targetLang = "zh-CN"
    @FocusState private var isInputFocused: Bool
    @AppStorage("autoTranslateMode") var autoTranslateMode = false
    
    var body: some View {
        VStack(spacing: Theme.Spacing.medium) {
            // Header
            HStack {
                Label("翻译", systemImage: "character.book.closed")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                if autoTranslateMode {
                    Text("智能模式")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "E60012").opacity(0.1))
                        .foregroundStyle(Color(hex: "E60012"))
                        .cornerRadius(4)
                }
                
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.medium)
            
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
                    .frame(minHeight: 80)
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
            .padding(.horizontal, Theme.Spacing.medium)
            
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
                        .foregroundStyle(Color(hex: "E60012"))
                        .background(Circle().fill(Color.white).padding(2))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal, Theme.Spacing.medium)
            
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
            .frame(minHeight: 100)
            .background(Theme.Colors.glassBackground)
            .cornerRadius(Theme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(Theme.Colors.glassBorder, lineWidth: 1)
            )
            .padding(.horizontal, Theme.Spacing.medium)
            
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
                .padding(.horizontal, Theme.Spacing.medium)
            }
            
            Spacer(minLength: Theme.Spacing.medium)
        }
        .padding(.vertical, Theme.Spacing.medium)
        .background(TranslationDragView())
        .onAppear {
            isInputFocused = true
        }
    }
    
    private func translate() {
        guard !inputText.isEmpty else { return }
        
        if autoTranslateMode {
            // Check if input contains Chinese characters using Regex
            if inputText.range(of: "\\p{Han}", options: .regularExpression) != nil {
                // If input is Chinese -> Translate to English
                targetLang = "en"
                // Optional: set source to zh-CN explicitly if desired, but auto works
                if sourceLang != "zh-CN" { sourceLang = "auto" }
            } else {
                // If input is not Chinese (English or others) -> Translate to Chinese
                targetLang = "zh-CN"
                if sourceLang != "auto" { sourceLang = "auto" }
            }
        }
        
        appState.isTranslating = true
        TranslationService.shared.translate(text: inputText, source: sourceLang, target: targetLang) { result in
            appState.translatedText = result
            appState.isTranslating = false
        }
    }
}

// MARK: - Private Draggable Helper for Translation
private struct TranslationDragView: NSViewRepresentable {
    func makeNSView(context: Context) -> TranslationDraggableNSView {
        return TranslationDraggableNSView()
    }
    
    func updateNSView(_ nsView: TranslationDraggableNSView, context: Context) {}
}

private class TranslationDraggableNSView: NSView {
    private var initialLocation: NSPoint?
    
    override func mouseDown(with event: NSEvent) {
        // 使用系统原生拖动，彻底消除手动计算导致的抖动
        window?.performDrag(with: event)
    }
    
    // mouseDragged 和 mouseUp 不再需要，由系统接管
}
