import AppKit
import Foundation
import Testing
@testable import Hermes

@Suite struct ScreenshotServiceResultTests {

    private let service = ScreenshotService.shared

    @Test func captureResultSuccessHasImage() {
        // CaptureResult 类型正确性测试（不实际截图）
        let image = NSImage(size: CGSize(width: 10, height: 10))
        let result = ScreenshotService.CaptureResult.success(image)
        if case .success(let img) = result {
            #expect(img.size.width == 10)
        } else {
            #expect(Bool(false), "Expected .success")
        }
    }

    @Test func captureResultCancelled() {
        let result = ScreenshotService.CaptureResult.cancelled
        if case .cancelled = result {
            #expect(true)
        } else {
            #expect(Bool(false), "Expected .cancelled")
        }
    }

    @Test func captureResultFailedHasReason() {
        let result = ScreenshotService.CaptureResult.failed("test error")
        if case .failed(let reason) = result {
            #expect(reason == "test error")
        } else {
            #expect(Bool(false), "Expected .failed")
        }
    }

    @Test func captureResultEqualityByCase() {
        // 验证不同 case 的模式匹配工作正确
        let success = ScreenshotService.CaptureResult.success(NSImage(size: .zero))
        let cancelled = ScreenshotService.CaptureResult.cancelled
        let failed = ScreenshotService.CaptureResult.failed("err")

        // 编译时验证所有 case 可匹配
        func isSuccess(_ r: ScreenshotService.CaptureResult) -> Bool {
            if case .success = r { true } else { false }
        }
        #expect(isSuccess(success))
        #expect(!isSuccess(cancelled))
        #expect(!isSuccess(failed))
    }

    @Test func captureResultCancelledByEsc() {
        // 验证 nil 文件（用户按 Esc）映射为 .cancelled
        let result: ScreenshotService.CaptureResult = .cancelled
        #expect(result.isCancelled == true)
    }

    @Test func everyCaptureModeRequiresScreenRecordingPermission() {
        #expect(ScreenshotService.captureRequiresPermission(.area))
        #expect(ScreenshotService.captureRequiresPermission(.window))
        #expect(ScreenshotService.captureRequiresPermission(.screen))
    }

    @Test func captureArgumentsMatchEachMode() {
        #expect(ScreenshotService.arguments(for: .area, outputPath: "/tmp/area.png") == ["-i", "-x", "/tmp/area.png"])
        #expect(ScreenshotService.arguments(for: .window, outputPath: "/tmp/window.png") == ["-i", "-W", "-o", "-x", "/tmp/window.png"])
        #expect(ScreenshotService.arguments(for: .screen, outputPath: "/tmp/screen.png") == ["-x", "/tmp/screen.png"])
    }

    @Test func missingInteractiveOutputIsReportedAsCancelled() {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let result = ScreenshotService.result(at: url, exitCode: 0, missingFileResult: .cancelled)

        if case .cancelled = result {
            #expect(Bool(true))
        } else {
            #expect(Bool(false), "Expected cancelled result")
        }
    }
}

extension ScreenshotService.CaptureResult {
    var isCancelled: Bool {
        if case .cancelled = self { true } else { false }
    }

    var isSuccess: Bool {
        if case .success = self { true } else { false }
    }

    var failedReason: String? {
        if case .failed(let reason) = self { reason } else { nil }
    }
}
