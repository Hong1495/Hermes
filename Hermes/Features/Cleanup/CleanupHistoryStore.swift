import Foundation

struct CleanupHistoryEntry: Codable, Identifiable, Sendable {
    let id: UUID
    let planID: UUID
    let createdAt: Date
    let movedCount: Int
    let movedBytes: Int64
    let skippedCount: Int
    let failedCount: Int

    init(
        id: UUID = UUID(),
        planID: UUID,
        createdAt: Date = Date(),
        movedCount: Int,
        movedBytes: Int64,
        skippedCount: Int,
        failedCount: Int
    ) {
        self.id = id
        self.planID = planID
        self.createdAt = createdAt
        self.movedCount = movedCount
        self.movedBytes = movedBytes
        self.skippedCount = skippedCount
        self.failedCount = failedCount
    }
}

actor CleanupHistoryStore {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) {
        let directory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Hermes", isDirectory: true)
        self.fileURL = directory.appendingPathComponent("cleanup-history.json")
    }

    func entries() -> [CleanupHistoryEntry] {
        guard let data = try? Data(contentsOf: fileURL),
              let entries = try? decoder.decode([CleanupHistoryEntry].self, from: data) else {
            return []
        }
        return entries.sorted { $0.createdAt > $1.createdAt }
    }

    func append(_ entry: CleanupHistoryEntry) {
        var current = entries()
        current.insert(entry, at: 0)
        guard let data = try? encoder.encode(Array(current.prefix(100))) else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }
}
