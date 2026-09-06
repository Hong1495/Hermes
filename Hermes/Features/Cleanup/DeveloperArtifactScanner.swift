import Foundation

actor DeveloperArtifactScanner {
    private let fileManager: FileManager
    private let safetyPolicy: CleanupSafetyPolicy
    private let artifactNames: Set<String> = [
        "node_modules",
        "DerivedData",
        "Archives",
        "DeviceSupport",
        "target",
        ".build",
        "build",
        "dist",
        ".next",
        ".turbo",
        ".nuxt",
        ".svelte-kit",
        ".output",
        "__pycache__",
        ".pytest_cache",
        ".mypy_cache",
        ".dart_tool",
        ".pnpm-store",
        "Pods",
        "vendor",
        ".venv",
        "venv",
        ".gradle",
        ".parcel-cache",
        ".angular"
    ]

    init(fileManager: FileManager = .default, safetyPolicy: CleanupSafetyPolicy? = nil) {
        self.fileManager = fileManager
        self.safetyPolicy = safetyPolicy ?? CleanupSafetyPolicy(fileManager: fileManager)
    }

    func scan() async -> CleanupScanSnapshot {
        let home = fileManager.homeDirectoryForCurrentUser
        var roots = [
            home.appendingPathComponent("Projects", isDirectory: true),
            home.appendingPathComponent("GitHub", isDirectory: true),
            home.appendingPathComponent("dev", isDirectory: true),
            home.appendingPathComponent("Developer", isDirectory: true),
            home.appendingPathComponent("Code", isDirectory: true),
            home.appendingPathComponent("Workspace", isDirectory: true),
            home.appendingPathComponent("开发", isDirectory: true)
        ].filter { fileManager.fileExists(atPath: $0.path) }

        // 自动发现已挂载外接磁盘中的开发目录（如 /Volumes/HAS2T/开发）
        let volumesURL = URL(fileURLWithPath: "/Volumes", isDirectory: true)
        if let volumeDirs = try? fileManager.contentsOfDirectory(at: volumesURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            let devNames = ["开发", "Projects", "dev", "Developer", "Code", "Workspace", "GitHub"]
            for vol in volumeDirs where vol.lastPathComponent != "Macintosh HD" && vol.lastPathComponent != "Recovery" {
                for devName in devNames {
                    let sub = vol.appendingPathComponent(devName, isDirectory: true)
                    if fileManager.fileExists(atPath: sub.path) {
                        roots.append(sub)
                    }
                }
            }
        }

        return scan(roots: roots)
    }

    func scan(roots: [URL]) -> CleanupScanSnapshot {
        let startedAt = Date()
        var items: [CleanupItem] = []
        var skippedCount = 0
        var errorCount = 0

        for root in roots {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .totalFileSizeKey, .fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                errorCount += 1
                continue
            }

            for case let url as URL in enumerator {
                guard !Task.isCancelled else {
                    return CleanupScanSnapshot(
                        startedAt: startedAt,
                        finishedAt: Date(),
                        items: items.sorted { $0.size > $1.size },
                        skippedCount: skippedCount,
                        errorCount: errorCount,
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

                guard artifactNames.contains(url.lastPathComponent) else { continue }
                guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]) else {
                    skippedCount += 1
                    enumerator.skipDescendants()
                    continue
                }

                let isDirectory = values.isDirectory == true
                let size = isDirectory ? directorySize(url) : Int64(values.fileSize ?? 0)
                let age = values.contentModificationDate.map { Date().timeIntervalSince($0) } ?? 0
                let recentlyUsed = age < 7 * 24 * 60 * 60
                let projectRoot = projectRoot(for: url, within: root)
                items.append(CleanupItem(
                    category: .developerArtifacts,
                    path: url.path,
                    kind: .directory,
                    size: max(0, size),
                    lastModifiedAt: values.contentModificationDate,
                    riskLevel: .review,
                    explanation: recentlyUsed
                        ? "项目 \(projectRoot.lastPathComponent) 最近 7 天内有活动，建议检查后再处理。"
                        : "项目 \(projectRoot.lastPathComponent) 的可重建开发产物。",
                    reversible: true,
                    selectedByDefault: false
                ))
                enumerator.skipDescendants()
            }
        }

        return CleanupScanSnapshot(
            startedAt: startedAt,
            finishedAt: Date(),
            items: items.sorted { $0.size > $1.size },
            skippedCount: skippedCount,
            errorCount: errorCount
        )
    }

    private func directorySize(_ url: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return 0 }
        var total: Int64 = 0
        for case let child as URL in enumerator {
            guard let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey]), values.isDirectory != true else { continue }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }

    private func projectRoot(for artifact: URL, within root: URL) -> URL {
        var candidate = artifact.deletingLastPathComponent()
        let indicators = [".git", "package.json", "Package.swift", "Cargo.toml", "pyproject.toml", "go.mod", "Podfile"]
        while candidate.path != root.path && candidate.path != "/" {
            if indicators.contains(where: { fileManager.fileExists(atPath: candidate.appendingPathComponent($0).path) }) {
                return candidate
            }
            candidate.deleteLastPathComponent()
        }
        return artifact.deletingLastPathComponent()
    }
}
