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
            ScreenshotService.shared.capture(mode: mode) { image in
                guard let image = image else {
                    self?.logger.error("截图失败: capture returned nil")
                    return
                }

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
                guard let image = image else {
                    self.logger.error("OCR截图失败: capture returned nil")
                    NSSound(named: "Basso")?.play()
                    return
                }
                DispatchQueue.main.async {
                    OCRService.shared.recognizeText(from: image) { result in
                        guard let text = result?.text, !text.isEmpty else {
                            self.logger.warning("OCR未识别到文字")
                            NSSound(named: "Basso")?.play()
                            return
                        }
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(text, forType: .string)
                        NSSound(named: "Glass")?.play()
                        self.logger.notice("OCR完成: 已复制 \(text.count) 字符")
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
