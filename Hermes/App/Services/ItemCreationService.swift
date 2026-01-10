//
//  ItemCreationService.swift
//  Hermes
//
//  Created by Hermes AI Assistant.
//

import Foundation
import SwiftData

class ItemCreationService {
    @MainActor
    static func createItem(from text: String, modelContext: ModelContext) {
        if let url = URL(string: text), url.scheme?.hasPrefix("http") == true {
            let newItem = HermesItem(title: "Loading...", scene: .article, status: .inbox)
            newItem.sourceURL = text
            modelContext.insert(newItem)
            
            Task {
                do {
                    let (title, content) = try await ContentParser.shared.fetchAndParse(url: url)
                    await MainActor.run {
                        newItem.title = title
                        newItem.content = content
                    }
                } catch {
                    print("Parse error: \(error)")
                    await MainActor.run {
                        newItem.title = "Failed to Load: \(text)"
                    }
                }
            }
        } else {
            let title = text.components(separatedBy: "\n").first ?? "New Draft"
            let newItem = HermesItem(title: title, content: text, scene: .draft, status: .inbox)
            modelContext.insert(newItem)
        }
    }
}
