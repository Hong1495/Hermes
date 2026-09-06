import Foundation

actor CacheScanner {
    private let fileManager: FileManager
    private let safetyPolicy: CleanupSafetyPolicy

    init(fileManager: FileManager = .default, safetyPolicy: CleanupSafetyPolicy? = nil) {
        self.fileManager = fileManager
        self.safetyPolicy = safetyPolicy ?? CleanupSafetyPolicy(fileManager: fileManager)
    }

    func scan() async -> CleanupScanSnapshot {
        let home = fileManager.homeDirectoryForCurrentUser
        let libraryCaches = home.appendingPathComponent("Library/Caches", isDirectory: true)

        let roots: [(URL, CleanupCategory, String)] = [
            (home.appendingPathComponent("Library/Logs", isDirectory: true), .applicationLogs, "应用日志"),
            (home.appendingPathComponent("Library/Logs/DiagnosticReports", isDirectory: true), .crashReports, "系统诊断与崩溃报告"),
            (libraryCaches.appendingPathComponent("com.apple.helpd", isDirectory: true), .applicationCaches, "macOS Help 系统缓存"),
            (libraryCaches.appendingPathComponent("com.apple.AppleMediaServices", isDirectory: true), .applicationCaches, "Apple Media Services 缓存"),
            (libraryCaches.appendingPathComponent("com.apple.parsecd", isDirectory: true), .applicationCaches, "Parsecd 缓存")
        ]

        var snapshots: [CleanupScanSnapshot] = []
        for (root, category, label) in roots where fileManager.fileExists(atPath: root.path) {
            snapshots.append(scanRoot(root: root, category: category, label: label))
        }

        // 动态扫描 ~/Library/Caches 中大于 5MB 的第三方应用缓存目录
        snapshots.append(scanGeneralAppCaches(cachesRoot: libraryCaches))

        return merge(snapshots)
    }

    private func scanGeneralAppCaches(cachesRoot: URL) -> CleanupScanSnapshot {
        let startedAt = Date()
        var items: [CleanupItem] = []
        var skippedCount = 0

        // 浏览器和特定工具由专用 Scanner 负责，避免重复统计
        let excludedNames: Set<String> = [
            "com.apple.Safari", "Google", "company.thebrowser.Browser", "Microsoft Edge",
            "Firefox", "BraveSoftware", "Homebrew", "CocoaPods", "org.swift.swiftpm",
            "com.apple.helpd", "com.apple.AppleMediaServices", "com.apple.parsecd",
            "CloudKit", "com.apple.nsurlsessiond"
        ]

        guard let children = try? fileManager.contentsOfDirectory(
            at: cachesRoot,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return CleanupScanSnapshot(startedAt: startedAt, finishedAt: Date())
        }

        for child in children {
            guard !Task.isCancelled else { break }
            let name = child.lastPathComponent
            guard !excludedNames.contains(name) else { continue }

            let decision = safetyPolicy.evaluate(path: child.path, allowedRoot: cachesRoot)
            guard decision.isAllowed else {
                skippedCount += 1
                continue
            }

            guard let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey]),
                  values.isDirectory == true else {
                continue
            }

            let size = directorySize(child)
            // 仅纳入 >= 5MB 的应用缓存，避免生成大量几十KB的琐碎条目
            guard size >= 5 * 1024 * 1024 else { continue }

            let age = values.contentModificationDate.map { Date().timeIntervalSince($0) } ?? 0
            let recent = age < 3 * 24 * 60 * 60
            items.append(CleanupItem(
                category: .applicationCaches,
                path: child.path,
                kind: .directory,
                size: size,
                lastModifiedAt: values.contentModificationDate,
                riskLevel: recent ? .review : .safe,
                explanation: "应用 \(name) 的磁盘缓存，可由该应用按需重新生成。",
                reversible: true,
                selectedByDefault: !recent
            ))
        }

        return CleanupScanSnapshot(
            startedAt: startedAt,
            finishedAt: Date(),
            items: items.sorted { $0.size > $1.size },
            skippedCount: skippedCount
        )
    }

    private func scanRoot(root: URL, category: CleanupCategory, label: String) -> CleanupScanSnapshot {
        let startedAt = Date()
        var items: [CleanupItem] = []
        var skippedCount = 0

        guard let children = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .totalFileSizeKey, .fileSizeKey, .contentModificationDateKey],
            options: []
        ) else {
            return CleanupScanSnapshot(startedAt: startedAt, finishedAt: Date(), errorCount: 1)
        }

        for url in children {
            guard !Task.isCancelled else {
                return CleanupScanSnapshot(
                    startedAt: startedAt,
                    finishedAt: Date(),
                    items: items,
                    skippedCount: skippedCount,
                    wasCancelled: true
                )
            }

            let decision = safetyPolicy.evaluate(path: url.path, allowedRoot: root)
            guard decision.isAllowed else {
                skippedCount += 1
                continue
            }
            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .totalFileSizeKey, .fileSizeKey, .contentModificationDateKey]) else {
                skippedCount += 1
                continue
            }

            let isDirectory = values.isDirectory == true
            let size: Int64
            if isDirectory {
                size = directorySize(url)
            } else {
                size = Int64(values.fileSize ?? 0)
            }
            let age = values.contentModificationDate.map { Date().timeIntervalSince($0) } ?? 0
            let recent = age < 7 * 24 * 60 * 60
            let risk: CleanupRiskLevel = recent ? .review : (category == .applicationCaches ? .safe : .review)
            let defaultSelection = category == .applicationCaches && !recent
            items.append(CleanupItem(
                category: category,
                path: url.path,
                kind: isDirectory ? .directory : .file,
                size: max(0, size),
                lastModifiedAt: values.contentModificationDate,
                riskLevel: risk,
                explanation: recent ? "最近 7 天内有活动的\(label)，建议检查后再处理。" : "自动扫描到的\(label)，内容可重新生成。",
                reversible: true,
                selectedByDefault: defaultSelection
            ))
        }

        return CleanupScanSnapshot(
            startedAt: startedAt,
            finishedAt: Date(),
            items: items.sorted { $0.size > $1.size },
            skippedCount: skippedCount
        )
    }

    private func directorySize(_ url: URL) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey]),
              values.isDirectory == true else {
            return Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return 0 }
        var total: Int64 = 0
        for case let child as URL in enumerator {
            guard let childValues = try? child.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey]),
                  childValues.isDirectory != true else { continue }
            total += Int64(childValues.fileSize ?? 0)
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
