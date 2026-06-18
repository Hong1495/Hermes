import Foundation
import Testing
@testable import Hermes

@Suite struct ScreenshotExportServiceTests {
    @Test func uniqueDestinationURLNoConflict() {
        // Create a temp directory for testing
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("HermesTest_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let url = tmp.appendingPathComponent("test.png")
        let result = ScreenshotExportService.shared.uniqueDestinationURL(for: url)
        #expect(result == url, "Non-existing path should return the same URL")
    }

    @Test func uniqueDestinationURLAddsSuffixOnConflict() {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("HermesTest_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        // Create "test.png"
        let url = tmp.appendingPathComponent("test.png")
        FileManager.default.createFile(atPath: url.path, contents: Data())

        let result = ScreenshotExportService.shared.uniqueDestinationURL(for: url)

        #expect(result.lastPathComponent == "test 2.png")
    }

    @Test func uniqueDestinationURLIncrementsCorrectly() {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("HermesTest_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let url = tmp.appendingPathComponent("test.png")
        let url2 = tmp.appendingPathComponent("test 2.png")
        let url3 = tmp.appendingPathComponent("test 3.png")

        FileManager.default.createFile(atPath: url.path, contents: Data())
        FileManager.default.createFile(atPath: url2.path, contents: Data())

        let result = ScreenshotExportService.shared.uniqueDestinationURL(for: url)

        // Should skip "test 2.png" and return "test 3.png"
        #expect(result.lastPathComponent == "test 3.png")
        #expect(!FileManager.default.fileExists(atPath: url3.path))
    }
}
