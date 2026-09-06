import Foundation
import Testing
@testable import Hermes

@Suite struct BrowserCacheScannerTests {
    @Test func scannerInitializesAndRunsSafely() async {
        let scanner = BrowserCacheScanner()
        let snapshot = await scanner.scan()
        #expect(!snapshot.wasCancelled)
        #expect(snapshot.items.allSatisfy { $0.category == .browserCaches })
    }
}
