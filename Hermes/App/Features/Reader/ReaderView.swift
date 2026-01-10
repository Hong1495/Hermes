//
//  ReaderView.swift
//  Hermes
//
//  Created by Hermes AI Assistant.
//

import SwiftUI

struct ReaderView: View {
    @Bindable var item: HermesItem
    @State private var isSummarizing: Bool = false
    
    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(item.title)
                        .font(.system(.title, design: .serif).weight(.bold))
                        .textSelection(.enabled)
                    
                    if let urlStr = item.sourceURL, let url = URL(string: urlStr) {
                        Link(destination: url) {
                            Label(url.host() ?? "Original Source", systemImage: "link")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                    }
                    
                    Divider()
                    
                    Text(item.content)
                        .font(.system(.body, design: .serif))
                        .lineSpacing(8)
                        .textSelection(.enabled)
                        .foregroundStyle(.primary.opacity(0.85))
                }
                .padding(40)
                .frame(maxWidth: 800)
            }
            .frame(maxWidth: .infinity)
            .background(Color(NSColor.textBackgroundColor))
            
            Divider()
            
            VStack(alignment: .leading, spacing: 20) {
                Text("AI Assistant")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                if let summary = item.summary, !summary.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Summary", systemImage: "text.quote")
                            .font(.caption.weight(.bold))
                        Text(summary)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.yellow.opacity(0.1)))
                } else {
                    Button(action: generateSummary) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Summarize Article")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.3)))
                    }
                    .buttonStyle(.plain)
                    .disabled(isSummarizing)
                }
                
                Spacer()
            }
            .padding()
            .frame(width: 250)
            .background(.regularMaterial)
        }
    }
    
    private func generateSummary() {
        guard !item.content.isEmpty else { return }
        isSummarizing = true
        
        Task {
            let prompt = "Summarize the following article in 3 bullet points:\n\n\(item.content.prefix(5000))"
            do {
                let result = try await AIService.shared.generateText(prompt: prompt)
                await MainActor.run {
                    withAnimation {
                        item.summary = result
                        isSummarizing = false
                    }
                }
            } catch {
                await MainActor.run {
                    isSummarizing = false
                }
            }
        }
    }
}
