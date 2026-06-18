import Cocoa
import OSLog

/// 协调截图 / OCR / 翻译工作区的完整流程，将时序逻辑从 AppDelegate 抽出。
final class CaptureCoordinator {
    weak var windowController: FloatingWindowController?
    private let appState: AppState
    private let logger = Logger(subsystem: "hera.Hermes", category: "Capture")

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Screenshot Capture

    func capture(mode: ScreenshotService.CaptureMode) {
        windowController?.closeWindow()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
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
        windowController?.closeWindow()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            ScreenshotService.shared.capture(mode: .area) { result in
                guard case .success(let image) = result else {
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
                        let showPreview = UserDefaults.standard.bool(forKey: AppSettings.Key.showOCRPreview)
                        if showPreview {
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
