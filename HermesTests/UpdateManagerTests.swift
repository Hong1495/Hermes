import Foundation
import Testing
@testable import Hermes

@Suite struct UpdateManagerTests {

    // MARK: - Version Comparison Tests

    @Test func versionComparatorCorrectlyIdentifiesNewerVersions() {
        #expect(VersionComparator.isVersion("0.2.0", newerThan: "0.1.0"))
        #expect(VersionComparator.isVersion("0.1.1", newerThan: "0.1.0"))
        #expect(VersionComparator.isVersion("1.0.0", newerThan: "0.1.0"))
        #expect(VersionComparator.isVersion("v0.2.0", newerThan: "0.1.0"))
        #expect(VersionComparator.isVersion("v0.1.1", newerThan: "v0.1.0"))
        #expect(VersionComparator.isVersion("0.1.0.1", newerThan: "0.1.0"))
    }

    @Test func versionComparatorCorrectlyRejectsOlderOrEqualVersions() {
        #expect(!VersionComparator.isVersion("0.1.0", newerThan: "0.1.0"))
        #expect(!VersionComparator.isVersion("v0.1.0", newerThan: "0.1.0"))
        #expect(!VersionComparator.isVersion("0.1.0", newerThan: "v0.1.0"))
        #expect(!VersionComparator.isVersion("0.0.9", newerThan: "0.1.0"))
        #expect(!VersionComparator.isVersion("0.0.1", newerThan: "0.1.0"))
        #expect(!VersionComparator.isVersion("0.1.0-beta", newerThan: "0.1.0"))
    }

    @Test func versionParserHandlesPrefixesAndWhitespace() {
        #expect(VersionComparator.parse("  v1.2.3  ") == [1, 2, 3])
        #expect(VersionComparator.parse("V0.1.0") == [0, 1, 0])
        #expect(VersionComparator.parse("2.0.0-rc1") == [2, 0, 0])
    }

    // MARK: - GitHub Release JSON Parsing

    @Test func gitHubUpdateServiceParsesReleasePayload() throws {
        let json = """
        {
            "tag_name": "v0.2.0",
            "name": "Hermes 0.2.0 Update",
            "body": "Fixed bugs and enhanced liquid glass.",
            "html_url": "https://github.com/Hong1495/Hermes/releases/tag/v0.2.0",
            "published_at": "2026-09-06T12:00:00Z",
            "assets": [
                {
                    "name": "other_file.txt",
                    "browser_download_url": "https://example.com/other.txt",
                    "size": 100
                },
                {
                    "name": "Hermes-0.2.0-macOS.zip",
                    "browser_download_url": "https://github.com/Hong1495/Hermes/releases/download/v0.2.0/Hermes-0.2.0-macOS.zip",
                    "size": 3145728
                }
            ]
        }
        """.data(using: .utf8)!

        let release = try GitHubUpdateService.parseRelease(from: json)

        #expect(release.tagName == "v0.2.0")
        #expect(release.version == "0.2.0")
        #expect(release.name == "Hermes 0.2.0 Update")
        #expect(release.body.contains("Fixed bugs"))
        #expect(release.htmlURL.absoluteString == "https://github.com/Hong1495/Hermes/releases/tag/v0.2.0")
        #expect(release.assetName == "Hermes-0.2.0-macOS.zip")
        #expect(release.assetSize == 3145728)
        #expect(release.assetURL?.absoluteString.contains("Hermes-0.2.0-macOS.zip") == true)
    }

    // MARK: - UpdateManager State Transitions

    private struct MockUpdateService: UpdateServiceProtocol {
        let result: Result<ReleaseInfo, Error>

        func fetchLatestRelease() async throws -> ReleaseInfo {
            switch result {
            case .success(let release):
                return release
            case .failure(let error):
                throw error
            }
        }
    }

    @MainActor
    @Test func updateManagerDetectsNewerRelease() async throws {
        let release = ReleaseInfo(
            tagName: "v9.9.9",
            version: "9.9.9",
            name: "Future Hermes",
            body: "Major update",
            htmlURL: URL(string: "https://github.com/Hong1495/Hermes")!
        )
        let mockService = MockUpdateService(result: .success(release))
        let manager = UpdateManager(updateService: mockService)

        manager.checkForUpdates(isUserInitiated: false)

        for _ in 0..<10 {
            if manager.status != .checking { break }
            try await Task.sleep(for: .milliseconds(20))
        }

        if case .available(let found) = manager.status {
            #expect(found.version == "9.9.9")
        } else {
            Issue.record("Expected .available status, got \(manager.status)")
        }
        #expect(manager.lastCheckDate != nil)
    }

    @MainActor
    @Test func updateManagerDetectsUpToDateState() async throws {
        let release = ReleaseInfo(
            tagName: "v0.0.1",
            version: "0.0.1",
            name: "Old Hermes",
            body: "",
            htmlURL: URL(string: "https://github.com/Hong1495/Hermes")!
        )
        let mockService = MockUpdateService(result: .success(release))
        let manager = UpdateManager(updateService: mockService)

        manager.checkForUpdates(isUserInitiated: false)

        for _ in 0..<10 {
            if manager.status != .checking { break }
            try await Task.sleep(for: .milliseconds(20))
        }

        if case .upToDate = manager.status {
            // expected
        } else {
            Issue.record("Expected .upToDate status, got \(manager.status)")
        }
    }

    @MainActor
    @Test func updateManagerHandlesNetworkFailure() async throws {
        let mockService = MockUpdateService(result: .failure(URLError(.cannotConnectToHost)))
        let manager = UpdateManager(updateService: mockService)

        manager.checkForUpdates(isUserInitiated: false)

        for _ in 0..<10 {
            if manager.status != .checking { break }
            try await Task.sleep(for: .milliseconds(20))
        }

        if case .failed = manager.status {
            // expected
        } else {
            Issue.record("Expected .failed status, got \(manager.status)")
        }
    }
}
