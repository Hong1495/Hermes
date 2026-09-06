import Foundation
import Testing
@testable import Hermes

@Suite struct SystemMonitorTests {
    @Test @MainActor func systemMonitorGathersRealMetrics() {
        let monitor = SystemMonitor()
        monitor.refreshMetrics()

        let metrics = monitor.metrics
        #expect(metrics.totalMemoryBytes > 0)
        #expect(metrics.usedMemoryBytes > 0)
        #expect(metrics.memoryUsagePercent >= 0.0 && metrics.memoryUsagePercent <= 1.0)
        #expect(metrics.cpuUsagePercent >= 0.0 && metrics.cpuUsagePercent <= 1.0)
        #expect(!metrics.uptimeFormatted.isEmpty)
    }
}
