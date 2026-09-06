import AppKit
import Testing
@testable import Hermes

@MainActor
@Suite struct CaptureCoordinatorTests {
    @Test func deniedPermissionDoesNotLaunchCapture() {
        let appState = AppState()
        let screenshotService = StubScreenshotService()
        let permissionChecker = StubPermissionChecker(isGranted: false)
        let coordinator = CaptureCoordinator(
            appState: appState,
            screenshotService: screenshotService,
            permissionChecker: permissionChecker,
            screenshotPresentationDelay: 0,
            permissionPollLimit: 0
        )

        coordinator.capture(mode: .area)

        #expect(permissionChecker.requestCount == 1)
        #expect(screenshotService.requestedModes.isEmpty)
        #expect(appState.errorIsPermissionRelated)
        #expect(appState.errorMessage?.contains("屏幕录制") == true)
    }

    @Test func successfulCaptureUpdatesTheScreenshotWorkspace() async throws {
        let appState = AppState()
        let image = NSImage(size: NSSize(width: 20, height: 10))
        let screenshotService = StubScreenshotService(result: .success(image))
        let coordinator = CaptureCoordinator(
            appState: appState,
            screenshotService: screenshotService,
            permissionChecker: StubPermissionChecker(isGranted: true),
            screenshotPresentationDelay: 0
        )

        coordinator.capture(mode: .screen)
        for _ in 0..<10 {
            if appState.capturedImage != nil { break }
            try await Task.sleep(for: .milliseconds(20))
        }

        #expect(screenshotService.requestedModes == [.screen])
        #expect(appState.capturedImage === image)
        #expect(appState.lastCaptureMode == .screen)
    }

    @Test func repeatedTriggersDoNotStartConcurrentCaptures() async throws {
        let appState = AppState()
        let screenshotService = StubScreenshotService()
        let coordinator = CaptureCoordinator(
            appState: appState,
            screenshotService: screenshotService,
            permissionChecker: StubPermissionChecker(isGranted: true),
            screenshotPresentationDelay: 0
        )

        coordinator.capture(mode: .area)
        try await Task.sleep(for: .milliseconds(20))
        coordinator.capture(mode: .window)

        #expect(screenshotService.requestedModes == [.area])
    }
}

@MainActor
private final class StubScreenshotService: ScreenshotCapturing {
    private let result: ScreenshotService.CaptureResult?
    private(set) var requestedModes: [ScreenshotService.CaptureMode] = []

    init(result: ScreenshotService.CaptureResult? = nil) {
        self.result = result
    }

    func capture(
        mode: ScreenshotService.CaptureMode,
        completion: @escaping (ScreenshotService.CaptureResult) -> Void
    ) {
        requestedModes.append(mode)
        if let result {
            completion(result)
        }
    }
}

@MainActor
private final class StubPermissionChecker: ScreenCapturePermissionChecking {
    private let isGranted: Bool
    private(set) var requestCount = 0

    init(isGranted: Bool) {
        self.isGranted = isGranted
    }

    func hasScreenCapturePermission() -> Bool {
        isGranted
    }

    func requestScreenCapturePermission() {
        requestCount += 1
    }
}
