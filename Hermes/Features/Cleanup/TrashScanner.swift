import Foundation

actor TrashScanner {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func scan() async -> CleanupScanSnapshot {
        let startedAt = Date()
        let trashURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".Trash", isDirectory: true)

        guard fileManager.fileExists(atPath: trashURL.path),
              let contents = try? fileManager.contentsOfDirectory(
                at: trashURL,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .totalFileSizeKey, .contentModificationDateKey],
                options: []
              ) else {
            return CleanupScanSnapshot(startedAt: startedAt, finishedAt: Date())
        }

        var items: [CleanupItem] = []

        for url in contents {
            guard !Task.isCancelled else {
                return CleanupScanSnapshot(startedAt: startedAt, finishedAt: Date(), items: items, wasCancelled: true)
            }

            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .totalFileSizeKey, .contentModificationDateKey]) else {
                continue
            }

            let isDir = values.isDirectory == true
            let size = isDir ? directorySize(url) : Int64(values.totalFileSize ?? values.fileSize ?? 0)

            items.append(CleanupItem(
                category: .trash,
                path: url.path,
                kind: isDir ? .directory : .file,
                size: max(0, size),
                lastModifiedAt: values.contentModificationDate,
                riskLevel: .review,
                explanation: "废纸篓中的文件，清倒后将永久删除不可恢复。",
                reversible: false,
                selectedByDefault: false
            ))
        }

        return CleanupScanSnapshot(
            startedAt: startedAt,
            finishedAt: Date(),
            items: items.sorted { $0.size > $1.size }
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
}
