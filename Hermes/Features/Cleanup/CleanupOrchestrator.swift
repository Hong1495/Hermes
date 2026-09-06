import Foundation

actor CleanupOrchestrator {
    private let fileManager: FileManager
    private let safetyPolicy: CleanupSafetyPolicy

    private let cacheScanner: CacheScanner
    private let browserScanner: BrowserCacheScanner
    private let devScanner: DeveloperArtifactScanner
    private let toolScanner: ToolCacheScanner
    private let aiScanner: AIToolsScanner
    private let installerScanner: InstallerScanner
    private let trashScanner: TrashScanner
    private let applicationScanner: ApplicationScanner

    init(fileManager: FileManager = .default, safetyPolicy: CleanupSafetyPolicy? = nil) {
        self.fileManager = fileManager
        let policy = safetyPolicy ?? CleanupSafetyPolicy(fileManager: fileManager)
        self.safetyPolicy = policy

        self.cacheScanner = CacheScanner(fileManager: fileManager, safetyPolicy: policy)
        self.browserScanner = BrowserCacheScanner(fileManager: fileManager, safetyPolicy: policy)
        self.devScanner = DeveloperArtifactScanner(fileManager: fileManager, safetyPolicy: policy)
        self.toolScanner = ToolCacheScanner(fileManager: fileManager, safetyPolicy: policy)
        self.aiScanner = AIToolsScanner(fileManager: fileManager, safetyPolicy: policy)
        self.installerScanner = InstallerScanner(fileManager: fileManager, safetyPolicy: policy)
        self.trashScanner = TrashScanner(fileManager: fileManager)
        self.applicationScanner = ApplicationScanner(fileManager: fileManager)
    }

    func scanAll(whitelist: [String] = [], onProgress: (@Sendable (String, Double) -> Void)? = nil) async -> CleanupScanSnapshot {
        let startedAt = Date()

        onProgress?("正在扫描系统与应用缓存…", 0.1)
        async let s1 = cacheScanner.scan()

        onProgress?("正在扫描浏览器缓存…", 0.25)
        async let s2 = browserScanner.scan()

        onProgress?("正在扫描开发生成产物…", 0.4)
        async let s3 = devScanner.scan()

        onProgress?("正在扫描包管理与工具缓存…", 0.55)
        async let s4 = toolScanner.scan()

        onProgress?("正在检查本地 AI 模型与权重…", 0.7)
        async let s5 = aiScanner.scan()

        onProgress?("正在检查已下载安装包…", 0.85)
        async let s6 = installerScanner.scan()

        onProgress?("正在检查废纸篓…", 0.95)
        async let s7 = trashScanner.scan()

        onProgress?("正在检查已卸载应用残留…", 0.98)
        let snapshots = await [s1, s2, s3, s4, s5, s6, s7]
        let residualScan = await scanResidualsWithTimeout()
        let residuals = residualScan.items.map { residual in
            CleanupItem(
                category: .applicationResiduals,
                path: residual.path,
                kind: .directory,
                size: residual.size,
                riskLevel: residual.riskLevel,
                explanation: "\(residual.applicationName) 的\(residual.relationship)，对应应用已不在系统中。",
                reversible: true,
                selectedByDefault: residual.selectedByDefault
            )
        }
        onProgress?(residualScan.timedOut ? "扫描完成（已跳过耗时残留检查）" : "扫描完成", 1.0)

        return merge(
            snapshots + [CleanupScanSnapshot(items: residuals)],
            whitelist: whitelist,
            startedAt: startedAt
        )
    }

    private func merge(_ snapshots: [CleanupScanSnapshot], whitelist: [String], startedAt: Date) -> CleanupScanSnapshot {
        let allItems = snapshots.flatMap(\.items)
        let filteredItems = allItems.filter { item in
            let path = item.path
            return !whitelist.contains { excluded in
                path == excluded || path.hasPrefix(excluded + "/")
            }
        }
        let whitelistSkipped = allItems.count - filteredItems.count

        return CleanupScanSnapshot(
            startedAt: startedAt,
            finishedAt: Date(),
            items: filteredItems.sorted { $0.size > $1.size },
            skippedCount: snapshots.reduce(0) { $0 + $1.skippedCount } + whitelistSkipped,
            errorCount: snapshots.reduce(0) { $0 + $1.errorCount },
            wasCancelled: snapshots.contains { $0.wasCancelled }
        )
    }

    private struct ResidualScanResult: Sendable {
        let items: [ApplicationResidual]
        let timedOut: Bool
    }

    /// Residual discovery touches user Library directories and can encounter
    /// slow or unavailable filesystem providers. Bound it so the overall scan
    /// always completes and remains usable.
    private func scanResidualsWithTimeout() async -> ResidualScanResult {
        await withTaskGroup(of: ResidualScanResult.self) { group in
            group.addTask { [applicationScanner] in
                let items = await applicationScanner.scanResiduals()
                return ResidualScanResult(items: items, timedOut: false)
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(60))
                return ResidualScanResult(items: [], timedOut: true)
            }
            let result = await group.next() ?? ResidualScanResult(items: [], timedOut: true)
            group.cancelAll()
            return result
        }
    }
}
