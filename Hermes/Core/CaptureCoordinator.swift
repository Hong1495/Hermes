import Cocoa
import OSLog

protocol ScreenshotCapturing {
    func capture(
        mode: ScreenshotService.CaptureMode,
        completion: @escaping (ScreenshotService.CaptureResult) -> Void
    )
}

extension ScreenshotService: ScreenshotCapturing {}

protocol ScreenCapturePermissionChecking {
    func hasScreenCapturePermission() -> Bool
    func requestScreenCapturePermission()
}

struct SystemScreenCapturePermissionChecker: ScreenCapturePermissionChecking {
    func hasScreenCapturePermission() -> Bool {
        ScreenshotService.hasScreenCapturePermission()
    }

    func requestScreenCapturePermission() {
        _ = ScreenshotService.requestScreenCapturePermission()
    }
}

/// Coordinates the single capture lifecycle shared by screenshots and OCR.
@MainActor
final class CaptureCoordinator {
    weak var windowController: FloatingWindowController?

    private enum Operation: Equatable {
        case screenshot(ScreenshotService.CaptureMode)
        case ocr

        var mode: ScreenshotService.CaptureMode {
            switch self {
            case .screenshot(let mode): return mode
            case .ocr: return .area
            }
        }

    }

    private enum State: Equatable {
        case idle
        case waitingForPermission(Operation)
        case waitingToStart(Operation)
        case capturing(Operation)
        case recognizingOCR
    }

    private let appState: AppState
    private let screenshotService: ScreenshotCapturing
    private let permissionChecker: ScreenCapturePermissionChecking
    private let logger = Logger(subsystem: "hera.Hermes", category: "Capture")
    private let screenshotPresentationDelay: TimeInterval
    private let ocrPresentationDelay: TimeInterval
    private let permissionPollInterval: TimeInterval
    private let permissionPollLimit: Int
    private var state: State = .idle

    init(appState: AppState) {
        self.appState = appState
        self.screenshotService = ScreenshotService.shared
        self.permissionChecker = SystemScreenCapturePermissionChecker()
        self.screenshotPresentationDelay = 0.15
        self.ocrPresentationDelay = 0.10
        self.permissionPollInterval = 0.5
        self.permissionPollLimit = 16
    }

    init(
        appState: AppState,
        screenshotService: ScreenshotCapturing,
        permissionChecker: ScreenCapturePermissionChecking,
        screenshotPresentationDelay: TimeInterval = 0.15,
        ocrPresentationDelay: TimeInterval = 0.10,
        permissionPollInterval: TimeInterval = 0.5,
        permissionPollLimit: Int = 16
    ) {
        self.appState = appState
        self.screenshotService = screenshotService
        self.permissionChecker = permissionChecker
        self.screenshotPresentationDelay = screenshotPresentationDelay
        self.ocrPresentationDelay = ocrPresentationDelay
        self.permissionPollInterval = permissionPollInterval
        self.permissionPollLimit = permissionPollLimit
    }

    // MARK: - Entry points

    func capture(mode: ScreenshotService.CaptureMode) {
        start(.screenshot(mode))
    }

    func ocrCaptureSilent() {
        start(.ocr)
    }

    // MARK: - Capture lifecycle

    private func start(_ operation: Operation) {
        guard state == .idle else {
            logger.debug("截图进行中，忽略重复触发")
            return
        }

        appState.clearError()
        appState.ocrResultText = nil
        windowController?.closeWindow()

        guard ScreenshotService.captureRequiresPermission(operation.mode) else {
            scheduleCapture(operation)
            return
        }

        state = .waitingForPermission(operation)
        ensureScreenCapturePermission(for: operation, attempt: 0)
    }

    private func ensureScreenCapturePermission(for operation: Operation, attempt: Int) {
        guard state == .waitingForPermission(operation) else { return }

        if permissionChecker.hasScreenCapturePermission() {
            scheduleCapture(operation)
            return
        }

        if attempt == 0 {
            permissionChecker.requestScreenCapturePermission()
        }

        guard attempt < permissionPollLimit else {
            finishWithPermissionError(for: operation)
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + permissionPollInterval) { [weak self] in
            self?.ensureScreenCapturePermission(for: operation, attempt: attempt + 1)
        }
    }

    private func scheduleCapture(_ operation: Operation) {
        state = .waitingToStart(operation)
        let delay = operation == .ocr ? ocrPresentationDelay : screenshotPresentationDelay
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.state == .waitingToStart(operation) else { return }
            self.state = .capturing(operation)
            self.screenshotService.capture(mode: operation.mode) { [weak self] result in
                DispatchQueue.main.async {
                    self?.handleCaptureResult(result, for: operation)
                }
            }
        }
    }

    private func handleCaptureResult(_ result: ScreenshotService.CaptureResult, for operation: Operation) {
        guard state == .capturing(operation) else { return }

        switch result {
        case .success(let image):
            switch operation {
            case .screenshot(let mode):
                state = .idle
                appState.setScreenshot(image, mode: mode)
                windowController?.showWindow()
            case .ocr:
                state = .recognizingOCR
                recognizeText(in: image)
            }
        case .cancelled:
            state = .idle
            logger.debug("截图取消（用户按 Esc）")
        case .failed(let reason):
            state = .idle
            presentCaptureFailure(reason)
        }
    }

    private func recognizeText(in image: NSImage) {
        OCRService.shared.recognizeText(from: image) { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.state == .recognizingOCR else { return }
                self.state = .idle

                guard let text = result?.text, !text.isEmpty else {
                    self.logger.debug("OCR未识别到文字")
                    NSSound(named: "Basso")?.play()
                    self.appState.showError("未识别到文字，请重新选择区域。")
                    self.windowController?.showWindow()
                    return
                }

                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)
                NSSound(named: "Glass")?.play()
                self.logger.notice("OCR完成: 已复制 \(text.count) 字符")
                if AppSettings.showOCRPreview() {
                    self.appState.ocrResultText = text
                    self.windowController?.showWindow()
                }
            }
        }
    }

    // MARK: - Failure presentation

    private func finishWithPermissionError(for operation: Operation) {
        guard state == .waitingForPermission(operation) else { return }
        state = .idle

        let action = operation == .ocr ? "识别屏幕上的文字" : "截图"
        appState.showError(
            "Hermes 需要「屏幕录制」权限才能\(action)。请在系统设置中允许后重试。",
            permissionRelated: true
        )
        windowController?.showWindow()
    }

    private func presentCaptureFailure(_ reason: String) {
        logger.error("截图失败: \(reason, privacy: .public)")
        let isPermissionIssue = reason.contains("权限")
        appState.showError(
            isPermissionIssue
                ? "截图失败：缺少屏幕录制权限。请在「系统设置 → 隐私与安全性 → 屏幕录制」中允许 Hermes 后重试。"
                : "截图失败：\(reason)",
            permissionRelated: isPermissionIssue
        )
        windowController?.showWindow()
    }

    // MARK: - Translation workspace

    func openTranslationWorkspace() {
        appState.prepareForTranslationWorkspace()
        windowController?.showWindow()
    }
}
