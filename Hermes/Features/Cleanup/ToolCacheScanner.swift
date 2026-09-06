import Foundation

actor ToolCacheScanner {
    private struct Rule {
        let root: URL
        let category: CleanupCategory
        let title: String
        let recursive: Bool
    }

    private let fileManager: FileManager
    private let safetyPolicy: CleanupSafetyPolicy

    init(fileManager: FileManager = .default, safetyPolicy: CleanupSafetyPolicy? = nil) {
        self.fileManager = fileManager
        self.safetyPolicy = safetyPolicy ?? CleanupSafetyPolicy(fileManager: fileManager)
    }

    func scan() async -> CleanupScanSnapshot {
        let home = fileManager.homeDirectoryForCurrentUser
        let library = home.appendingPathComponent("Library", isDirectory: true)
        let rules = [
            Rule(root: home.appendingPathComponent(".npm/_cacache", isDirectory: true), category: .packageManagerCaches, title: "npm 缓存", recursive: false),
            Rule(root: home.appendingPathComponent(".yarn/berry/cache", isDirectory: true), category: .packageManagerCaches, title: "Yarn Berry 缓存", recursive: false),
            Rule(root: library.appendingPathComponent("Caches/Yarn", isDirectory: true), category: .packageManagerCaches, title: "Yarn 缓存", recursive: false),
            Rule(root: home.appendingPathComponent(".local/share/pnpm/store", isDirectory: true), category: .packageManagerCaches, title: "pnpm 存储仓库", recursive: false),
            Rule(root: home.appendingPathComponent(".bun/install/cache", isDirectory: true), category: .packageManagerCaches, title: "Bun 模块缓存", recursive: false),
            Rule(root: home.appendingPathComponent(".cache/pip", isDirectory: true), category: .packageManagerCaches, title: "pip 缓存", recursive: false),
            Rule(root: library.appendingPathComponent("Caches/pypoetry", isDirectory: true), category: .packageManagerCaches, title: "Python Poetry 缓存", recursive: false),
            Rule(root: library.appendingPathComponent("Caches/Homebrew/downloads", isDirectory: true), category: .packageManagerCaches, title: "Homebrew 下载缓存", recursive: false),
            Rule(root: library.appendingPathComponent("Caches/org.swift.swiftpm", isDirectory: true), category: .packageManagerCaches, title: "SwiftPM 缓存", recursive: false),
            Rule(root: library.appendingPathComponent("Caches/CocoaPods", isDirectory: true), category: .packageManagerCaches, title: "CocoaPods 缓存", recursive: false),
            Rule(root: home.appendingPathComponent(".cargo/registry/cache", isDirectory: true), category: .packageManagerCaches, title: "Rust Cargo 缓存", recursive: false),
            Rule(root: home.appendingPathComponent("go/pkg/mod/cache", isDirectory: true), category: .packageManagerCaches, title: "Go 模块缓存", recursive: false),
            Rule(root: home.appendingPathComponent(".gradle/caches", isDirectory: true), category: .packageManagerCaches, title: "Gradle 缓存", recursive: false),
            Rule(root: home.appendingPathComponent(".m2/repository", isDirectory: true), category: .packageManagerCaches, title: "Maven 本地仓库", recursive: false),
            Rule(root: home.appendingPathComponent(".composer/cache", isDirectory: true), category: .packageManagerCaches, title: "Composer 缓存", recursive: false),
            Rule(root: home.appendingPathComponent(".turbo/cache", isDirectory: true), category: .developerArtifacts, title: "Turborepo 构建缓存", recursive: false),
            Rule(root: library.appendingPathComponent("Containers/com.docker.docker/Data", isDirectory: true), category: .developerArtifacts, title: "Docker 虚拟磁盘与缓存", recursive: false),
            Rule(root: library.appendingPathComponent("Developer/Xcode/DerivedData", isDirectory: true), category: .xcodeData, title: "Xcode DerivedData", recursive: false),
            Rule(root: library.appendingPathComponent("Developer/Xcode/Archives", isDirectory: true), category: .xcodeData, title: "Xcode Archives", recursive: false),
            Rule(root: library.appendingPathComponent("Developer/Xcode/iOS DeviceSupport", isDirectory: true), category: .xcodeData, title: "Xcode iOS DeviceSupport", recursive: false),
            Rule(root: library.appendingPathComponent("Developer/XCTestDevices", isDirectory: true), category: .xcodeData, title: "XCTest 测试设备数据", recursive: false),
            Rule(root: library.appendingPathComponent("Developer/CoreSimulator/Caches", isDirectory: true), category: .xcodeData, title: "模拟器缓存", recursive: false),
            Rule(root: library.appendingPathComponent("Caches/com.apple.QuickLook.thumbnailcache", isDirectory: true), category: .quickLookCaches, title: "Quick Look 缓存", recursive: false),
            Rule(root: home.appendingPathComponent(".claude/worktrees", isDirectory: true), category: .developerArtifacts, title: "Claude Code 历史工作树", recursive: false),
            Rule(root: library.appendingPathComponent("Caches/com.microsoft.VSCode.ShipIt", isDirectory: true), category: .developerArtifacts, title: "VS Code 更新缓存", recursive: false),
            Rule(root: library.appendingPathComponent("Caches/com.microsoft.VSCode", isDirectory: true), category: .developerArtifacts, title: "VS Code 编辑器缓存", recursive: false),
            Rule(root: library.appendingPathComponent("Caches/com.todesktop.230313mzl4w4u92", isDirectory: true), category: .developerArtifacts, title: "Cursor 编辑器缓存", recursive: false),
            Rule(root: library.appendingPathComponent("Caches/ms-playwright", isDirectory: true), category: .developerArtifacts, title: "Playwright 测试浏览器缓存", recursive: false),
            Rule(root: home.appendingPathComponent(".codex/worktrees", isDirectory: true), category: .developerArtifacts, title: "Codex 工作树残留", recursive: false)
        ]

        var snapshots: [CleanupScanSnapshot] = []
        for rule in rules where fileManager.fileExists(atPath: rule.root.path) {
            snapshots.append(scanRule(rule))
        }
        return merge(snapshots)
    }

    private func scanRule(_ rule: Rule) -> CleanupScanSnapshot {
        let startedAt = Date()
        var items: [CleanupItem] = []
        var skipped = 0
        let urls: [URL]

        if rule.recursive {
            urls = (fileManager.enumerator(at: rule.root, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .totalFileSizeKey, .fileSizeKey, .contentModificationDateKey], options: [.skipsHiddenFiles, .skipsPackageDescendants])?.compactMap { $0 as? URL }) ?? []
        } else {
            urls = (try? fileManager.contentsOfDirectory(at: rule.root, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .totalFileSizeKey, .fileSizeKey, .contentModificationDateKey], options: [])) ?? []
        }

        for url in urls {
            guard !Task.isCancelled else {
                return CleanupScanSnapshot(startedAt: startedAt, finishedAt: Date(), items: items, skippedCount: skipped, wasCancelled: true)
            }
            let decision = safetyPolicy.evaluate(path: url.path, allowedRoot: rule.root)
            guard decision.isAllowed else {
                skipped += 1
                continue
            }
            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .totalFileSizeKey, .fileSizeKey, .contentModificationDateKey]) else {
                skipped += 1
                continue
            }
            let isDir = values.isDirectory == true
            let size = isDir ? directorySize(url) : Int64(values.totalFileSize ?? values.fileSize ?? 0)
            guard size > 0 else { continue }
            let age = values.contentModificationDate.map { Date().timeIntervalSince($0) } ?? 0
            let recent = age < 7 * 24 * 60 * 60
            items.append(CleanupItem(
                category: rule.category,
                path: url.path,
                kind: isDir ? .directory : .file,
                size: max(0, size),
                lastModifiedAt: values.contentModificationDate,
                riskLevel: .review,
                explanation: recent ? "最近 7 天内有活动的\(rule.title)，建议检查后再处理。" : "可由系统或开发工具重新生成的\(rule.title)。",
                reversible: true,
                selectedByDefault: false
            ))
        }

        return CleanupScanSnapshot(startedAt: startedAt, finishedAt: Date(), items: items.sorted { $0.size > $1.size }, skippedCount: skipped)
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
