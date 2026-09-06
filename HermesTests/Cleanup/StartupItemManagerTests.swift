import Foundation
import Testing
@testable import Hermes

@Suite struct StartupItemManagerTests {
    @Test func scannerScansWithoutCrashing() async {
        let manager = StartupItemManager()
        let items = await manager.scanStartupItems()
        for item in items {
            #expect(!item.id.isEmpty)
            #expect(!item.name.isEmpty)
            #expect(!item.label.isEmpty)
            #expect(!item.path.isEmpty)
        }
    }
}
