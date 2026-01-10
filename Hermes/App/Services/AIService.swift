//
//  AIService.swift
//  Hermes
//
//  Created by Hermes AI Assistant.
//

import Foundation
import Combine

enum AIError: Error {
    case invalidURL
    case noAPIKey
    case networkError(Error)
    case decodingError(Error)
    case apiError(String)
}

class AIConfig: ObservableObject {
    static let shared = AIConfig()
    
    @Published var apiKey: String {
        didSet {
            UserDefaults.standard.set(apiKey, forKey: "GeminiAPIKey")
        }
    }
    
    @Published var modelName: String = "gemini-1.5-flash"
    
    init() {
        self.apiKey = UserDefaults.standard.string(forKey: "GeminiAPIKey") ?? ""
    }
}

class AIService {
    static let shared = AIService()
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"
    
    func generateText(prompt: String) async throws -> String {
        guard !AIConfig.shared.apiKey.isEmpty else {
            throw AIError.noAPIKey
        }
        
        let urlString = "\(baseURL)/\(AIConfig.shared.modelName):generateContent?key=\(AIConfig.shared.apiKey)"
        guard let url = URL(string: urlString) else { throw AIError.invalidURL }
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, 
              (200...299).contains(httpResponse.statusCode) else {
            let errMsg = String(data: data, encoding: .utf8) ?? "Unknown Error"
            throw AIError.apiError("Status: \((response as? HTTPURLResponse)?.statusCode ?? 0), Body: \(errMsg)")
        }
        
        let root = try JSONDecoder().decode(GeminiResponse.self, from: data)
        return root.candidates?.first?.content.parts.first?.text ?? ""
    }
}

struct GeminiResponse: Codable {
    struct Candidate: Codable {
        struct Content: Codable {
            struct Part: Codable {
                let text: String
            }
            let parts: [Part]
        }
        let content: Content
    }
    let candidates: [Candidate]?
}
