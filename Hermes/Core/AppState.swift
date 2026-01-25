import SwiftUI
import Combine

enum AppMode {
    case actions
    case translation
}

class AppState: ObservableObject {
    static let shared = AppState()

    @Published var mode: AppMode = .actions
    @Published var capturedImage: NSImage?
    @Published var ocrText: String = ""
    @Published var isRecognizing: Bool = false
    @Published var translatedText: String = ""
    @Published var translationInput: String = ""
    @Published var isTranslating: Bool = false
    @Published var lastCaptureMode: ScreenshotService.CaptureMode = .area

    func setScreenshot(_ image: NSImage, mode: ScreenshotService.CaptureMode = .area) {
        self.capturedImage = image
        self.lastCaptureMode = mode
        self.mode = .actions
        self.ocrText = ""
        self.isRecognizing = true

        OCRService.shared.recognizeText(from: image) { [weak self] text in
            self?.ocrText = text ?? "No text recognized"
            self?.isRecognizing = false
        }
    }

    func clear() {
        self.capturedImage = nil
        self.ocrText = ""
        self.translatedText = ""
        self.translationInput = ""
    }
}
