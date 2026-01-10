//
//  WriterView.swift
//  Hermes
//
//  Created by Hermes AI Assistant.
//

import SwiftUI

struct WriterView: View {
    @Bindable var item: HermesItem
    @State private var isAIProcessing: Bool = false
    @State private var aiPrompt: String = ""
    @State private var showPromptBar: Bool = false
    
    private let quickActions = ["Fix Grammar", "Make Professional", "Summarize", "Continue Writing"]
    
    var body: some View {
        VStack(spacing: 0) {
            TextField("Untitled Draft", text: $item.title)
                .font(.title2.weight(.bold))
                .textFieldStyle(.plain)
                .padding(.horizontal)
                .padding(.vertical, 12)
            
            Divider()
            
            TextEditor(text: $item.content)
                .font(.system(.body, design: .serif))
                .lineSpacing(6)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            if showPromptBar {
                aiCommandBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Color(NSColor.textBackgroundColor))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showPromptBar.toggle()
                    }
                }) {
                    Label("AI Assistant", systemImage: "sparkles")
                        .symbolEffect(.pulse, isActive: isAIProcessing)
                }
                .keyboardShortcut("k", modifiers: .command)
            }
        }
    }
    
    var aiCommandBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                TextField("Ask AI to edit...", text: $aiPrompt)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        performAIAction(prompt: aiPrompt)
                    }
                if isAIProcessing {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.regularMaterial)
                    .stroke(.tertiary, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quickActions, id: \.self) { action in
                        Button(action: { performAIAction(prompt: action) }) {
                            Text(action)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(.ultraThinMaterial))
                                .overlay(Capsule().stroke(.quaternary, lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    private func performAIAction(prompt: String) {
        guard !prompt.isEmpty else { return }
        isAIProcessing = true
        
        Task {
            let context = item.content.isEmpty ? "(No content yet)" : item.content
            let fullPrompt = """
            You are a professional writing assistant.
            CONTEXT:
            \(context)
            INSTRUCTION:
            \(prompt)
            OUTPUT:
            Provide ONLY the rewritten or generated text. Do not explain.
            """
            
            do {
                let result = try await AIService.shared.generateText(prompt: fullPrompt)
                
                await MainActor.run {
                    withAnimation {
                        if item.content.isEmpty {
                            item.content = result
                        } else {
                            item.content += "\n\n" + result
                        }
                        isAIProcessing = false
                        aiPrompt = ""
                    }
                }
            } catch {
                await MainActor.run {
                    isAIProcessing = false
                    print("AI Error: \(error)")
                }
            }
        }
    }
}
