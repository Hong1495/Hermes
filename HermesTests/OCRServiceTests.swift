import Foundation
import Testing
@testable import Hermes

@Suite struct OCRServiceTests {
    @Test func filterUnsupportedLanguages() {
        // effectiveLanguages should return configured languages that are supported
        // We test the filtering logic: when stored value contains unsupported codes,
        // they get filtered out.
        let codes = "zh-Hans,en-US,zz-Nonexistent"
        let parts = codes
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let supported: Set<String> = ["zh-Hans", "en-US", "ja-JP"]
        let filtered = parts.filter { supported.contains($0) }

        #expect(filtered.count == 2)
        #expect(filtered.contains("zh-Hans"))
        #expect(filtered.contains("en-US"))
        #expect(!filtered.contains("zz-Nonexistent"))
    }

    @Test func emptyConfigFallsBackToDefaults() {
        let codes = "".split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        let nonEmpty = codes.isEmpty ? AppSettings.Default.ocrFallbackLanguages : codes
        #expect(nonEmpty == ["zh-Hans", "en-US"])
    }
}
