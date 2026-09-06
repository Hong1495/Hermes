import Foundation

enum CleanupExecutionStatus: String, Codable, Sendable {
    case movedToTrash
    case skippedChanged
    case skippedUnsafe
    case failed
}

struct CleanupExecutionResult: Codable, Identifiable, Sendable {
    let id: UUID
    let planID: UUID
    let path: String
    let status: CleanupExecutionStatus
    let size: Int64
    let message: String

    nonisolated init(
        id: UUID = UUID(),
        planID: UUID,
        path: String,
        status: CleanupExecutionStatus,
        size: Int64,
        message: String
    ) {
        self.id = id
        self.planID = planID
        self.path = path
        self.status = status
        self.size = size
        self.message = message
    }
}

struct CleanupExecutionSummary: Sendable {
    let planID: UUID
    let results: [CleanupExecutionResult]

    nonisolated var movedCount: Int {
        results.filter { $0.status == .movedToTrash }.count
    }

    nonisolated var movedBytes: Int64 {
        results.filter { $0.status == .movedToTrash }.reduce(0) { $0 + $1.size }
    }
}

actor CleanupExecutor {
    private let fileManager: FileManager
    private let safetyPolicy: CleanupSafetyPolicy

    init(fileManager: FileManager = .default, safetyPolicy: CleanupSafetyPolicy? = nil) {
        self.fileManager = fileManager
        self.safetyPolicy = safetyPolicy ?? CleanupSafetyPolicy(fileManager: fileManager)
    }

    func emptyTrash(items: [CleanupItem]) async -> Int {
        var removed = 0
        let trashRoot = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".Trash").standardizedFileURL.path + "/"
        for item in items where item.category == .trash {
            guard !Task.isCancelled else { break }
            let url = URL(fileURLWithPath: item.path).standardizedFileURL
            guard url.path.hasPrefix(trashRoot) else { continue }
            if (try? fileManager.removeItem(at: url)) != nil { removed += 1 }
        }
        return removed
    }

    func execute(_ plan: CleanupPlan, allowedRoots: [URL]) async -> CleanupExecutionSummary {
        var results: [CleanupExecutionResult] = []

        for item in plan.items {
            guard !Task.isCancelled else { break }
            let pathURL = URL(fileURLWithPath: item.path)
            guard let root = allowedRoots.first(where: { isWithin(pathURL, root: $0) }) else {
                results.append(.init(
                    planID: plan.id,
                    path: item.path,
                    status: .skippedUnsafe,
                    size: item.size,
                    message: "项目不在本次扫描允许的范围内。"
                ))
                continue
            }

            let decision = safetyPolicy.evaluate(path: item.path, allowedRoot: root)
            guard decision.isAllowed else {
                results.append(.init(
                    planID: plan.id,
                    path: item.path,
                    status: .skippedUnsafe,
                    size: item.size,
                    message: "执行前安全校验未通过：\(decision.reason.rawValue)。"
                ))
                continue
            }

            guard let values = try? pathURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey, .totalFileSizeKey]),
                  values.isSymbolicLink != true else {
                results.append(.init(
                    planID: plan.id,
                    path: item.path,
                    status: .skippedUnsafe,
                    size: item.size,
                    message: "目标路径不存在或为软链接，已跳过。"
                ))
                continue
            }

            if values.isDirectory != true {
                let currentSize = Int64(values.totalFileSize ?? values.fileSize ?? 0)
                guard currentSize == item.size else {
                    results.append(.init(
                        planID: plan.id,
                        path: item.path,
                        status: .skippedChanged,
                        size: item.size,
                        message: "文件在扫描后发生变化，请重新扫描。"
                    ))
                    continue
                }
            }

            do {
                try fileManager.trashItem(at: pathURL, resultingItemURL: nil)
                results.append(.init(
                    planID: plan.id,
                    path: item.path,
                    status: .movedToTrash,
                    size: item.size,
                    message: "已移入废纸篓，可从废纸篓恢复。"
                ))
            } catch {
                results.append(.init(
                    planID: plan.id,
                    path: item.path,
                    status: .failed,
                    size: item.size,
                    message: error.localizedDescription
                ))
            }
        }

        return CleanupExecutionSummary(planID: plan.id, results: results)
    }


    private func isWithin(_ candidate: URL, root: URL) -> Bool {
        let candidatePath = candidate.standardizedFileURL.path
        let rootPath = root.standardizedFileURL.path
        return candidatePath == rootPath || candidatePath.hasPrefix(rootPath.hasSuffix("/") ? rootPath : rootPath + "/")
    }
}
