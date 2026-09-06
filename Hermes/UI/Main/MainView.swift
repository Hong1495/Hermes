import AppKit
import SwiftUI

// MARK: - Main View

struct MainView: View {
    @State private var selection: MainSection? = .overview
    @StateObject private var cleanupViewModel = CleanupViewModel()
    @StateObject private var systemMonitor = SystemMonitor()

    @Namespace private var sidebarNamespace
    @State private var hoveredSection: MainSection?

    var body: some View {
        NavigationSplitView {
            GlassEffectContainer(spacing: 10) {
                VStack(alignment: .leading, spacing: 16) {
                // 顶部应用标志与标题
                HStack(spacing: 8) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 22, height: 22)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    Text("Hermes")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)

                // 组 1: 系统维护
                VStack(alignment: .leading, spacing: 3) {
                    Text("系统维护")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 2)

                    ForEach(MainSection.mainSections) { section in
                        SidebarItemRow(
                            section: section,
                            isSelected: selection == section,
                            isHovered: hoveredSection == section && selection != section,
                            namespace: sidebarNamespace
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                                selection = section
                            }
                        }
                        .onHover { hovering in
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
                                if hovering {
                                    hoveredSection = section
                                } else if hoveredSection == section {
                                    hoveredSection = nil
                                }
                            }
                        }
                    }
                }

                // 组 2: 偏好设置
                VStack(alignment: .leading, spacing: 3) {
                    Text("偏好")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 2)

                    SidebarItemRow(
                        section: .settings,
                        isSelected: selection == .settings,
                        isHovered: hoveredSection == .settings && selection != .settings,
                        namespace: sidebarNamespace
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                            selection = .settings
                        }
                    }
                    .onHover { hovering in
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
                            if hovering {
                                hoveredSection = .settings
                            } else if hoveredSection == .settings {
                                hoveredSection = nil
                            }
                        }
                    }
                }

                Spacer()

                // 底部快捷键轻提示
                Text("⌘⇧X 截图 · ⌘⇧O OCR · ⌘⇧T 翻译")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 250)
            .background {
                VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow)
                    .ignoresSafeArea()
            }
        } detail: {
            ZStack {
                // 飘逸灵动液态玻璃背景，穿透延伸至顶部窗口标题栏与边缘
                ZStack {
                    VisualEffectBlur(material: .underWindowBackground, blendingMode: .behindWindow)
                    Theme.Colors.panelBackground.opacity(0.35)
                }
                .ignoresSafeArea()

                MainSectionView(
                    section: selection ?? .overview,
                    cleanupViewModel: cleanupViewModel,
                    systemMonitor: systemMonitor,
                    onSelectSection: { selection = $0 }
                )
            }
        }
        .accentColor(Theme.Colors.accent)
        .frame(minWidth: 900, minHeight: 600)
        .background {
            ZStack {
                VisualEffectBlur(material: .underWindowBackground, blendingMode: .behindWindow)
                Theme.Colors.background.opacity(0.42)
            }
            .ignoresSafeArea()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsFromMenu)) { _ in
            selection = .settings
        }
        .onReceive(NotificationCenter.default.publisher(for: .openCleanupFromMenu)) { _ in
            selection = .cleanup
        }
        .onReceive(NotificationCenter.default.publisher(for: .openAboutFromMenu)) { _ in
            selection = .settings
        }
    }
}

// MARK: - Sidebar Data Model

enum MainSection: String, CaseIterable, Identifiable, Hashable {
    case overview
    case cleanup
    case diskAnalysis
    case applications
    case optimize
    case history
    case settings

    var id: String { rawValue }

    /// Sections shown in the "系统维护" sidebar group (excludes settings).
    static var mainSections: [MainSection] {
        [.overview, .cleanup, .diskAnalysis, .applications, .optimize, .history]
    }

