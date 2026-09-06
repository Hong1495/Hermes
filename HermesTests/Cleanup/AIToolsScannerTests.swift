import Foundation
import Testing
@testable import Hermes

@Suite struct AIToolsScannerTests {
    @Test func scannerRunsSafely() async {
        let scanner = AIToolsScanner()
        let snapshot = await scanner.scan()
        #expect(!snapshot.wasCancelled)
        #expect(snapshot.items.allSatisfy { $0.category == .aiModels })
    }
}
