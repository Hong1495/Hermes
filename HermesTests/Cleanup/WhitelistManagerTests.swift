import Foundation
import Testing
@testable import Hermes

@Suite struct WhitelistManagerTests {
    @Test @MainActor func whitelistExcludesSubpaths() {
        let manager = WhitelistManager()
        let testPath = "/Users/test/sensitive-project"
        manager.addPath(testPath)

        #expect(manager.isExcluded(path: testPath))
        #expect(manager.isExcluded(path: "\(testPath)/node_modules"))
        #expect(manager.isExcluded(path: "\(testPath)/build/output.log"))
        #expect(!manager.isExcluded(path: "/Users/test/other-project"))

        manager.removePath(testPath)
        #expect(!manager.isExcluded(path: testPath))
    }
}