    var title: String {
        switch self {
        case .overview: "概览"
        case .cleanup: "空间清理"
        case .diskAnalysis: "磁盘分析"
        case .applications: "应用管理"
        case .optimize: "自愈维护"
        case .history: "操作历史"
        case .settings: "偏好设置"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "gauge"
        case .cleanup: "wand.and.stars"
        case .diskAnalysis: "externaldrive"
        case .applications: "square.grid.2x2"
        case .optimize: "wrench.adjustable"
        case .history: "clock.arrow.circlepath"
        case .settings: "slider.horizontal.3"
        }
    }
}

// MARK: - Sidebar Item Row with Fluid Glass Bubble

private struct SidebarItemRow: View {
    let section: MainSection
    let isSelected: Bool
    let isHovered: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: section.systemImage)
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? Theme.Colors.accent : Theme.Colors.textSecondary)
                    .frame(width: 24, height: 24)
                    .background(isSelected ? Theme.Colors.accentSoft.opacity(0.7) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                Text(section.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .glassEffect(
                isSelected
                    ? .regular.tint(Theme.Colors.accent.opacity(0.10)).interactive()
                    : (isHovered ? .clear.interactive() : .identity),
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .glassEffectID(
                isSelected ? "sidebar-selection" : (isHovered ? "sidebar-hover" : nil),
                in: namespace
            )
            .glassEffectTransition(.matchedGeometry)
            .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Detail Router

private struct MainSectionView: View {
    let section: MainSection
    @ObservedObject var cleanupViewModel: CleanupViewModel
    @ObservedObject var systemMonitor: SystemMonitor
    let onSelectSection: (MainSection) -> Void

    var body: some View {
        Group {
            switch section {
            case .applications:
                ApplicationManagementView()
                    .padding(.horizontal, Theme.Spacing.xxLarge)
                    .padding(.top, 20)
                    .padding(.bottom, Theme.Spacing.large)
            case .diskAnalysis:
                DiskAnalysisView()
                    .padding(.horizontal, Theme.Spacing.xxLarge)
                    .padding(.top, 20)
                    .padding(.bottom, Theme.Spacing.large)
            default:
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.extraLarge) {
                        switch section {
                        case .overview:
                            OverviewView(
                                viewModel: cleanupViewModel,
                                monitor: systemMonitor,
                                onNavigateToCleanup: { onSelectSection(.cleanup) }
                            )
                        case .cleanup:
                            CleanupView(viewModel: cleanupViewModel)
                        case .optimize:
                            SystemOptimizationView()
                        case .history:
                            CleanupHistoryView()
                        case .settings:
                            UnifiedSettingsView()
                        default:
                            EmptyView()
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xxLarge)
                    .padding(.top, 20)
                    .padding(.bottom, Theme.Spacing.xxLarge)
                    .frame(maxWidth: 980, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity.combined(with: .scale(scale: 0.99)))
        .animation(.spring(response: 0.3, dampingFraction: 0.82), value: section)
    }
}

// MARK: - Overview

private struct OverviewView: View {
    @ObservedObject var viewModel: CleanupViewModel
    @ObservedObject var monitor: SystemMonitor
    let onNavigateToCleanup: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.extraLarge) {
            // 页面标题 — 统一 .largeTitle 风格，与其他页面保持一致
            VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                Text("系统概览")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("一站式查看系统健康状态与存储空间分析。")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            // Macintosh HD 存储容量条
            StorageUsageBar(cleanableBytes: viewModel.snapshot != nil ? viewModel.selectedBytes : 0)

            // 系统实时状态雷达
            SystemRadarCard(monitor: monitor)

            // 状态卡片
            HStack(spacing: Theme.Spacing.large) {
                if let snapshot = viewModel.snapshot {
                    MetricCard(
                        title: "待清理项",
                        value: "\(snapshot.items.count) 项",
                        detail: "共可释放 \(ByteCountFormatter.string(fromByteCount: snapshot.items.reduce(0) { $0 + $1.size }, countStyle: .file))",
                        systemImage: "sparkles"
                    )
                } else {
                    MetricCard(
                        title: "空间体检",
                        value: "等待扫描",
                        detail: "全面扫描系统、浏览器与开发缓存",
                        systemImage: "magnifyingglass"
                    )
                }

                MetricCard(
                    title: "安全规范",
                    value: "可撤回保护",
                    detail: "全部清理移入废纸篓，安全防误删",
                    systemImage: "checkmark.shield"
                )
            }

            // 快速体检 CTA 卡片（Elevated 层级）
            HStack(spacing: Theme.Spacing.large) {
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    Text("智能系统空间体检")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("全面扫描 10+ 类缓存（系统、浏览器、Node/Rust/Go 开发产物、AI 权重、废纸篓与安装包）。")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()
                Button {
                    onNavigateToCleanup()
                    if viewModel.snapshot == nil && !viewModel.isScanning {
                        Task { await viewModel.scanAll() }
                    }
                } label: {
                    Label(viewModel.isScanning ? "正在扫描…" : (viewModel.snapshot == nil ? "开始全面体检" : "查看清理结果"), systemImage: "arrow.right.circle.fill")
                        .font(.headline)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                .modernStyle(.primary)
            }
            .glassCardElevated(cornerRadius: Theme.CornerRadius.medium)
        }
    }
}

// MARK: - Cleanup

private struct CleanupView: View {
    @ObservedObject var viewModel: CleanupViewModel
    @State private var expandedCategories: Set<CleanupCategory> = []
    @State private var showingEmptyTrashConfirmation = false

    private var groupedItems: [(CleanupCategory, [CleanupItem])] {
        guard let snapshot = viewModel.snapshot else { return [] }
        return CleanupCategory.allCases.compactMap { category in
            let items = snapshot.items.filter { $0.category == category }
            return items.isEmpty ? nil : (category, items)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.large) {
            // 顶栏：标题与扫描按钮
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    Text("空间清理")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("深度扫描各处冗余产物。过程纯只读，执行操作均安全移入废纸篓。")
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()
                if !viewModel.trashItems.isEmpty {
                    Button {
                        showingEmptyTrashConfirmation = true
                    } label: {
                        Label("清空废纸篓", systemImage: "trash.slash")
                    }
                    .modernStyle(.danger)
                    .disabled(viewModel.isScanning || viewModel.isEmptyingTrash)
                }
                Button {
                    Task { await viewModel.scanAll() }
                } label: {
                    if viewModel.isScanning {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("扫描中…")
                        }
                    } else {
                        Label(viewModel.snapshot == nil ? "开始扫描" : "重新扫描", systemImage: "sparkles")
                    }
                }
                .modernStyle(.primary)
                .disabled(viewModel.isScanning)
            }

            // 扫描进度条
            if viewModel.isScanning {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(viewModel.scanMessage)
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.textSecondary)
                        Spacer()
                        Text("\(Int(viewModel.scanProgress * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                    ProgressView(value: viewModel.scanProgress)
                        .tint(Theme.Colors.accent)
                }
                .padding(Theme.Spacing.medium)
                .background(Theme.Colors.panelElevated)
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small, style: .continuous))
            }

            // 执行结果提示
            if let summary = viewModel.executionSummary {
                ExecutionSummaryView(summary: summary, isExecuting: viewModel.isExecuting)
            }

            if let snapshot = viewModel.snapshot {
                // 筛选与选择条
                HStack {
                    Button("全选") { viewModel.setAllSelected(true) }
                        .modernStyle(.secondary)
                        .controlSize(.small)
                    Button("仅选推荐 (低风险)") { viewModel.selectRecommended() }
                        .modernStyle(.secondary)
                        .controlSize(.small)
                    Button("取消全选") { viewModel.setAllSelected(false) }
                        .modernStyle(.secondary)
                        .controlSize(.small)

                    Spacer()

                    Text("已选 \(viewModel.selectedItems.count) 项 · \(ByteCountFormatter.string(fromByteCount: viewModel.selectedBytes, countStyle: .file))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.Colors.accent)
                }

                if snapshot.items.isEmpty {
                    PlaceholderSectionView(title: "没有可清理的项目", message: "您的 Mac 处于极佳状态，未扫描到需清理的项目。", systemImage: "checkmark.seal")
                } else {
                    // 分类折叠卡片列表
                    VStack(spacing: Theme.Spacing.medium) {
                        ForEach(groupedItems, id: \.0) { category, items in
                            let isExpanded = expandedCategories.contains(category)
                            let categoryBytes = items.reduce(0) { $0 + $1.size }
                            let allSelected = items.allSatisfy { viewModel.selectedItemIDs.contains($0.id) }

                            VStack(spacing: 0) {
                                HStack(spacing: Theme.Spacing.medium) {
                                    Toggle("", isOn: Binding(
                                        get: { allSelected },
                                        set: { viewModel.setCategorySelected(category, selected: $0) }
                                    ))
                                    .labelsHidden()

                                    Image(systemName: category.systemImage)
                                        .font(.title3)
                                        .foregroundStyle(Theme.Colors.accent)
                                        .frame(width: 28)

                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(category.title)
                                                .font(.headline)
                                                .foregroundStyle(Theme.Colors.textPrimary)
                                            Text("\(items.count) 项")
                                                .font(.caption2)
                                                .foregroundStyle(Theme.Colors.textTertiary)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 1)
                                                .background(Theme.Colors.panelBackground)
                                                .clipShape(Capsule())
                                        }
                                        Text(category.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(Theme.Colors.textSecondary)
                                    }

                                    Spacer()

                                    Text(ByteCountFormatter.string(fromByteCount: categoryBytes, countStyle: .file))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Theme.Colors.textPrimary)

                                    Button {
                                        if isExpanded {
                                            expandedCategories.remove(category)
                                        } else {
                                            expandedCategories.insert(category)
                                        }
                                    } label: {
                                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                            .foregroundStyle(Theme.Colors.textTertiary)
                                            .frame(width: 24, height: 24)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(Theme.Spacing.large)

                                if isExpanded {
                                    Divider()
                                    VStack(spacing: 0) {
                                        ForEach(items) { item in
                                            CleanupItemRow(
                                                item: item,
                                                isSelected: viewModel.selectedItemIDs.contains(item.id)
                                            ) {
                                                viewModel.setSelected($0, for: item)
                                            }
                                            if item.id != items.last?.id {
                                                Divider()
                                                    .padding(.leading, 36)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, Theme.Spacing.large)
                                    .padding(.vertical, Theme.Spacing.small)
                                    .background(Theme.Colors.panelBackground.opacity(0.5))
                                }
                            }
                            .glassCard(cornerRadius: Theme.CornerRadius.medium, padding: 0)
                        }
                    }
                }

                // 底部悬浮操作栏（Elevated 层级）
                if !viewModel.selectedItems.isEmpty {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("准备就绪")
                                .font(.headline)
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Text("将安全处理 \(viewModel.selectedItems.count) 项，共 \(ByteCountFormatter.string(fromByteCount: viewModel.selectedBytes, countStyle: .file))。此操作可从废纸篓随时恢复。")
                                .font(.caption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                        Spacer()
                        Button {
                            Task { await viewModel.executePlan() }
                        } label: {
                            if viewModel.isExecuting {
                                ProgressView().controlSize(.small)
                            } else {
                                Label("移入废纸篓", systemImage: "trash")
                                    .font(.headline)
                                    .padding(.horizontal, 8)
                            }
                        }
                        .modernStyle(.primary)
                        .disabled(viewModel.isExecuting)
                    }
                    .glassCardElevated(cornerRadius: Theme.CornerRadius.medium)
                }
            } else {
                CleanupCategoryPlaceholderList()
            }
        }
        .alert("清空废纸篓？", isPresented: $showingEmptyTrashConfirmation) {
            Button("取消", role: .cancel) {}
            Button("永久删除", role: .destructive) {
                Task { await viewModel.emptyTrash() }
            }
        } message: {
            Text("将永久删除 \(viewModel.trashItems.count) 项，共 \(ByteCountFormatter.string(fromByteCount: viewModel.trashBytes, countStyle: .file))，此操作无法恢复。")
        }
    }
}

private struct CleanupCategoryPlaceholderList: View {
    var body: some View {
        VStack(spacing: 0) {
            CleanupCategoryRow(title: "应用与系统缓存", detail: "可重建临时数据与系统缓存", size: "待扫描", risk: "低风险", systemImage: "shippingbox")
            Divider()
            CleanupCategoryRow(title: "浏览器深度缓存", detail: "Safari、Chrome、Arc、Edge 等网页缓存", size: "待扫描", risk: "低风险", systemImage: "safari")
            Divider()
            CleanupCategoryRow(title: "开发产物", detail: "node_modules、target、DerivedData 等", size: "待扫描", risk: "需检查", systemImage: "hammer")
            Divider()
            CleanupCategoryRow(title: "包管理器与工具缓存", detail: "npm、pnpm、pip、Homebrew、Cargo、Docker", size: "待扫描", risk: "需检查", systemImage: "shippingbox.fill")
            Divider()
            CleanupCategoryRow(title: "AI 工具与模型", detail: "Ollama、Hugging Face、LM Studio 权重与模型", size: "待扫描", risk: "需检查", systemImage: "cpu")
            Divider()
            CleanupCategoryRow(title: "下载安装包与废纸篓", detail: "已下载的 DMG、PKG 与废纸篓文件", size: "待扫描", risk: "需检查", systemImage: "arrow.down.circle")
        }
        .padding(.horizontal, Theme.Spacing.large)
        .glassCard(cornerRadius: Theme.CornerRadius.medium, padding: 0)
    }
}

private struct ExecutionSummaryView: View {
    let summary: CleanupExecutionSummary
    let isExecuting: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            Label("清理结果", systemImage: "checkmark.circle")
                .font(.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("已移入废纸篓 \(summary.movedCount) 项，共释放 \(ByteCountFormatter.string(fromByteCount: summary.movedBytes, countStyle: .file))。")
                .foregroundStyle(Theme.Colors.success)
            let skipped = summary.results.filter { $0.status == .skippedChanged || $0.status == .skippedUnsafe }.count
            let failed = summary.results.filter { $0.status == .failed }.count
            if skipped > 0 || failed > 0 {
                Text("跳过 \(skipped) 项，失败 \(failed) 项；请查看详情后重新扫描。")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.warning)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: Theme.CornerRadius.small, padding: Theme.Spacing.medium)
    }
}

