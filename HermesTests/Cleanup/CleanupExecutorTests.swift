import Foundation
import Testing
@testable import Hermes

@Suite struct CleanupExecutorTests {
    @Test func movesUnchangedFileToTrash() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("remove-me.tmp")
        try Data(repeating: 1, count: 32).write(to: file)
        let item = makeItem(path: file.path, size: 32)
        let plan = CleanupPlan(scanID: UUID(), items: [item])

        let summary = await CleanupExecutor().execute(plan, allowedRoots: [root])

        #expect(summary.movedCount == 1)
        #expect(summary.results.first?.status == .movedToTrash)
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test func movesDirectoryToTrashSuccessfully() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let dir = root.appendingPathComponent("build-dir")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let subfile = dir.appendingPathComponent("sub.tmp")
        try Data(repeating: 2, count: 64).write(to: subfile)

        let item = CleanupItem(
            category: .developerArtifacts,
            path: dir.path,
            kind: .directory,
            size: 64,
            riskLevel: .review,
            explanation: "测试目录",
            reversible: true,
            selectedByDefault: false
        )
        let plan = CleanupPlan(scanID: UUID(), items: [item])

        let summary = await CleanupExecutor().execute(plan, allowedRoots: [root])

        #expect(summary.movedCount == 1)
        #expect(summary.results.first?.status == .movedToTrash)
        #expect(!FileManager.default.fileExists(atPath: dir.path))
    }

    @Test func skipsFileThatChangedAfterScan() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("changed.tmp")
        try Data(repeating: 1, count: 16).write(to: file)
        let item = makeItem(path: file.path, size: 16)
        try Data(repeating: 1, count: 24).write(to: file)

        let summary = await CleanupExecutor().execute(
            CleanupPlan(scanID: UUID(), items: [item]),
            allowedRoots: [root]
        )

        #expect(summary.results.first?.status == .skippedChanged)
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test func rejectsPathOutsideAllowedRoots() async throws {
        let root = try makeRoot()
        let outside = root.deletingLastPathComponent().appendingPathComponent("outside.tmp")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: outside)
        }
        try Data(repeating: 1, count: 8).write(to: outside)
        let item = makeItem(path: outside.path, size: 8)

        let summary = await CleanupExecutor().execute(
            CleanupPlan(scanID: UUID(), items: [item]),
            allowedRoots: [root]
        )

        #expect(summary.results.first?.status == .skippedUnsafe)
        #expect(FileManager.default.fileExists(atPath: outside.path))
    }

    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("HermesExecutor-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func makeItem(path: String, size: Int64) -> CleanupItem {
        CleanupItem(
            category: .installerFiles,
            path: path,
            kind: .file,
            size: size,
            riskLevel: .review,
            explanation: "测试",
            reversible: true,
            selectedByDefault: false
        )
    }
}
