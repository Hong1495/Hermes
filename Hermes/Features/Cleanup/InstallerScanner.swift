import Foundation

actor InstallerScanner {
    private let fileManager: FileManager
    private let safetyPolicy: CleanupSafetyPolicy

    init(fileManager: FileManager = .default, safetyPolicy: CleanupSafetyPolicy? = nil) {
        self.fileManager = fileManager
        self.safetyPolicy = safetyPolicy ?? CleanupSafetyPolicy(fileManager: fileManager)
    }

    func scan() async -> CleanupScanSnapshot {
        let roots = automaticRoots().filter { fileManager.fileExists(atPath: $0.path) }
        return await scan(roots: roots)
    }

    func scan(roots: [URL]) async -> CleanupScanSnapshot {
        let startedAt = Date()
        var allItems: [CleanupItem] = []
        var skippedCount = 0
        var errorCount = 0

        for root in roots {
            let result = scanRoot(root: root, startedAt: startedAt)
            allItems.append(contentsOf: result.items)
            skippedCount += result.skippedCount
            errorCount += result.errorCount
            if result.wasCancelled {
                return CleanupScanSnapshot(
                    startedAt: startedAt,
                    finishedAt: Date(),
                    items: allItems.sorted { $0.size > $1.size },
                    skippedCount: skippedCount,
                    errorCount: errorCount,
                    wasCancelled: true
                )
            }
        }

        return CleanupScanSnapshot(
            startedAt: startedAt,
            finishedAt: Date(),
            items: allItems.sorted { $0.size > $1.size },
            skippedCount: skippedCount,
            errorCount: errorCount
        )
    }

    private func merge(_ snapshots: CleanupScanSnapshot...) -> CleanupScanSnapshot {
        CleanupScanSnapshot(
            startedAt: snapshots.map(\.startedAt).min() ?? Date(),
            finishedAt: snapshots.compactMap(\.finishedAt).max(),
            items: snapshots.flatMap(\.items).sorted { $0.size > $1.size },
            skippedCount: snapshots.reduce(0) { $0 + $1.skippedCount },
            errorCount: snapshots.reduce(0) { $0 + $1.errorCount },
            wasCancelled: snapshots.contains { $0.wasCancelled }
        )
    }

    private func automaticRoots() -> [URL] {
        let home = fileManager.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent("Downloads", isDirectory: true),
            home.appendingPathComponent("Desktop", isDirectory: true),
            home.appendingPathComponent("Documents", isDirectory: true),
            home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true),
            home.appendingPathComponent("Library/Caches/Homebrew", isDirectory: true),
            home.appendingPathComponent("Library/Application Support/Homebrew", isDirectory: true),
            home.appendingPathComponent("Library/Containers/com.apple.mail/Data/Library/Mail Downloads", isDirectory: true),
            home.appendingPathComponent("Library/Application Support/Telegram Desktop/tdata/Downloads", isDirectory: true)
        ]
    }

    private func scanRoot(root: URL, startedAt: Date) -> CleanupScanSnapshot {
        var items: [CleanupItem] = []
        var skippedCount = 0

        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey, .totalFileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return CleanupScanSnapshot(
                startedAt: startedAt,
                finishedAt: Date(),
                skippedCount: 1,
                errorCount: 1
            )
        }

        for case let url as URL in enumerator {
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
                if decision.reason == .symbolicLink {
                    enumerator.skipDescendants()
                }
                continue
            }

            guard isInstaller(url) else { continue }
            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .totalFileSizeKey, .contentModificationDateKey]) else {
                skippedCount += 1
                continue
            }

            let isDirectory = values.isDirectory == true
            let size = Int64(values.totalFileSize ?? values.fileSize ?? 0)
            items.append(CleanupItem(
                category: .installerFiles,
                path: url.path,
                kind: isDirectory ? .package : .file,
                size: max(0, size),
                lastModifiedAt: values.contentModificationDate,
                riskLevel: .review,
                explanation: "自动扫描到的安装包，确认后可移入废纸篓。",
                reversible: true,
                selectedByDefault: false
            ))

            if isDirectory {
                enumerator.skipDescendants()
            }
        }

        return CleanupScanSnapshot(
            startedAt: startedAt,
            finishedAt: Date(),
            items: items,
            skippedCount: skippedCount
        )
    }

    private func isInstaller(_ url: URL) -> Bool {
        ["dmg", "pkg", "mpkg", "iso", "xip", "zip"].contains(url.pathExtension.lowercased())
    }
}
