import Cocoa

class ScreenshotService {
    static let shared = ScreenshotService()

    private init() {}

    enum CaptureMode {
        case area
        case window
        case screen
    }

    func capture(mode: CaptureMode, completion: @escaping (NSImage?) -> Void) {
        switch mode {
        case .window:
            captureWindow(completion: completion)
        case .area, .screen:
            captureViaScreencapture(mode: mode, completion: completion)
        }
    }

    // Legacy alias
    func captureInteractive(completion: @escaping (NSImage?) -> Void) {
        capture(mode: .area, completion: completion)
    }

    // MARK: - screencapture path (area / screen)

    /// 每次调用生成唯一临时路径，避免并发截图时互相覆盖
    private static func makeTempPath(suffix: String = "") -> String {
        let unique = "\(ProcessInfo.processInfo.processIdentifier)_\(UUID().uuidString)\(suffix).png"
        return NSTemporaryDirectory().appending(unique)
    }

    private func captureViaScreencapture(mode: CaptureMode, completion: @escaping (NSImage?) -> Void) {
        let tempPath = Self.makeTempPath()
        let url = URL(fileURLWithPath: tempPath)
        try? FileManager.default.removeItem(at: url)

        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"

        var arguments: [String] = []

        switch mode {
        case .area:
            arguments.append("-i")
        case .screen:
            break
        default:
            break
        }

        arguments.append("-x")
        arguments.append(tempPath)

        task.arguments = arguments

        task.terminationHandler = { _ in
            let image: NSImage?
            if FileManager.default.fileExists(atPath: tempPath) {
                image = NSImage(contentsOfFile: tempPath)
                try? FileManager.default.removeItem(at: URL(fileURLWithPath: tempPath))
            } else {
                image = nil
            }
            DispatchQueue.main.async {
                completion(image)
            }
        }

        do {
            try task.run()
        } catch {
            completion(nil)
        }
    }

    // MARK: - Window capture

    private func captureWindow(completion: @escaping (NSImage?) -> Void) {
        let tempPath = Self.makeTempPath(suffix: "_w")
        let url = URL(fileURLWithPath: tempPath)
        try? FileManager.default.removeItem(at: url)

        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"

        // Try standard window capture first. Works for all normal windows.
        task.arguments = ["-i", "-W", "-o", "-x", tempPath]

        task.terminationHandler = { [weak self] _ in
            let image: NSImage?
            if FileManager.default.fileExists(atPath: tempPath) {
                image = NSImage(contentsOfFile: tempPath)
                try? FileManager.default.removeItem(at: URL(fileURLWithPath: tempPath))
            } else {
                image = nil
            }

            // If image exists, check whether a sharingState=0 window (WeChat)
            // was on top at mouse click position — screencapture -i -W would have
            // skipped it and captured the window behind instead.
            if image != nil, let self = self {
                let clickPoint = NSEvent.mouseLocation
                if Self.hasBlockedWindowAt(cocoaPoint: clickPoint),
                   let rect = Self.findWindowRectViaRegion(cocoaPoint: clickPoint) {
                    // Re-capture using region mode (pixel-level, bypasses window sharing)
                    self.captureRegion(rect: rect, completion: completion)
                    return
                }
            }

            DispatchQueue.main.async {
                completion(image)
            }
        }

        do {
            try task.run()
        } catch {
            completion(nil)
        }
    }

    private func captureRegion(rect: NSRect, completion: @escaping (NSImage?) -> Void) {
        let tempPath = Self.makeTempPath(suffix: "_r")
        let url = URL(fileURLWithPath: tempPath)
        try? FileManager.default.removeItem(at: url)

        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"

        let rectStr = String(format: "%d,%d,%d,%d",
                             Int(rect.origin.x), Int(rect.origin.y),
                             Int(rect.width), Int(rect.height))
        task.arguments = ["-R", rectStr, "-x", tempPath]

        task.terminationHandler = { _ in
            let image: NSImage?
            if FileManager.default.fileExists(atPath: tempPath) {
                image = NSImage(contentsOfFile: tempPath)
                try? FileManager.default.removeItem(at: URL(fileURLWithPath: tempPath))
            } else {
                image = nil
            }
            DispatchQueue.main.async {
                completion(image)
            }
        }

        do {
            try task.run()
        } catch {
            completion(nil)
        }
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
