import Cocoa
import OSLog

/// 协调截图 / OCR / 翻译工作区的完整流程，将时序逻辑从 AppDelegate 抽出。
final class CaptureCoordinator {
    weak var windowController: FloatingWindowController?
    private let appState: AppState
    private let logger = Logger(subsystem: "hera.Hermes", category: "Capture")
    private let capturePresentationDelay: TimeInterval = 0.15
    private let ocrPresentationDelay: TimeInterval = 0.10

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Screenshot Capture

    func capture(mode: ScreenshotService.CaptureMode) {
        appState.ocrResultText = nil
        windowController?.closeWindow()

        DispatchQueue.main.asyncAfter(deadline: .now() + capturePresentationDelay) { [weak self] in
            ScreenshotService.shared.capture(mode: mode) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let image):
                        self?.appState.setScreenshot(image, mode: mode)
                        self?.windowController?.showWindow()
                    case .cancelled:
                        self?.logger.debug("截图取消（用户按 Esc）")
                    case .failed(let reason):
                        self?.logger.error("截图失败: \(reason, privacy: .public)")
                    }
                }
            }
        }
    }

    // MARK: - Silent OCR

    func ocrCaptureSilent() {
        appState.ocrResultText = nil
        windowController?.closeWindow()

        DispatchQueue.main.asyncAfter(deadline: .now() + ocrPresentationDelay) {
            ScreenshotService.shared.capture(mode: .area) { result in
                guard case .success(let image) = result else {
                    switch result {
                    case .cancelled:
                        self.logger.debug("OCR截图取消")
                    case .failed(let reason):
                        self.logger.error("OCR截图失败: \(reason, privacy: .public)")
                    case .success:
                        break
                    }
                    return
                }
                DispatchQueue.main.async {
                    OCRService.shared.recognizeText(from: image) { result in
                        guard let text = result?.text, !text.isEmpty else {
                            self.logger.debug("OCR未识别到文字")
                            NSSound(named: "Basso")?.play()
                            return
                        }
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(text, forType: .string)
                        NSSound(named: "Glass")?.play()
                        self.logger.notice("OCR完成: 已复制 \(text.count) 字符")
                        if AppSettings.showOCRPreview() {
                            self.appState.ocrResultText = text
                            self.windowController?.showWindow()
                        }
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
