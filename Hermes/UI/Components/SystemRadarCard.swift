import SwiftUI

struct SystemRadarCard: View {
    @ObservedObject var monitor: SystemMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            HStack {
                Label("系统实时状态", systemImage: "waveform.path.ecg")
                    .font(.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Text("运行时间: \(monitor.metrics.uptimeFormatted)")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }

            HStack(spacing: Theme.Spacing.medium) {
                // CPU 负载 — 语义色：绿 < 50%，黄 50-80%，红 > 80%
                MetricGaugeBlock(
                    title: "CPU 负载",
                    valueString: "\(Int(monitor.metrics.cpuUsagePercent * 100))%",
                    percentage: monitor.metrics.cpuUsagePercent,
                    color: gaugeColor(percent: monitor.metrics.cpuUsagePercent, warning: 0.5, danger: 0.8),
                    icon: "cpu"
                )

                // 内存压力 — 语义色：绿 < 60%，黄 60-85%，红 > 85%
                MetricGaugeBlock(
                    title: "内存占用",
                    valueString: "\(Int(monitor.metrics.memoryUsagePercent * 100))%",
                    percentage: monitor.metrics.memoryUsagePercent,
                    color: gaugeColor(percent: monitor.metrics.memoryUsagePercent, warning: 0.6, danger: 0.85),
                    icon: "memorychip"
                )

                // 电池 / 电源
                if let battery = monitor.metrics.batteryPercent {
                    MetricGaugeBlock(
                        title: monitor.metrics.isCharging ? "充电中" : "电池电量",
                        valueString: "\(battery)%",
                        percentage: Double(battery) / 100.0,
                        color: battery < 20 ? Theme.Colors.warning : Theme.Colors.success,
                        icon: monitor.metrics.isCharging ? "bolt.batteryblock.fill" : "battery.100"
                    )
                } else {
                    MetricGaugeBlock(
                        title: "电源状态",
                        valueString: "外接电源",
                        percentage: 1.0,
                        color: Theme.Colors.success,
                        icon: "powerplug.fill"
                    )
                }

                MetricGaugeBlock(
                    title: "网络流量",
                    valueString: "↓ \(rate(monitor.metrics.networkDownloadBytesPerSecond))",
                    percentage: min(1, Double(monitor.metrics.networkDownloadBytesPerSecond) / 10_000_000),
                    color: Theme.Colors.accent,
                    icon: "network"
                )
            }
        }
        .glassCard(cornerRadius: Theme.CornerRadius.large, padding: Theme.Spacing.large)
    }

    /// Maps a 0…1 percentage to a semantic health color.
    private func gaugeColor(percent: Double, warning: Double, danger: Double) -> Color {
        if percent > danger { return Theme.Colors.danger }
        if percent > warning { return Theme.Colors.warning }
        return Theme.Colors.success
    }

    private func rate(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .binary) + "/s"
    }
}

private struct MetricGaugeBlock: View {
    let title: String
    let valueString: String
    let percentage: Double
    let color: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                Text(valueString)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Theme.Colors.panelBackground)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(color)
                        .frame(width: max(4, CGFloat(min(percentage, 1.0)) * geo.size.width))
                }
            }
            .frame(height: 6)
        }
        .padding(Theme.Spacing.medium)
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.panelBackground.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