private struct CleanupItemRow: View {
    let item: CleanupItem
    let isSelected: Bool
    let onSelectionChange: (Bool) -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.medium) {
            Toggle("", isOn: Binding(get: { isSelected }, set: onSelectionChange))
                .labelsHidden()
            Image(systemName: item.kind == .package ? "shippingbox" : (item.kind == .directory ? "folder" : "doc"))
                .foregroundStyle(Theme.Colors.accent)
            VStack(alignment: .leading, spacing: 3) {
                Text(URL(fileURLWithPath: item.path).lastPathComponent)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(item.explanation)
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                Text(item.path)
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
                Text(item.riskLevel == .safe ? "低风险" : "需检查")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(item.riskLevel == .safe ? Theme.Colors.success : Theme.Colors.warning)
            }
        }
        .padding(.vertical, 8)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Theme.Colors.accent)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.textSecondary)
            Text(value)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
            Text(detail)
                .font(.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: Theme.CornerRadius.medium, padding: Theme.Spacing.large)
    }
}

private struct CleanupCategoryRow: View {
    let title: String
    let detail: String
    let size: String
    let risk: String
    let systemImage: String

    var body: some View {
        HStack(spacing: Theme.Spacing.medium) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Theme.Colors.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
            Text(size)
                .foregroundStyle(Theme.Colors.textSecondary)
            Text(risk)
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.Colors.warning)
                .frame(width: 58, alignment: .trailing)
        }
        .padding(.vertical, Theme.Spacing.medium)
    }
}

struct PlaceholderSectionView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: Theme.Spacing.medium) {
            Image(systemName: systemImage)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(Theme.Colors.accent)
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .glassCard(cornerRadius: Theme.CornerRadius.medium, padding: Theme.Spacing.large)
    }
}
