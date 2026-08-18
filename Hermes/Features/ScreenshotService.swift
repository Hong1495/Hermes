import Cocoa

final class ScreenshotService {
    static let shared = ScreenshotService()

    init() {}

    enum CaptureMode: Equatable {
        case area
        case window
        case screen
    }

    enum CaptureResult {
        case success(NSImage)
        case cancelled
        case failed(String)
    }

    // MARK: - Screen Recording Permission

    /// macOS 会允许交互式选区界面先出现，再在提交选区时拒绝无权限的截图。
    /// 因此所有截图模式都必须先检查屏幕录制权限，否则用户会看到十字光标却拿不到结果。
    static func captureRequiresPermission(_ mode: CaptureMode) -> Bool {
        true
    }

    /// 预检屏幕录制权限（TCC kTCCServiceScreenCapture）。
    static func hasScreenCapturePermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// 请求屏幕录制权限；系统会在首次请求时弹出授权对话框。
    static func requestScreenCapturePermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    /// 命令参数集中定义，便于验证每种模式的交互行为。
    static func arguments(for mode: CaptureMode, outputPath: String) -> [String] {
        switch mode {
        case .area:
            return ["-i", "-x", outputPath]
        case .window:
            return ["-i", "-W", "-o", "-x", outputPath]
        case .screen:
            return ["-x", outputPath]
        }
    }

    func capture(mode: CaptureMode, completion: @escaping (CaptureResult) -> Void) {
        switch mode {
        case .window:
            captureWindow(completion: completion)
        case .area, .screen:
            captureToFile(
                arguments: Self.arguments(for: mode, outputPath: "{output}"),
                outputPathSuffix: "",
                missingFileResult: .cancelled,
                completion: completion
            )
        }
    }

    // Legacy alias
    func captureInteractive(completion: @escaping (CaptureResult) -> Void) {
        capture(mode: .area, completion: completion)
    }

    // MARK: - Process execution

    /// 每次调用生成唯一临时路径，避免并发截图时互相覆盖。
    private static func makeTempPath(suffix: String = "") -> String {
        let unique = "\(ProcessInfo.processInfo.processIdentifier)_\(UUID().uuidString)\(suffix).png"
        return NSTemporaryDirectory().appending(unique)
    }

    private func captureWindow(completion: @escaping (CaptureResult) -> Void) {
        let clickPoint = NSEvent.mouseLocation
        captureToFile(
            arguments: Self.arguments(for: .window, outputPath: "{output}"),
            outputPathSuffix: "_w",
            missingFileResult: .cancelled
        ) { [weak self] result in
            guard case .success = result, let self else {
                completion(result)
                return
            }

            // Some windows (for example sharingState=0 windows) are skipped by -W.
            // Re-capture their full bounds by region when the picker returned a window behind it.
            if Self.hasBlockedWindowAt(cocoaPoint: clickPoint),
               let rect = Self.findWindowRectViaRegion(cocoaPoint: clickPoint) {
                self.captureRegion(rect: rect, completion: completion)
            } else {
                completion(result)
            }
        }
    }

    private func captureRegion(rect: NSRect, completion: @escaping (CaptureResult) -> Void) {
        let rectString = String(format: "%d,%d,%d,%d",
                                Int(rect.origin.x), Int(rect.origin.y),
                                Int(rect.width), Int(rect.height))
        captureToFile(
            arguments: ["-R", rectString, "-x", "{output}"],
            outputPathSuffix: "_r",
            missingFileResult: .failed("区域截图未生成文件"),
            completion: completion
        )
    }

    private func captureToFile(
        arguments argumentTemplate: [String],
        outputPathSuffix: String,
        missingFileResult: CaptureResult,
        completion: @escaping (CaptureResult) -> Void
    ) {
        let outputPath = Self.makeTempPath(suffix: outputPathSuffix)
        let outputURL = URL(fileURLWithPath: outputPath)
        try? FileManager.default.removeItem(at: outputURL)

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = argumentTemplate.map { $0 == "{output}" ? outputPath : $0 }
        task.terminationHandler = { task in
            let result = Self.result(
                at: outputURL,
                exitCode: task.terminationStatus,
                missingFileResult: missingFileResult
            )
            DispatchQueue.main.async {
                completion(result)
            }
        }

        do {
            try task.run()
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            DispatchQueue.main.async {
                completion(.failed("screencapture 启动失败: \(error.localizedDescription)"))
            }
        }
    }

