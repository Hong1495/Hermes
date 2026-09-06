import Foundation

actor BrowserCacheScanner {
    private struct BrowserRule {
        let root: URL
        let name: String
    }

    private let fileManager: FileManager
    private let safetyPolicy: CleanupSafetyPolicy

    init(fileManager: FileManager = .default, safetyPolicy: CleanupSafetyPolicy? = nil) {
        self.fileManager = fileManager
        self.safetyPolicy = safetyPolicy ?? CleanupSafetyPolicy(fileManager: fileManager)
    }

    func scan() async -> CleanupScanSnapshot {
        let home = fileManager.homeDirectoryForCurrentUser
        let libraryCaches = home.appendingPathComponent("Library/Caches", isDirectory: true)

        let rules: [BrowserRule] = [
            BrowserRule(root: libraryCaches.appendingPathComponent("com.apple.Safari", isDirectory: true), name: "Safari"),
            BrowserRule(root: libraryCaches.appendingPathComponent("Google/Chrome", isDirectory: true), name: "Google Chrome"),
            BrowserRule(root: libraryCaches.appendingPathComponent("company.thebrowser.Browser", isDirectory: true), name: "Arc"),
            BrowserRule(root: libraryCaches.appendingPathComponent("Microsoft Edge", isDirectory: true), name: "Microsoft Edge"),
            BrowserRule(root: libraryCaches.appendingPathComponent("Firefox", isDirectory: true), name: "Firefox"),
            BrowserRule(root: libraryCaches.appendingPathComponent("BraveSoftware", isDirectory: true), name: "Brave"),
            BrowserRule(root: libraryCaches.appendingPathComponent("com.operasoftware.Opera", isDirectory: true), name: "Opera"),
            BrowserRule(root: libraryCaches.appendingPathComponent("com.vivaldi.Vivaldi", isDirectory: true), name: "Vivaldi")
        ]

        var snapshots: [CleanupScanSnapshot] = []
        for rule in rules where fileManager.fileExists(atPath: rule.root.path) {
            snapshots.append(scanBrowser(rule))
        }
        return merge(snapshots)
    }

    private func scanBrowser(_ rule: BrowserRule) -> CleanupScanSnapshot {
        let startedAt = Date()
        var items: [CleanupItem] = []
        var skipped = 0

        guard let children = try? fileManager.contentsOfDirectory(
            at: rule.root,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .totalFileSizeKey, .fileSizeKey, .contentModificationDateKey],
            options: []
        ) else {
            return CleanupScanSnapshot(startedAt: startedAt, finishedAt: Date(), errorCount: 1)
        }

        for child in children {
            guard !Task.isCancelled else {
                return CleanupScanSnapshot(startedAt: startedAt, finishedAt: Date(), items: items, skippedCount: skipped, wasCancelled: true)
            }

            let decision = safetyPolicy.evaluate(path: child.path, allowedRoot: rule.root)
            guard decision.isAllowed else {
                skipped += 1
                continue
            }

            guard let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .totalFileSizeKey, .contentModificationDateKey]) else {
                skipped += 1
                continue
            }

            let isDir = values.isDirectory == true
            let size = isDir ? directorySize(child) : Int64(values.totalFileSize ?? values.fileSize ?? 0)

            // 过滤极小文件（小于 100KB）
            guard size >= 100 * 1024 else { continue }

            let age = values.contentModificationDate.map { Date().timeIntervalSince($0) } ?? 0
            let recent = age < 3 * 24 * 60 * 60 // 3天内有活动

            items.append(CleanupItem(
                category: .browserCaches,
                path: child.path,
                kind: isDir ? .directory : .file,
                size: size,
                lastModifiedAt: values.contentModificationDate,
                riskLevel: recent ? .review : .safe,
                explanation: "\(rule.name) 网页与资源缓存，清理后不影响登录状态与书签历史。",
                reversible: true,
                selectedByDefault: !recent
            ))
        }

        return CleanupScanSnapshot(
            startedAt: startedAt,
            finishedAt: Date(),
            items: items.sorted { $0.size > $1.size },
            skippedCount: skipped
        )
    }

    private func directorySize(_ url: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .totalFileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return 0 }

        var total: Int64 = 0
        for case let child as URL in enumerator {
            if let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .totalFileSizeKey]),
               values.isDirectory != true {
                total += Int64(values.totalFileSize ?? values.fileSize ?? 0)
            }
        }
        return total
    }

    private func merge(_ snapshots: [CleanupScanSnapshot]) -> CleanupScanSnapshot {
        CleanupScanSnapshot(
            startedAt: snapshots.map(\.startedAt).min() ?? Date(),
            finishedAt: snapshots.compactMap(\.finishedAt).max(),
            items: snapshots.flatMap(\.items).sorted { $0.size > $1.size },
            skippedCount: snapshots.reduce(0) { $0 + $1.skippedCount },
            errorCount: snapshots.reduce(0) { $0 + $1.errorCount },
            wasCancelled: snapshots.contains { $0.wasCancelled }
        )
    }
}
