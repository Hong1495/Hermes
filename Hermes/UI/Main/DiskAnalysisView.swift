import Combine
import SwiftUI

struct DiskAnalysisView: View {
    @StateObject private var viewModel = DiskAnalysisViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.large) {
            VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                Text("磁盘分析")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("层级穿透查看目录占用与大文件，直接定位并清理空间消耗源。")
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            HStack(spacing: Theme.Spacing.medium) {
                LiquidGlassSegmentedControl(
                    items: DiskViewMode.allCases,
                    selection: $viewModel.selectedMode,
                    title: \.title,
                    icon: { mode in
                        switch mode {
                        case .explorer: "folder"
                        case .largeFiles: "flame"
                        }
                    }
                )

                Spacer()

                Button {
                    Task { await viewModel.analyzeHome() }
                } label: {
                    Image(systemName: "house")
                }
                .buttonStyle(.glass)
                .help("回到主目录")
                .disabled(viewModel.isAnalyzing)
            }

            // 面包屑导航与返回上一级
            HStack(spacing: Theme.Spacing.medium) {
                Button {
                    Task { await viewModel.goBack() }
                } label: {
                    Label("返回", systemImage: "arrow.backward")
                }
                .modernStyle(.secondary)
                .controlSize(.small)
                .disabled(!viewModel.canGoBack || viewModel.isAnalyzing)

                BreadcrumbBar(breadcrumbs: viewModel.breadcrumbs) { url in
                    Task { await viewModel.goToBreadcrumb(url) }
                }
            }
            .padding(Theme.Spacing.small)
            .background(Theme.Colors.panelElevated)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Theme.Colors.glassBorder, lineWidth: 1)
            }

            if viewModel.isAnalyzing {
                VStack(spacing: Theme.Spacing.medium) {
                    ProgressView("正在计算空间占用与文件分布…")
                }
                .frame(maxWidth: .infinity, minHeight: 300)
            } else if let snapshot = viewModel.snapshot {
                // 概览指标卡片
                HStack(spacing: Theme.Spacing.large) {
                    MetricCard(
                        title: "当前目录大小",
                        value: ByteCountFormatter.string(fromByteCount: snapshot.totalSize, countStyle: .file),
                        detail: viewModel.currentURL.lastPathComponent,
                        systemImage: "internaldrive"
                    )
                    MetricCard(
                        title: "项目数量",
                        value: "\(snapshot.entries.count) 个子项",
                        detail: "共包含 \(snapshot.totalFiles) 个文件",
                        systemImage: "folder"
                    )
                }

                switch viewModel.selectedMode {
                case .explorer:
                    ExplorerView(viewModel: viewModel, snapshot: snapshot)
                case .largeFiles:
                    LargeFilesView(viewModel: viewModel, snapshot: snapshot)
                }
            } else {
                PlaceholderSectionView(title: "准备分析", message: "点击分析用户目录，查看空间主要占用位置。", systemImage: "internaldrive")
            }
        }
        .task { await viewModel.loadIfNeeded() }
    }
}

private struct ExplorerView: View {
    @ObservedObject var viewModel: DiskAnalysisViewModel
    let snapshot: DiskAnalysisSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            Text("子项分布与占用")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.Colors.textPrimary)

            if snapshot.entries.isEmpty {
                Text("此目录为空或无读取权限。")
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(.vertical, Theme.Spacing.large)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(snapshot.entries) { entry in
                            DiskEntryRow(
                                entry: entry,
                                onNavigate: {
                                    Task { await viewModel.navigateTo(url: URL(fileURLWithPath: entry.path)) }
                                },
                                onReveal: { viewModel.revealInFinder(path: entry.path) },
                                onTrash: {
                                    Task { await viewModel.moveToTrash(path: entry.path) }
                                }
                            )
                        }
                    }
                }
            }
        }
    }
}

private struct LargeFilesView: View {
    @ObservedObject var viewModel: DiskAnalysisViewModel
    let snapshot: DiskAnalysisSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            Text("大于 100MB 的文件 (\(snapshot.largeFiles.count))")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.Colors.textPrimary)

            if snapshot.largeFiles.isEmpty {
                Text("当前目录下未发现大于 100MB 的文件。")
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(.vertical, Theme.Spacing.large)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(snapshot.largeFiles) { file in
                            HStack(spacing: Theme.Spacing.medium) {
                                Image(systemName: "doc.fill")
                                    .foregroundStyle(Theme.Colors.accent)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(file.name)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Theme.Colors.textPrimary)
                                    Text(file.path)
                                        .font(.caption2)
                                        .foregroundStyle(Theme.Colors.textTertiary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                Text(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.Colors.textPrimary)

                                Button {
                                    viewModel.revealInFinder(path: file.path)
                                } label: {
                                    Image(systemName: "arrow.up.right.square")
                                }
                                .buttonStyle(.plain)
                                .help("在访达中显示")

                                Button {
                                    Task { await viewModel.moveToTrash(path: file.path) }
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(Theme.Colors.danger)
                                }
                                .buttonStyle(.plain)
                                .help("移入废纸篓")
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Theme.Colors.panelElevated)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Theme.Colors.glassBorder.opacity(0.4), lineWidth: 1)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct DiskEntryRow: View {
    let entry: DiskEntry
    let onNavigate: () -> Void
    let onReveal: () -> Void
    let onTrash: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.medium) {
            // 图标与名称
            Button {
                if entry.isDirectory { onNavigate() }
            } label: {
                HStack(spacing: Theme.Spacing.small) {
                    Image(systemName: entry.isDirectory ? "folder.fill" : "doc.fill")
                        .foregroundStyle(entry.isDirectory ? Theme.Colors.accent : Theme.Colors.textSecondary)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(entry.name)
                                .font(.subheadline.weight(entry.isDirectory ? .semibold : .regular))
                                .foregroundStyle(Theme.Colors.textPrimary)
                            if entry.isDirectory {
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.Colors.textTertiary)
                            }
                        }
                        if entry.isDirectory {
                            Text("\(entry.itemCount) 个项目")
                                .font(.caption2)
                                .foregroundStyle(Theme.Colors.textTertiary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // 占比进度条与容量
            HStack(spacing: Theme.Spacing.medium) {
                // 占比微进度条
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Theme.Colors.panelBackground)
                        .frame(width: 80, height: 6)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Theme.Colors.accent)
                        .frame(width: max(2, CGFloat(entry.percentage) * 80), height: 6)
                }

                Text("\(Int(entry.percentage * 100))%")
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .frame(width: 34, alignment: .trailing)

                Text(ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(width: 80, alignment: .trailing)

                Button(action: onReveal) {
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                .buttonStyle(.plain)
                .help("在访达中显示")

                Button(action: onTrash) {
                    Image(systemName: "trash")
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                .buttonStyle(.plain)
                .help("移入废纸篓")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Theme.Colors.panelElevated)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Theme.Colors.glassBorder.opacity(0.35), lineWidth: 1)
        }
    }
}
