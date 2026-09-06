import Foundation

actor AIToolsScanner {
    private struct AIRule {
        let root: URL
        let title: String
        let explanation: String
    }

    private let fileManager: FileManager
    private let safetyPolicy: CleanupSafetyPolicy

    init(fileManager: FileManager = .default, safetyPolicy: CleanupSafetyPolicy? = nil) {
        self.fileManager = fileManager
        self.safetyPolicy = safetyPolicy ?? CleanupSafetyPolicy(fileManager: fileManager)
    }

    func scan() async -> CleanupScanSnapshot {
        let home = fileManager.homeDirectoryForCurrentUser
        let rules: [AIRule] = [
            AIRule(
                root: home.appendingPathComponent(".ollama/models", isDirectory: true),
                title: "Ollama 本地模型",
                explanation: "Ollama 下载的模型权重与清单，删除后再次使用需重新 pull。"
            ),
            AIRule(
                root: home.appendingPathComponent(".cache/huggingface/hub", isDirectory: true),
                title: "Hugging Face 模型缓存",
                explanation: "通过 transformers/huggingface_hub 下载的模型权重缓存。"
            ),
            AIRule(
                root: home.appendingPathComponent(".cache/lm-studio/models", isDirectory: true),
                title: "LM Studio 模型",
                explanation: "LM Studio 下载的本地大语言模型。"
            ),
            AIRule(
                root: home.appendingPathComponent(".cache/torch/kernels", isDirectory: true),
                title: "PyTorch 编译缓存",
                explanation: "PyTorch 本地编译的算子与核函数缓存。"
            )
        ]

        var snapshots: [CleanupScanSnapshot] = []
        for rule in rules where fileManager.fileExists(atPath: rule.root.path) {
            snapshots.append(scanRule(rule))
        }
        return merge(snapshots)
    }

    private func scanRule(_ rule: AIRule) -> CleanupScanSnapshot {
        let startedAt = Date()
        var items: [CleanupItem] = []
        var skipped = 0

        guard let children = try? fileManager.contentsOfDirectory(
            at: rule.root,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .totalFileSizeKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
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

            // 过滤小于 1MB 的细碎描述文件，专注扫描有实质体积的模型与数据块
            guard size >= 1024 * 1024 else { continue }

            items.append(CleanupItem(
                category: .aiModels,
                path: child.path,
                kind: isDir ? .directory : .file,
                size: size,
                lastModifiedAt: values.contentModificationDate,
                riskLevel: .review,
                explanation: "\(rule.title)项：\(child.lastPathComponent)。\(rule.explanation)",
                reversible: true,
                selectedByDefault: false
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