    static func result(
        at url: URL,
        exitCode: Int32,
        missingFileResult: CaptureResult
    ) -> CaptureResult {
        defer { try? FileManager.default.removeItem(at: url) }

        guard FileManager.default.fileExists(atPath: url.path) else {
            return exitCode == 0 ? missingFileResult :
                .failed("screencapture 失败（退出码 \(exitCode)），可能是缺少屏幕录制权限")
        }
        guard let image = NSImage(contentsOf: url), image.isValid else {
            return .failed("截图文件读取失败")
        }
        return .success(image)
    }

    /// Checks if a sharingState=0 window exists at the given Cocoa point
    /// that is NOT visible in optionOnScreenOnly (i.e., standard window picker can't see it).
    private static func hasBlockedWindowAt(cocoaPoint: NSPoint) -> Bool {
        let primaryMaxY = NSScreen.screens.map(\.frame.maxY).max() ?? 0
        let quartzPoint = CGPoint(x: cocoaPoint.x, y: primaryMaxY - cocoaPoint.y)

        // Get visible windows (ones screencapture -W can see)
        let visibleIDs = Set(windowIDs(at: quartzPoint, options: .optionOnScreenOnly))

        // Get all windows including blocked
        let allWindows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []

        for info in allWindows {
            let pid = info[kCGWindowOwnerPID as String] as? pid_t ?? -1
            if pid == ProcessInfo.processInfo.processIdentifier { continue }

            let sharing = info[kCGWindowSharingState as String] as? Int ?? 1
            guard sharing == 0 else { continue }

            guard let bounds = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = bounds["X"], let y = bounds["Y"],
                  let w = bounds["Width"], let h = bounds["Height"],
                  w > 30, h > 30 else { continue }

            guard quartzPoint.x >= x, quartzPoint.x <= x + w,
                  quartzPoint.y >= y, quartzPoint.y <= y + h else { continue }

            let layer = info[kCGWindowLayer as String] as? Int32 ?? 0
            guard layer >= -100, layer <= 100 else { continue }

            let wid = info[kCGWindowNumber as String] as? UInt32 ?? 0
            if visibleIDs.contains(wid) { continue }

            // Found a blocked window on top at this point
            return true
        }

        return false
    }

    /// Rect for region-based fallback capture, in Quartz coordinates.
    private static func findWindowRectViaRegion(cocoaPoint: NSPoint) -> NSRect? {
        let primaryMaxY = NSScreen.screens.map(\.frame.maxY).max() ?? 0
        let quartzPoint = CGPoint(x: cocoaPoint.x, y: primaryMaxY - cocoaPoint.y)

        return findRect(at: quartzPoint, options: .optionAll)
    }

    private static func windowIDs(at quartzPoint: CGPoint, options: CGWindowListOption) -> [UInt32] {
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        return list.compactMap { info in
            guard let bounds = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = bounds["X"], let y = bounds["Y"],
                  let w = bounds["Width"], let h = bounds["Height"] else { return nil }

            guard quartzPoint.x >= x, quartzPoint.x <= x + w,
                  quartzPoint.y >= y, quartzPoint.y <= y + h else { return nil }

            let layer = info[kCGWindowLayer as String] as? Int32 ?? 0
            guard layer >= -100, layer <= 100 else { return nil }

            return info[kCGWindowNumber as String] as? UInt32
        }
    }

    private static func findRect(at quartzPoint: CGPoint, options: CGWindowListOption) -> NSRect? {
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        var bestLayer: Int32 = .min
        var bestRect: NSRect?

        for info in list {
            guard let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                  pid != ProcessInfo.processInfo.processIdentifier else { continue }

            guard let bounds = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = bounds["X"], let y = bounds["Y"],
                  let w = bounds["Width"], let h = bounds["Height"],
                  w > 30, h > 30 else { continue }

            let rect = NSRect(x: x, y: y, width: w, height: h)
            guard NSPointInRect(quartzPoint, rect) else { continue }

            let layer = info[kCGWindowLayer as String] as? Int32 ?? 0
            guard layer >= -100, layer <= 100 else { continue }

            if layer >= bestLayer {
                bestLayer = layer
                bestRect = rect
            }
        }

        return bestRect
    }
}
