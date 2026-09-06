import Foundation
import Testing
@testable import Hermes

@Suite struct ApplicationScannerTests {
    @Test func scannerInitializesAndDiscoversApps() async {
        let scanner = ApplicationScanner()
        let snapshot = await scanner.scan()
        #expect(!snapshot.applications.isEmpty)
        if let first = snapshot.applications.first {
            #expect(!first.name.isEmpty)
            #expect(!first.bundleIdentifier.isEmpty)
            #expect(first.totalSize >= first.bundleSize)
        }
    }
}
