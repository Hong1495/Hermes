//
//  ContentParser.swift
//  Hermes
//
//  Created by Hermes AI Assistant.
//

import Foundation

class ContentParser {
    static let shared = ContentParser()
    
    func fetchAndParse(url: URL) async throws -> (title: String, content: String) {
        let (data, _) = try await URLSession.shared.data(from: url)
        
        guard let htmlString = String(data: data, encoding: .utf8) else {
            throw URLError(.badServerResponse)
        }
        
        return extractContent(html: htmlString)
    }
    
    private func extractContent(html: String) -> (String, String) {
        let titlePattern = "<title>(.*?)</title>"
        let titleRegex = try? NSRegularExpression(pattern: titlePattern, options: .caseInsensitive)
        let titleMatch = titleRegex?.firstMatch(in: html, range: NSRange(html.startIndex..., in: html))
        
        var title = "Untitled Article"
        if let range = titleMatch?.range(at: 1), let swiftRange = Range(range, in: html) {
            title = String(html[swiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        var body = html
        body = body.replacingOccurrences(of: "<script[\\s\\S]*?>[\\s\\S]*?</script>", with: "", options: .regularExpression)
        body = body.replacingOccurrences(of: "<style[\\s\\S]*?>[\\s\\S]*?</style>", with: "", options: .regularExpression)
        
        let pPattern = "<p[^>]*>(.*?)</p>"
        let pRegex = try? NSRegularExpression(pattern: pPattern, options: .caseInsensitive)
        let matches = pRegex?.matches(in: body, range: NSRange(body.startIndex..., in: body)) ?? []
        
        let paragraphs = matches.compactMap { match -> String? in
            guard let range = Range(match.range(at: 1), in: body) else { return nil }
            let rawText = String(body[range])
            return rawText.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                          .trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }
        
        let cleanedContent = paragraphs.joined(separator: "\n\n")
        
        return (title, cleanedContent.isEmpty ? "No readable content found." : cleanedContent)
    }
}
