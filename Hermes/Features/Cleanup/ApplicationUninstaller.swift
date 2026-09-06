import AppKit
import Foundation

struct UninstallResult: Sendable {
    let successCount: Int
    let failedPaths: [(path: String, error: String)]
    let movedBytes: Int64
}

actor ApplicationUninstaller {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func isAppRunning(bundleIdentifier: String) -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleIdentifier }
    }

    func terminateApp(bundleIdentifier: String) -> Bool {
        guard let runningApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }) else {
            return true
        }
        return runningApp.terminate()
    }

    func uninstall(paths: [String]) async -> UninstallResult {
        var success = 0
        var failed: [(path: String, error: String)] = []
        var movedBytes: Int64 = 0

        for path in paths {
            let url = URL(fileURLWithPath: path)
            guard fileManager.fileExists(atPath: path) else {
                continue
            }

            let size = pathSize(url)

            do {
                try fileManager.trashItem(at: url, resultingItemURL: nil)
                success += 1
                movedBytes += size
            } catch {
                // 如果是权限原因（如 /Applications 属于 root/admin），通过 Finder AppleScript 唤起系统授权移入废纸篓
                let escapedPath = path.replacingOccurrences(of: "\"", with: "\\\"")
                let appleScript = "tell application \"Finder\" to delete (POSIX file \"\(escapedPath)\")"
                var errorDict: NSDictionary?
                if let script = NSAppleScript(source: appleScript) {
                    _ = script.executeAndReturnError(&errorDict)
                    if errorDict == nil {
                        success += 1
                        movedBytes += size
                    } else {
                        let msg = (errorDict?[NSAppleScript.errorMessage] as? String) ?? error.localizedDescription
                        failed.append((path: path, error: msg))
                    }
                } else {
                    failed.append((path: path, error: error.localizedDescription))
                }
            }
        }

        return UninstallResult(successCount: success, failedPaths: failed, movedBytes: movedBytes)
    }

    private func pathSize(_ url: URL) -> Int64 {
        let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
        if !isDir {
            return Int64((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
        }
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .totalFileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for case let child as URL in enumerator {
            if let values = try? child.resourceValues(forKeys: [.fileSizeKey, .totalFileSizeKey]) {
                total += Int64(values.totalFileSize ?? values.fileSize ?? 0)
            }
        }
        return total
    }
}
