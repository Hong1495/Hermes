import SwiftUI
import Combine

enum AppMode {
    case actions
    case translation
}

final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var mode: AppMode = .actions
    @Published var capturedImage: NSImage?
    @Published var translatedText: String = ""
    @Published var translationInput: String = ""
    @Published var isTranslating: Bool = false
    @Published var translationError: String?
    @Published var lastCaptureMode: ScreenshotService.CaptureMode = .area
    @Published var translationFocusRequestID = UUID()
    @Published var ocrResultText: String?

    func setScreenshot(_ image: NSImage, mode: ScreenshotService.CaptureMode = .area) {
        capturedImage = image
        lastCaptureMode = mode
        self.mode = .actions
        ocrResultText = nil
        translationInput = ""
        translatedText = ""
        translationError = nil
        isTranslating = false
    }

    func prepareForTranslationWorkspace() {
        mode = .translation
        ocrResultText = nil
        translationInput = ""
        translatedText = ""
        translationError = nil
        isTranslating = false
        requestTranslationFocus()
    }

    func requestTranslationFocus() {
        translationFocusRequestID = UUID()
    }

    func clearWorkspace(preserveImage: Bool = false) {
        if !preserveImage {
            capturedImage = nil
            lastCaptureMode = .area
        }

        translatedText = ""
        translationInput = ""
        translationError = nil
        isTranslating = false
        ocrResultText = nil
    }

    func clear() {
        clearWorkspace()
    }
}
