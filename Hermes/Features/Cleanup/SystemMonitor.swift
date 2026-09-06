import Combine
import Foundation
import IOKit.ps
import Darwin

struct SystemMetrics: Equatable, Sendable {
    var cpuUsagePercent: Double = 0
    var totalMemoryBytes: UInt64 = 0
    var usedMemoryBytes: UInt64 = 0
    var freeMemoryBytes: UInt64 = 0
    var wiredMemoryBytes: UInt64 = 0
    var compressedMemoryBytes: UInt64 = 0
    var uptimeFormatted: String = ""
    var batteryPercent: Int? = nil
    var isCharging: Bool = false
    var batteryCycleCount: Int? = nil
    var batteryHealth: String? = nil
    var networkDownloadBytesPerSecond: UInt64 = 0
    var networkUploadBytesPerSecond: UInt64 = 0

    var memoryUsagePercent: Double {
        totalMemoryBytes > 0 ? Double(usedMemoryBytes) / Double(totalMemoryBytes) : 0
    }
}

@MainActor
final class SystemMonitor: ObservableObject {
    @Published private(set) var metrics = SystemMetrics()
    private var timer: Timer?
    private var previousCPULoad: host_cpu_load_info?
    private var previousNetworkTotals: (download: UInt64, upload: UInt64)?

    init() {
        refreshMetrics()
        startMonitoring()
    }

    deinit {
        timer?.invalidate()
    }

    func startMonitoring() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshMetrics()
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func refreshMetrics() {
        var m = SystemMetrics()
        m.cpuUsagePercent = calculateCPUUsage()
        let mem = calculateMemoryUsage()
        m.totalMemoryBytes = mem.total
        m.usedMemoryBytes = mem.used
        m.freeMemoryBytes = mem.free
        m.wiredMemoryBytes = mem.wired
        m.compressedMemoryBytes = mem.compressed
        m.uptimeFormatted = calculateUptime()
        let battery = readBatteryInfo()
        m.batteryPercent = battery.percent
        m.isCharging = battery.isCharging
        m.batteryCycleCount = battery.cycles
        m.batteryHealth = battery.health
        let network = calculateNetworkRate()
        m.networkDownloadBytesPerSecond = network.download
        m.networkUploadBytesPerSecond = network.upload
        self.metrics = m
    }

    private func calculateNetworkRate() -> (download: UInt64, upload: UInt64) {
        var totals = (download: UInt64(0), upload: UInt64(0))
        var cursor: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&cursor) == 0, let first = cursor else { return (0, 0) }
        defer { freeifaddrs(first) }
        var current: UnsafeMutablePointer<ifaddrs>? = first
        while let interface = current {
            if interface.pointee.ifa_addr?.pointee.sa_family == UInt8(AF_LINK),
               let data = interface.pointee.ifa_data?.assumingMemoryBound(to: if_data.self).pointee {
                totals.download += UInt64(data.ifi_ibytes)
                totals.upload += UInt64(data.ifi_obytes)
            }
            current = interface.pointee.ifa_next
        }
        defer { previousNetworkTotals = totals }
        guard let previous = previousNetworkTotals else { return (0, 0) }
        return (
            download: totals.download >= previous.download ? (totals.download - previous.download) / 2 : 0,
            upload: totals.upload >= previous.upload ? (totals.upload - previous.upload) / 2 : 0
        )
    }

    // MARK: - CPU Load
    private func calculateCPUUsage() -> Double {
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        var cpuLoadInfo = host_cpu_load_info()

        let result = withUnsafeMutablePointer(to: &cpuLoadInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }

        guard let prev = previousCPULoad else {
            previousCPULoad = cpuLoadInfo
            return 0
        }

        let userDiff = Double(cpuLoadInfo.cpu_ticks.0 - prev.cpu_ticks.0)
        let sysDiff = Double(cpuLoadInfo.cpu_ticks.1 - prev.cpu_ticks.1)
        let idleDiff = Double(cpuLoadInfo.cpu_ticks.2 - prev.cpu_ticks.2)
        let niceDiff = Double(cpuLoadInfo.cpu_ticks.3 - prev.cpu_ticks.3)
        let total = userDiff + sysDiff + idleDiff + niceDiff

        previousCPULoad = cpuLoadInfo
        guard total > 0 else { return 0 }

        let active = userDiff + sysDiff + niceDiff
        return min(max(active / total, 0.0), 1.0)
    }

    // MARK: - Memory
    private func calculateMemoryUsage() -> (total: UInt64, used: UInt64, free: UInt64, wired: UInt64, compressed: UInt64) {
        let total = ProcessInfo.processInfo.physicalMemory
        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)

        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS, pageSize > 0 else {
            return (total, total / 2, total / 2, 0, 0)
        }

        let freeBytes = UInt64(vmStats.free_count) * UInt64(pageSize)
        let activeBytes = UInt64(vmStats.active_count) * UInt64(pageSize)
        let inactiveBytes = UInt64(vmStats.inactive_count) * UInt64(pageSize)
        let wiredBytes = UInt64(vmStats.wire_count) * UInt64(pageSize)
        let compressedBytes = UInt64(vmStats.compressor_page_count) * UInt64(pageSize)

        let usedBytes = activeBytes + wiredBytes + compressedBytes
        return (total, min(usedBytes, total), freeBytes + inactiveBytes, wiredBytes, compressedBytes)
    }

    // MARK: - Uptime
    private func calculateUptime() -> String {
        var bootTime = timeval()
        var size = MemoryLayout<timeval>.stride
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]

        guard sysctl(&mib, 2, &bootTime, &size, nil, 0) == 0 else {
            return "未知"
        }

        let now = Date().timeIntervalSince1970
        let boot = Double(bootTime.tv_sec)
        let diff = max(0, Int(now - boot))

        let days = diff / 86400
        let hours = (diff % 86400) / 3600
        let minutes = (diff % 3600) / 60

        if days > 0 {
            return "\(days) 天 \(hours) 小时"
        } else if hours > 0 {
            return "\(hours) 小时 \(minutes) 分钟"
        } else {
            return "\(max(1, minutes)) 分钟"
        }
    }

    // MARK: - Battery Info
    private func readBatteryInfo() -> (percent: Int?, isCharging: Bool, cycles: Int?, health: String?) {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              !sources.isEmpty else {
            return (nil, false, nil, nil)
        }

        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }

            let isPresent = desc[kIOPSIsPresentKey] as? Bool ?? false
            guard isPresent else { continue }

            let currentCap = desc[kIOPSCurrentCapacityKey] as? Int
            let maxCap = desc[kIOPSMaxCapacityKey] as? Int ?? 100
            let isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false

            var percent: Int? = nil
            if let cur = currentCap, maxCap > 0 {
                percent = Int((Double(cur) / Double(maxCap)) * 100.0)
            }

            return (percent, isCharging, nil, "良好")
        }

        return (nil, false, nil, nil)
    }
}
