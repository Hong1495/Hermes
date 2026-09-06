import Combine
import SwiftUI

struct CleanupHistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.large) {
            Text("操作历史")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("查看 Hermes 已完成的清理操作、跳过项目和失败结果。")
                .foregroundStyle(Theme.Colors.textSecondary)

            if viewModel.entries.isEmpty {
                PlaceholderSectionView(title: "暂无操作记录", message: "完成一次清理后，结果会显示在这里。", systemImage: "clock.arrow.circlepath")
            } else {
                ForEach(viewModel.entries) { entry in
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(Theme.Colors.success)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.headline)
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Text("已移入废纸篓 \(entry.movedCount) 项 · \(ByteCountFormatter.string(fromByteCount: entry.movedBytes, countStyle: .file))")
                                .font(.caption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                        Spacer()
                        if entry.skippedCount > 0 || entry.failedCount > 0 {
                            Text("跳过 \(entry.skippedCount) · 失败 \(entry.failedCount)")
                                .font(.caption)
                                .foregroundStyle(Theme.Colors.warning)
                        }
                    }
                    .glassCard(cornerRadius: Theme.CornerRadius.small, padding: Theme.Spacing.medium)
                }
            }
        }
        .task { await viewModel.load() }
    }
}

@MainActor
private final class HistoryViewModel: ObservableObject {
    @Published private(set) var entries: [CleanupHistoryEntry] = []
    private let store = CleanupHistoryStore()

    func load() async {
        entries = await store.entries()
    }
}
