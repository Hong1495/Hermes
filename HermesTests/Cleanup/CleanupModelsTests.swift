import Foundation
import Testing
@testable import Hermes

@Suite struct CleanupModelsTests {
    @Test func safeItemsAreSelectedByDefaultOnlyWhenDeclared() {
        let item = CleanupItem(
            category: .installerFiles,
            path: "/tmp/example.dmg",
            kind: .file,
            size: 128,
            riskLevel: .review,
            explanation: "安装包",
            reversible: true,
            selectedByDefault: false
        )

        #expect(item.category == .installerFiles)
        #expect(item.selectedByDefault == false)
        #expect(item.reversible)
    }

    @Test func scanSnapshotPreservesPartialScanState() {
        let snapshot = CleanupScanSnapshot(
            finishedAt: nil,
            items: [],
            skippedCount: 2,
            errorCount: 1,
            wasCancelled: true
        )

        #expect(snapshot.wasCancelled)
        #expect(snapshot.skippedCount == 2)
        #expect(snapshot.errorCount == 1)
        #expect(snapshot.finishedAt == nil)
    }
}

@Suite struct CleanupSafetyPolicyTests {
    @Test func allowsExistingFileInsideSelectedRoot() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let file = root.appendingPathComponent("cache.tmp")
        try Data("test".utf8).write(to: file)

        let decision = CleanupSafetyPolicy().evaluate(path: file.path, allowedRoot: root)

        #expect(decision.isAllowed)
        #expect(decision.normalizedPath == file.standardizedFileURL.path)
    }

    @Test func rejectsPathOutsideSelectedRoot() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let outside = root.deletingLastPathComponent().appendingPathComponent("outside.tmp")
        let decision = CleanupSafetyPolicy().evaluate(path: outside.path, allowedRoot: root)

        #expect(decision.reason == .outsideAllowedRoot)
    }

    @Test func rejectsRootDirectory() {
        let decision = CleanupSafetyPolicy().evaluate(path: "/", allowedRoot: URL(fileURLWithPath: "/"))

        #expect(decision.reason == .rootDirectory)
    }

    @Test func rejectsSymbolicLink() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let target = root.appendingPathComponent("target.tmp")
        let link = root.appendingPathComponent("link.tmp")
        try Data("test".utf8).write(to: target)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        let decision = CleanupSafetyPolicy().evaluate(path: link.path, allowedRoot: root)

        #expect(decision.reason == .symbolicLink)
    }
}
