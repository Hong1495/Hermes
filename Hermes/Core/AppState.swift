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
    @Published var ocrText: String = ""
    @Published var isRecognizing: Bool = false
    @Published var translatedText: String = ""
    @Published var translationInput: String = ""
    @Published var isTranslating: Bool = false
    @Published var translationError: String?
    @Published var lastCaptureMode: ScreenshotService.CaptureMode = .area
    @Published var translationFocusRequestID = UUID()

    func setScreenshot(_ image: NSImage, mode: ScreenshotService.CaptureMode = .area) {
        capturedImage = image
        lastCaptureMode = mode
        self.mode = .actions
        ocrText = ""
        isRecognizing = true
        translationInput = ""
        translatedText = ""
        translationError = nil
        isTranslating = false

        OCRService.shared.recognizeText(from: image) { [weak self] text in
            let normalized = text?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty

            self?.ocrText = normalized ?? "未识别到文本"
            self?.isRecognizing = false
        }
    }

    func prepareForTranslationWorkspace() {
        mode = .translation
        translationInput = ""
        translatedText = ""
        translationError = nil
        isTranslating = false
        requestTranslationFocus()
    }

    func requestTranslationFocus() {
        translationFocusRequestID = UUID()
    }

    func populateTranslationInputFromOCR() {
        let normalized = ocrText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty

        guard let normalized, normalized != "未识别到文本" else { return }

        translationInput = normalized
        mode = .translation
        requestTranslationFocus()
    }

    func clearWorkspace(preserveImage: Bool = false) {
        if !preserveImage {
            capturedImage = nil
            lastCaptureMode = .area
        }

        ocrText = ""
        isRecognizing = false
        translatedText = ""
        translationInput = ""
        translationError = nil
        isTranslating = false
    }

    func clear() {
        clearWorkspace()
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
