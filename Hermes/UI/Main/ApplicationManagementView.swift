import AppKit
import Combine
import SwiftUI

struct ApplicationManagementView: View {
    @StateObject private var viewModel = ApplicationManagementViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.large) {
            VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                Text("应用管理")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("彻底卸载应用及关联隐藏文件，或清理已删除应用的残留配置。")
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            // 模式切换和刷新是同一层级的页面工具，单独成行避免挤压标题。
            HStack(spacing: Theme.Spacing.medium) {
                LiquidGlassSegmentedControl(
                    items: AppManagementTab.allCases,
                    selection: $viewModel.selectedTab,
                    title: \.title,
                    icon: { tab in
                        switch tab {
                        case .installedApps: "square.grid.2x2"
                        case .residuals: "trash"
                        case .startupItems: "bolt.badge.clock"
                        }
                    }
                )

                Spacer()

                Button {
                    Task { await viewModel.scan() }
                } label: {
                    if viewModel.isScanning {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.glass)
                .disabled(viewModel.isScanning)
                .help("重新扫描")
            }

            // 操作结果反馈提示条
            if let msg = viewModel.lastOperationMessage {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.Colors.success)
                    Text(msg)
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Spacer()
                }
                .padding(Theme.Spacing.medium)
                .background(Theme.Colors.accentSoft.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small, style: .continuous))
            }

            if viewModel.isScanning && viewModel.snapshot == nil {
                VStack(spacing: Theme.Spacing.medium) {
                    ProgressView("正在扫描已安装应用及关联支持数据…")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                switch viewModel.selectedTab {
                case .installedApps:
                    InstalledAppsSplitView(viewModel: viewModel)
                case .residuals:
                    ResidualsView(viewModel: viewModel)
                case .startupItems:
                    StartupItemsView(viewModel: viewModel)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await viewModel.loadIfNeeded() }
    }
}

