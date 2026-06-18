import Cocoa

/// 协调截图 / OCR / 翻译工作区的完整流程，将时序逻辑从 AppDelegate 抽出。
final class CaptureCoordinator {
    weak var windowController: FloatingWindowController?
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Screenshot Capture

    func capture(mode: ScreenshotService.CaptureMode) {
        windowController?.closeWindow()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            ScreenshotService.shared.capture(mode: mode) { image in
                guard let image = image else { return }

                DispatchQueue.main.async {
                    self?.appState.setScreenshot(image, mode: mode)
                    self?.windowController?.showWindow()
                }
            }
        }
    }

    // MARK: - Silent OCR

    func ocrCaptureSilent() {
        windowController?.closeWindow()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            ScreenshotService.shared.capture(mode: .area) { image in
                guard let image = image else { return }
                DispatchQueue.main.async {
                    OCRService.shared.recognizeText(from: image) { result in
                        let text = result?.text
                        guard let text = text, !text.isEmpty else {
                            NSSound(named: "Basso")?.play()
                            return
                        }
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(text, forType: .string)
                        NSSound(named: "Glass")?.play()
                    }
                }
            }
        }
    }

    // MARK: - Translation Workspace

    func openTranslationWorkspace() {
        DispatchQueue.main.async {
            self.appState.prepareForTranslationWorkspace()
            self.windowController?.showWindow()
        }
    }
}
