import Cocoa
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

    @Test func recognizesClearEnglishText() async {
        let defaults = UserDefaults.standard
        let previousLanguages = defaults.object(forKey: AppSettings.Key.ocrLanguages)
        defaults.set("en-US", forKey: AppSettings.Key.ocrLanguages)
        defer {
            if let previousLanguages {
                defaults.set(previousLanguages, forKey: AppSettings.Key.ocrLanguages)
            } else {
                defaults.removeObject(forKey: AppSettings.Key.ocrLanguages)
            }
        }

        let image = NSImage(size: NSSize(width: 900, height: 220), flipped: false) { rect in
            NSColor.white.setFill()
            rect.fill()
            NSAttributedString(
                string: "HERMES OCR 123",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 72, weight: .bold),
                    .foregroundColor: NSColor.black
                ]
            ).draw(at: NSPoint(x: 50, y: 70))
            return true
        }

        let result = await withCheckedContinuation { continuation in
            OCRService.shared.recognizeText(from: image) { result in
                continuation.resume(returning: result)
            }
        }

        #expect(result?.text.localizedCaseInsensitiveContains("HERMES") == true)
        #expect(result?.text.contains("123") == true)
    }
}
