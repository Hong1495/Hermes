import SwiftUI

struct StorageUsageBar: View {
    let cleanableBytes: Int64

    @State private var totalBytes: Int64 = 0
    @State private var freeBytes: Int64 = 0

    private var usedBytes: Int64 {
        max(0, totalBytes - freeBytes)
    }

    private var usedPercent: Double {
        totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) : 0
    }

    private var freePercent: Double {
        totalBytes > 0 ? Double(freeBytes) / Double(totalBytes) : 0
    }

    private var cleanablePercent: Double {
        totalBytes > 0 ? min(Double(cleanableBytes) / Double(totalBytes), usedPercent) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Macintosh HD")
                        .font(.headline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("共 \(formatBytes(totalBytes)) · 可用 \(formatBytes(freeBytes))")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()
                if cleanableBytes > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.caption)
                        Text("可清理 \(formatBytes(cleanableBytes))")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(Theme.Colors.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Theme.Colors.accentSoft.opacity(0.4))
                    .clipShape(Capsule())
                }
            }

            // 分段进度条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // 底槽（可用空间）
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Theme.Colors.panelBackground)

                    HStack(spacing: 2) {
                        // 已用不可清理空间
                        let regularUsedWidth = max(0, (usedPercent - cleanablePercent) * geo.size.width)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Theme.Colors.textSecondary.opacity(0.45))
                            .frame(width: regularUsedWidth)

                        // 扫描发现的可清理空间（高亮强调）
                        if cleanablePercent > 0 {
                            let cleanWidth = max(4, cleanablePercent * geo.size.width)
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Theme.Colors.accent)
                                .frame(width: cleanWidth)
                        }

                        // 剩余可用空间
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(height: 12)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            // 图例说明
            HStack(spacing: Theme.Spacing.large) {
                LegendItem(color: Theme.Colors.textSecondary.opacity(0.45), title: "系统与应用已用 (\(formatBytes(usedBytes - cleanableBytes)))")
                if cleanableBytes > 0 {
                    LegendItem(color: Theme.Colors.accent, title: "待清理项 (\(formatBytes(cleanableBytes)))")
                }
                LegendItem(color: Theme.Colors.panelBackground, title: "可用空间 (\(formatBytes(freeBytes)))")
                Spacer()
            }
            .font(.caption2)
            .foregroundStyle(Theme.Colors.textTertiary)
        }
        .padding(Theme.Spacing.large)
        .background(Theme.Colors.panelElevated)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.CornerRadius.large, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.45), Color.white.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .onAppear {
            updateDiskMetrics()
        }
    }

    private func updateDiskMetrics() {
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/") {
            self.totalBytes = (attrs[.systemSize] as? Int64) ?? 0
            self.freeBytes = (attrs[.systemFreeSize] as? Int64) ?? 0
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: max(0, bytes), countStyle: .file)
    }
}

private struct LegendItem: View {
    let color: Color
    let title: String

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(title)
        }
    }
}