private struct AppMetricBadge: View {
    let title: String
    let value: String
    let isPrimary: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(Theme.Colors.textTertiary)
                .lineLimit(1)
            Text(value)
                .font(.caption.weight(isPrimary ? .bold : .medium))
                .foregroundStyle(isPrimary ? Theme.Colors.accent : Theme.Colors.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Theme.Colors.panelBackground.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

private struct InstalledAppsSplitView: View {
    @ObservedObject var viewModel: ApplicationManagementViewModel

    var body: some View {
        HStack(spacing: 0) {
            // 左侧：搜索框与应用列表
            VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.Colors.textTertiary)
                    TextField("搜索应用名称或 Bundle ID…", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                    if !viewModel.searchText.isEmpty {
                        Button {
                            viewModel.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Theme.Colors.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Theme.Spacing.small)
                .background(Theme.Colors.panelElevated)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Theme.Colors.glassBorder.opacity(0.4), lineWidth: 1)
                }

                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(viewModel.filteredApplications) { app in
                            let isSelected = viewModel.selectedApp?.id == app.id
                            Button {
                                viewModel.selectApp(app)
                            } label: {
                                HStack(spacing: Theme.Spacing.medium) {
                                    AppIconView(path: app.path, size: 32)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(app.name)
                                            .font(.subheadline.weight(isSelected ? .semibold : .regular))
                                            .foregroundStyle(Theme.Colors.textPrimary)
                                            .lineLimit(1)
                                        if let version = app.version {
                                            Text(version)
                                                .font(.caption2)
                                                .foregroundStyle(Theme.Colors.textTertiary)
                                        }
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(ByteCountFormatter.string(fromByteCount: app.totalSize, countStyle: .file))
                                            .font(.caption)
                                            .foregroundStyle(Theme.Colors.textSecondary)
                                        if app.isRunning {
                                            Text("运行中")
                                                .font(.caption2)
                                                .foregroundStyle(Theme.Colors.warning)
                                        }
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(isSelected ? Theme.Colors.accentSoft.opacity(0.4) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .frame(width: 300)
            .padding(.trailing, Theme.Spacing.large)

            Divider()

            // 右侧：选定应用详情与深度关联文件（固定底部卸载栏）
            VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                if let app = viewModel.selectedApp {
                    // 应用头部摘要
                    HStack(spacing: Theme.Spacing.large) {
                        AppIconView(path: app.path, size: 52)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(app.name)
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                    .lineLimit(1)
                                if app.isRunning {
                                    Text("正在运行")
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(Theme.Colors.warning)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Theme.Colors.warning.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                            }
                            Text("\(app.bundleIdentifier) · \(app.version ?? "未知版本")")
                                .font(.caption)
                                .foregroundStyle(Theme.Colors.textTertiary)
                                .lineLimit(1)

                            // 清晰紧凑的指标徽章
                            HStack(spacing: 8) {
                                AppMetricBadge(title: "总空间", value: ByteCountFormatter.string(fromByteCount: app.totalSize, countStyle: .file), isPrimary: true)
                                AppMetricBadge(title: "本体", value: ByteCountFormatter.string(fromByteCount: app.bundleSize, countStyle: .file), isPrimary: false)
                                let extraSize = max(0, app.totalSize - app.bundleSize)
                                AppMetricBadge(title: "关联文件", value: ByteCountFormatter.string(fromByteCount: extraSize, countStyle: .file), isPrimary: false)
                            }
                        }
                        Spacer()
                    }
                    .glassCard(cornerRadius: Theme.CornerRadius.medium, padding: Theme.Spacing.medium)

                    // 关联文件列表
                    VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                        HStack {
                            Text("深度关联文件与残留数据")
                                .font(.headline)
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Spacer()
                            Text("\(app.relatedFiles.count + 1) 个路径")
                                .font(.caption)
                                .foregroundStyle(Theme.Colors.textTertiary)
                        }

                        ScrollView {
                            VStack(spacing: 4) {
                                // 主程序文件行
                                RelatedFileRow(
                                    name: "\(app.name).app",
                                    path: app.path,
                                    relationship: "应用程序本体",
                                    size: app.bundleSize,
                                    isSelected: viewModel.selectedFilePaths.contains(app.path),
                                    onToggle: { viewModel.toggleFilePath(app.path) }
                                )

                                ForEach(app.relatedFiles) { file in
                                    RelatedFileRow(
                                        name: file.name,
                                        path: file.path,
                                        relationship: file.relationship,
                                        size: file.size,
                                        isSelected: viewModel.selectedFilePaths.contains(file.path),
                                        onToggle: { viewModel.toggleFilePath(file.path) }
                                    )
                                }
                            }
                        }
                        .frame(maxHeight: .infinity)
                    }

                    // 底部固定卸载动作栏（始终置底可见）
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            let selectedCount = viewModel.selectedFilePaths.count
                            let totalSelectedBytes = calculateSelectedBytes(app: app, paths: viewModel.selectedFilePaths)
                            Text("已勾选 \(selectedCount) 项待清理")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Text("共 \(ByteCountFormatter.string(fromByteCount: totalSelectedBytes, countStyle: .file)) · 移入废纸篓安全不误删")
                                .font(.caption2)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                        Spacer()
                        Button {
                            Task { await viewModel.uninstallSelectedApp() }
                        } label: {
                            if viewModel.isUninstalling {
                                HStack(spacing: 6) {
                                    ProgressView().controlSize(.small)
                                    Text("正在卸载…")
                                }
                            } else {
                                Label("移入废纸篓彻底卸载", systemImage: "trash.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                            }
                        }
                        .modernStyle(.danger)
                        .disabled(viewModel.isUninstalling || viewModel.selectedFilePaths.isEmpty)
                    }
                    .glassCardElevated(cornerRadius: Theme.CornerRadius.medium, padding: Theme.Spacing.medium)
                } else {
                    PlaceholderSectionView(title: "未选择应用", message: "从左侧列表选择一个应用以查看关联文件与卸载。", systemImage: "square.stack.3d.up")
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.leading, Theme.Spacing.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func calculateSelectedBytes(app: InstalledApplication, paths: Set<String>) -> Int64 {
        var sum: Int64 = 0
        if paths.contains(app.path) { sum += app.bundleSize }
        for f in app.relatedFiles where paths.contains(f.path) {
            sum += f.size
        }
        return sum
    }
}

private struct RelatedFileRow: View {
    let name: String
    let path: String
    let relationship: String
    let size: Int64
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.medium) {
            Toggle("", isOn: Binding(get: { isSelected }, set: { _ in onToggle() }))
                .labelsHidden()

            Image(systemName: path.hasSuffix(".app") ? "app" : (path.contains("Caches") ? "shippingbox" : "folder"))
                .foregroundStyle(Theme.Colors.accent)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(relationship)
                        .font(.caption2)
                        .foregroundStyle(Theme.Colors.accent)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Theme.Colors.accentSoft.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                Text(path)
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Theme.Colors.panelElevated)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Theme.Colors.glassBorder.opacity(0.35), lineWidth: 1)
        }
    }
}

private struct ResidualsView: View {
    @ObservedObject var viewModel: ApplicationManagementViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.large) {
            HStack {
                Text("发现 \(viewModel.residuals.count) 项残留文件")
                    .font(.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                if !viewModel.residuals.isEmpty {
                    Button("一键清理所有残留") {
                        Task { await viewModel.cleanupAllResiduals() }
                    }
                    .modernStyle(.primary)
                    .disabled(viewModel.isUninstalling)
                }
            }

            if viewModel.residuals.isEmpty {
                PlaceholderSectionView(title: "未发现残留数据", message: "您的 Mac 很干净，没有发现已卸载软件的残留文件。", systemImage: "checkmark.seal")
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(viewModel.residuals) { residual in
                            HStack(spacing: Theme.Spacing.medium) {
                                Image(systemName: "trash.circle")
                                    .font(.title3)
                                    .foregroundStyle(Theme.Colors.warning)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(residual.applicationName)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Theme.Colors.textPrimary)
                                        Text(residual.relationship)
                                            .font(.caption2)
                                            .foregroundStyle(Theme.Colors.textTertiary)
                                    }
                                    Text(residual.path)
                                        .font(.caption2)
                                        .foregroundStyle(Theme.Colors.textTertiary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                Text(ByteCountFormatter.string(fromByteCount: residual.size, countStyle: .file))
                                    .font(.caption)
                                    .foregroundStyle(Theme.Colors.textSecondary)

                                Button("清理") {
                                    Task { await viewModel.cleanupResidual(residual) }
                                }
                                .modernStyle(.secondary)
                                .controlSize(.small)
                            }
                            .padding(Theme.Spacing.medium)
                            .background(Theme.Colors.panelElevated)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.small, style: .continuous)
                                    .stroke(Theme.Colors.glassBorder.opacity(0.35), lineWidth: 1)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct StartupItemsView: View {
    @ObservedObject var viewModel: ApplicationManagementViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.large) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("自启动项与后台守护")
                        .font(.headline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("共发现 \(viewModel.startupItems.count) 项开机自启或后台运行的 LaunchAgents 配置。")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()
            }

            if viewModel.startupItems.isEmpty {
                PlaceholderSectionView(
                    title: "未发现开机启动守护项",
                    message: "没有检测到用户级自启动代理配置，开机运行环境保持干净。",
                    systemImage: "bolt.badge.checkmark"
                )
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(viewModel.startupItems) { item in
                            HStack(spacing: Theme.Spacing.medium) {
                                Image(systemName: item.isUserAgent ? "person.crop.circle" : "gearshape.2")
                                    .font(.title3)
                                    .foregroundStyle(Theme.Colors.accent)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(item.name)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Theme.Colors.textPrimary)
                                        Text(item.isUserAgent ? "用户代理" : "系统级代理")
                                            .font(.caption2)
                                            .foregroundStyle(Theme.Colors.textTertiary)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1)
                                            .background(Theme.Colors.panelBackground)
                                            .clipShape(Capsule())

                                        if item.isMissingTarget {
                                            HStack(spacing: 3) {
                                                Image(systemName: "exclamationmark.triangle.fill")
                                                    .font(.system(size: 9))
                                                Text("目标程序已缺失 (残留启动项)")
                                            }
                                            .font(.caption2.weight(.medium))
                                            .foregroundStyle(Theme.Colors.warning)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 1)
                                            .background(Theme.Colors.warning.opacity(0.12))
                                            .clipShape(Capsule())
                                        }
                                    }
                                    if let prog = item.programPath {
                                        Text(prog)
                                            .font(.caption2)
                                            .foregroundStyle(item.isMissingTarget ? Theme.Colors.danger : Theme.Colors.textTertiary)
                                            .lineLimit(1)
                                    } else {
                                        Text(item.label)
                                            .font(.caption2)
                                            .foregroundStyle(Theme.Colors.textTertiary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                Button("移除自启") {
                                    Task { await viewModel.disableStartupItem(item) }
                                }
                                .modernStyle(.secondary)
                                .controlSize(.small)
                            }
                            .padding(Theme.Spacing.medium)
                            .background(Theme.Colors.panelElevated)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.small, style: .continuous)
                                    .stroke(Theme.Colors.glassBorder.opacity(0.35), lineWidth: 1)
                            }
                        }
                    }
                }
            }
        }
    }
}
