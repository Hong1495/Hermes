import AppKit
import Foundation

struct DiskEntry: Identifiable, Sendable, Hashable {
    let id: String
    let name: String
    let path: String
    let size: Int64
    let isDirectory: Bool
    let itemCount: Int
    let percentage: Double

    init(
        id: String,
        name: String,
        path: String,
        size: Int64,
        isDirectory: Bool,
        itemCount: Int,
        percentage: Double = 0.0
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.size = size
        self.isDirectory = isDirectory
        self.itemCount = itemCount
        self.percentage = percentage
    }
}

struct DiskAnalysisSnapshot: Sendable {
    let rootPath: String
    let totalSize: Int64
    let totalFiles: Int
    let entries: [DiskEntry]
    let largeFiles: [DiskEntry]
    let wasCancelled: Bool
}

actor DiskAnalyzer {
    private let fileManager: FileManager
    private let maxLargeFiles: Int

    init(fileManager: FileManager = .default, maxLargeFiles: Int = 50) {
        self.fileManager = fileManager
        self.maxLargeFiles = maxLargeFiles
    }

    func analyze(root: URL) async -> DiskAnalysisSnapshot {
        let normalizedRoot = root.standardizedFileURL
        var rawEntries: [(entry: DiskEntry, size: Int64)] = []
        var largeFiles: [DiskEntry] = []
        var totalSize: Int64 = 0
        var totalFiles = 0
        var cancelled = false

        guard let children = try? fileManager.contentsOfDirectory(
            at: normalizedRoot,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .totalFileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return DiskAnalysisSnapshot(rootPath: normalizedRoot.path, totalSize: 0, totalFiles: 0, entries: [], largeFiles: [], wasCancelled: false)
        }

        for child in children {
            guard !Task.isCancelled else { cancelled = true; break }
            let result = measure(child)
            let entry = DiskEntry(
                id: child.path,
                name: child.lastPathComponent,
                path: child.path,
                size: result.size,
                isDirectory: result.isDirectory,
                itemCount: result.count
            )
            rawEntries.append((entry, result.size))
            totalSize += result.size
            totalFiles += result.count

            // 递归或浅层搜集大于 100MB 的大文件
            if !result.isDirectory && result.size >= 100 * 1024 * 1024 {
                largeFiles.append(entry)
            }
        }

        // 计算各子项在当前目录中的体积占比
        let safeTotal = max(1, totalSize)
        let entriesWithPercentage: [DiskEntry] = rawEntries.map { item in
            DiskEntry(
                id: item.entry.id,
                name: item.entry.name,
                path: item.entry.path,
                size: item.entry.size,
                isDirectory: item.entry.isDirectory,
                itemCount: item.entry.itemCount,
                percentage: Double(item.size) / Double(safeTotal)
            )
        }.sorted { $0.size > $1.size }

        return DiskAnalysisSnapshot(
            rootPath: normalizedRoot.path,
            totalSize: totalSize,
            totalFiles: totalFiles,
            entries: entriesWithPercentage,
            largeFiles: largeFiles.sorted { $0.size > $1.size }.prefix(maxLargeFiles).map { $0 },
            wasCancelled: cancelled
        )
    }

    private func measure(_ url: URL) -> (size: Int64, count: Int, isDirectory: Bool) {
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .totalFileSizeKey]) else {
            return (0, 0, false)
        }
        guard values.isDirectory == true else {
            return (Int64(values.fileSize ?? 0), 1, false)
        }
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .totalFileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return (0, 0, true) }

        var size: Int64 = 0
        var count = 0
        for case let child as URL in enumerator {
            guard let childValues = try? child.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .totalFileSizeKey]) else { continue }
            if childValues.isDirectory != true {
                size += Int64(childValues.fileSize ?? 0)
                count += 1
            }
        }
        return (size, count, true)
    }
}
