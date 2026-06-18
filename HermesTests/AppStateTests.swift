import AppKit
import Testing
@testable import Hermes

@Suite struct AppStateTests {
    @Test func setScreenshotClearsOCRPreview() {
        let appState = AppState()
        appState.ocrResultText = "stale OCR"

        appState.setScreenshot(NSImage(size: CGSize(width: 10, height: 10)), mode: .area)

        #expect(appState.ocrResultText == nil)
        #expect(appState.mode == .actions)
    }

    @Test func prepareTranslationClearsOCRPreview() {
        let appState = AppState()
        appState.ocrResultText = "stale OCR"

        appState.prepareForTranslationWorkspace()

        #expect(appState.ocrResultText == nil)
        #expect(appState.mode == .translation)
    }
}
