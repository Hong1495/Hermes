import Foundation
import Testing
@testable import Hermes

@Suite struct InstallerScannerTests {
    @Test func findsSupportedInstallersAndIgnoresOtherFiles() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        try Data(repeating: 1, count: 32).write(to: root.appendingPathComponent("Example.dmg"))
        try Data(repeating: 2, count: 16).write(to: root.appendingPathComponent("archive.zip"))
        try Data(repeating: 3, count: 8).write(to: root.appendingPathComponent("Setup.PKG"))

        let snapshot = await InstallerScanner().scan(roots: [root])

        #expect(snapshot.items.count == 3)
        let filenames = snapshot.items.map { URL(fileURLWithPath: $0.path).lastPathComponent }
        #expect(filenames.contains("Example.dmg"))
        #expect(filenames.contains("Setup.PKG"))
        #expect(filenames.contains("archive.zip"))
        #expect(snapshot.items.allSatisfy { $0.category == .installerFiles })
        #expect(snapshot.items.allSatisfy { !$0.selectedByDefault })
    }

    @Test func rejectsInstallerSymlink() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let target = root.appendingPathComponent("target.dmg")
        let link = root.appendingPathComponent("linked.dmg")
        try Data(repeating: 1, count: 4).write(to: target)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        let snapshot = await InstallerScanner().scan(roots: [root])

        let filenames = snapshot.items.map { URL(fileURLWithPath: $0.path).lastPathComponent }
        #expect(filenames.contains("target.dmg"))
        #expect(!filenames.contains("linked.dmg"))
        #expect(snapshot.skippedCount >= 1)
    }

    @Test func sortsInstallersByDescendingSizeAcrossRoots() async throws {
        let first = try makeTemporaryRoot()
        let second = try makeTemporaryRoot()
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
        }

        try Data(repeating: 1, count: 5).write(to: first.appendingPathComponent("small.iso"))
        try Data(repeating: 2, count: 50).write(to: second.appendingPathComponent("large.xip"))

        let snapshot = await InstallerScanner().scan(roots: [first, second])

        #expect(snapshot.items.count == 2)
        #expect(snapshot.items[0].size >= snapshot.items[1].size)
        #expect(snapshot.items[0].path.hasSuffix("large.xip"))
    }

    private func makeTemporaryRoot() throws -> URL {
        let basePath = (FileManager.default.temporaryDirectory.path as NSString).resolvingSymlinksInPath
        let root = URL(fileURLWithPath: basePath, isDirectory: true)
            .appendingPathComponent("HermesInstallerScannerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
