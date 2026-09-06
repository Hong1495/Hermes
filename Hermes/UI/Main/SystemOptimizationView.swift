import SwiftUI

struct SystemOptimizationView: View {
    @StateObject private var viewModel = SystemOptimizationViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.large) {
            // 头部标题与一键优化
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    Text("系统维护")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("运行系统原生自愈与缓存重置任务，安全改善卡顿，解决显示与关联异常。")
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()
                Button {
                    Task { await viewModel.runAll() }
                } label: {
                    if viewModel.isExecuting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("一键全部优化", systemImage: "sparkles")
                    }
                }
                .modernStyle(.primary)
                .disabled(viewModel.isExecuting)
            }

            // 任务列表
            VStack(spacing: Theme.Spacing.medium) {
                ForEach(viewModel.tasks) { task in
                    OptimizationTaskRow(task: task) {
                        Task { await viewModel.run(task: task.id) }
                    }
                }
            }

            // 安全说明
            HStack(spacing: 6) {
                Image(systemName: "checkmark.shield")
                    .foregroundStyle(Theme.Colors.success)
                Text("所有优化项目均基于 macOS 原生命令安全运行，不修改系统保护文件，不关闭任何系统守护进程。")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            .padding(.top, Theme.Spacing.small)
        }
    }
}

private struct OptimizationTaskRow: View {
    let task: OptimizationTaskItem
    let onRun: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.large) {
            Image(systemName: task.id.systemImage)
                .font(.title2)
                .foregroundStyle(Theme.Colors.accent)
                .frame(width: 36, height: 36)
                .background(Theme.Colors.accentSoft.opacity(0.4))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(task.id.title)
                    .font(.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(task.id.subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)

                // 状态消息反馈
                switch task.status {
                case .success(let msg):
                    Text(msg)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Theme.Colors.success)
                case .failure(let err):
                    Text(err)
                        .font(.caption2)
                        .foregroundStyle(Theme.Colors.danger)
                default:
                    EmptyView()
                }
            }

            Spacer()

            switch task.status {
            case .running:
                ProgressView()
                    .controlSize(.small)
            case .success:
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.Colors.success)
                    Text("已完成")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.Colors.success)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            default:
                Button("执行", action: onRun)
                    .modernStyle(.secondary)
            }
        }
        .glassCard(cornerRadius: Theme.CornerRadius.medium, padding: Theme.Spacing.large)
    }
}
