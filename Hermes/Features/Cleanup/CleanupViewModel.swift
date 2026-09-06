import Combine
import Foundation

@MainActor
final class CleanupViewModel: ObservableObject {
    @Published private(set) var snapshot: CleanupScanSnapshot?
    @Published private(set) var selectedItemIDs: Set<UUID> = []
    @Published private(set) var plan: CleanupPlan?
    @Published private(set) var executionSummary: CleanupExecutionSummary?
    @Published private(set) var history: [CleanupHistoryEntry] = []
    @Published private(set) var isScanning = false
    @Published private(set) var isExecuting = false
    @Published private(set) var isEmptyingTrash = false
    @Published private(set) var scanProgress: Double = 0.0
    @Published private(set) var scanMessage: String = "准备就绪"

    private let orchestrator: CleanupOrchestrator
    private let cleanupExecutor: CleanupExecutor
    private let historyStore: CleanupHistoryStore

    var items: [CleanupItem] { snapshot?.items ?? [] }
    var selectedItems: [CleanupItem] { items.filter { selectedItemIDs.contains($0.id) } }
    var selectedBytes: Int64 { selectedItems.reduce(0) { $0 + $1.size } }
    var trashItems: [CleanupItem] { items.filter { $0.category == .trash } }
    var trashBytes: Int64 { trashItems.reduce(0) { $0 + $1.size } }

    func emptyTrash() async {
        guard !isEmptyingTrash, !trashItems.isEmpty else { return }
        isEmptyingTrash = true
        let removedPaths = Set(trashItems.map(\.path))
        _ = await cleanupExecutor.emptyTrash(items: trashItems)
        if let snapshot {
            self.snapshot = CleanupScanSnapshot(id: snapshot.id, startedAt: snapshot.startedAt, finishedAt: snapshot.finishedAt, items: snapshot.items.filter { !removedPaths.contains($0.path) }, skippedCount: snapshot.skippedCount, errorCount: snapshot.errorCount, wasCancelled: snapshot.wasCancelled)
        }
        isEmptyingTrash = false
    }

    init(
        orchestrator: CleanupOrchestrator = CleanupOrchestrator(),
        cleanupExecutor: CleanupExecutor = CleanupExecutor(),
        historyStore: CleanupHistoryStore = CleanupHistoryStore()
    ) {
        self.orchestrator = orchestrator
        self.cleanupExecutor = cleanupExecutor
        self.historyStore = historyStore
    }

    func loadHistory() async {
        history = await historyStore.entries()
    }

    func scanAll() async {
        guard !isScanning else { return }
        isScanning = true
        executionSummary = nil
        plan = nil
        selectedItemIDs = []
        scanProgress = 0.0
        scanMessage = "开始扫描…"
        defer { isScanning = false }

        let whitelist = WhitelistManager.shared.excludedPaths
        let result = await orchestrator.scanAll(whitelist: whitelist) { message, progress in
            Task { @MainActor [weak self] in
                self?.scanMessage = message
                self?.scanProgress = progress
            }
        }

        snapshot = result
        // 默认勾选安全项（低风险推荐项）
        selectedItemIDs = Set(result.items.filter(\.selectedByDefault).map(\.id))
        plan = makePlan()
        scanProgress = 1.0
        scanMessage = result.wasCancelled ? "扫描已取消" : "扫描完成，发现 \(result.items.count) 项"
    }

    func scanInstallers() async {
        await scanAll()
    }

    func selectRecommended() {
        selectedItemIDs = Set(items.filter { $0.riskLevel == .safe }.map(\.id))
        plan = makePlan()
    }

    func setCategorySelected(_ category: CleanupCategory, selected: Bool) {
        let categoryItemIDs = items.filter { $0.category == category }.map(\.id)
        if selected {
            // Emptying Trash is irreversible and requires its own explicit
            // confirmation flow; it is never included in bulk selection.
            let reversibleIDs = Set(items.filter { categoryItemIDs.contains($0.id) && $0.reversible }.map(\.id))
            selectedItemIDs.formUnion(reversibleIDs)
        } else {
            selectedItemIDs.subtract(categoryItemIDs)
        }
        plan = makePlan()
    }

    func setSelected(_ selected: Bool, for item: CleanupItem) {
        if selected {
            guard item.reversible else { return }
            selectedItemIDs.insert(item.id)
        } else {
            selectedItemIDs.remove(item.id)
        }
        plan = makePlan()
    }

    func setAllSelected(_ selected: Bool) {
        selectedItemIDs = selected ? Set(items.filter(\.reversible).map(\.id)) : []
        plan = makePlan()
    }

    func makePlan() -> CleanupPlan? {
        guard let snapshot else { return nil }
        return CleanupPlan(
            scanID: snapshot.id,
            items: snapshot.items.filter { selectedItemIDs.contains($0.id) }
        )
    }

    func executePlan() async {
        guard !isExecuting, let plan, !plan.items.isEmpty else { return }
        isExecuting = true
        defer { isExecuting = false }
        let roots = automaticRoots()
        executionSummary = await cleanupExecutor.execute(plan, allowedRoots: roots)
        if let summary = executionSummary {
            let entry = CleanupHistoryEntry(
                planID: summary.planID,
                createdAt: Date(),
                movedCount: summary.movedCount,
                movedBytes: summary.movedBytes,
                skippedCount: summary.results.filter { $0.status == .skippedChanged || $0.status == .skippedUnsafe }.count,
                failedCount: summary.results.filter { $0.status == .failed }.count
            )
            await historyStore.append(entry)
            history = await historyStore.entries()
        }
        if executionSummary?.movedCount ?? 0 > 0 {
            snapshot = snapshot.map { snapshot in
                CleanupScanSnapshot(
                    id: snapshot.id,
                    startedAt: snapshot.startedAt,
                    finishedAt: snapshot.finishedAt,
                    items: snapshot.items.filter { item in
                        !(executionSummary?.results.contains { result in
                            result.path == item.path && result.status == .movedToTrash
                        } ?? false)
                    },
                    skippedCount: snapshot.skippedCount,
                    errorCount: snapshot.errorCount,
                    wasCancelled: snapshot.wasCancelled
                )
            }
            selectedItemIDs = []
            self.plan = nil
        }
    }

    private func automaticRoots() -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent("Downloads", isDirectory: true),
            home.appendingPathComponent("Library", isDirectory: true),
            home.appendingPathComponent("Projects", isDirectory: true),
            home.appendingPathComponent("GitHub", isDirectory: true),
            home.appendingPathComponent("dev", isDirectory: true),
            home.appendingPathComponent("Developer", isDirectory: true),
            home.appendingPathComponent(".npm", isDirectory: true),
            home.appendingPathComponent(".cache", isDirectory: true),
            home.appendingPathComponent(".cargo", isDirectory: true),
            home.appendingPathComponent("go", isDirectory: true),
            home.appendingPathComponent(".gradle", isDirectory: true),
            home.appendingPathComponent(".m2", isDirectory: true),
            home.appendingPathComponent(".ollama", isDirectory: true),
            home.appendingPathComponent(".Trash", isDirectory: true),
            home.appendingPathComponent(".yarn", isDirectory: true)
        ]
    }
}
