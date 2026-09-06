import Foundation

enum CleanupCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case applicationCaches
    case applicationLogs
    case browserCaches
    case installerFiles
    case developerArtifacts
    case packageManagerCaches
    case xcodeData
    case crashReports
    case quickLookCaches
    case aiModels
    case applicationResiduals
    case trash

    var id: String { rawValue }

    var title: String {
        switch self {
        case .applicationCaches: "应用缓存"
        case .applicationLogs: "应用日志"
        case .browserCaches: "浏览器缓存"
        case .installerFiles: "安装包"
        case .developerArtifacts: "开发产物"
        case .packageManagerCaches: "包管理器缓存"
        case .xcodeData: "Xcode 数据"
        case .crashReports: "崩溃与诊断报告"
        case .quickLookCaches: "Quick Look 缓存"
        case .aiModels: "AI 工具与模型"
        case .applicationResiduals: "已卸载应用残留"
        case .trash: "废纸篓"
        }
    }

    var systemImage: String {
        switch self {
        case .applicationCaches: "shippingbox"
        case .applicationLogs: "doc.text"
        case .browserCaches: "safari"
        case .installerFiles: "arrow.down.circle"
        case .developerArtifacts: "hammer"
        case .packageManagerCaches: "archivebox"
        case .xcodeData: "wrench.and.screwdriver"
        case .crashReports: "exclamationmark.bubble"
        case .quickLookCaches: "eye"
        case .aiModels: "cpu"
        case .applicationResiduals: "trash.circle"
        case .trash: "trash"
        }
    }

    var subtitle: String {
        switch self {
        case .applicationCaches: "应用产生的可重建临时文件"
        case .applicationLogs: "运行日志与旧诊断日志"
        case .browserCaches: "浏览器网页与资源缓存"
        case .installerFiles: "已下载的 DMG、PKG 安装包"
        case .developerArtifacts: "node_modules、target 等构建生成物"
        case .packageManagerCaches: "npm、pip、Homebrew、Cargo 等下载缓存"
        case .xcodeData: "DerivedData、模拟器及构建缓存"
        case .crashReports: "系统与应用崩溃转储文件"
        case .quickLookCaches: "系统文件预览缩略图缓存"
        case .aiModels: "Ollama、Hugging Face、LM Studio 模型及权重缓存"
        case .applicationResiduals: "主程序已删除但留在 Library 中的配置残留"
        case .trash: "系统废纸篓中的文件"
        }
    }
}

enum CleanupRiskLevel: String, Codable, Comparable, CaseIterable, Sendable {
    case safe
    case review
    case sensitive
    case prohibited

    nonisolated private var rank: Int {
        switch self {
        case .safe: 0
        case .review: 1
        case .sensitive: 2
        case .prohibited: 3
        }
    }

    nonisolated static func < (lhs: CleanupRiskLevel, rhs: CleanupRiskLevel) -> Bool {
        lhs.rank < rhs.rank
    }
}

enum CleanupItemKind: String, Codable, Sendable {
    case file
    case directory
    case package
    case symbolicLink
}

struct CleanupItem: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let category: CleanupCategory
    let path: String
    let kind: CleanupItemKind
    let size: Int64
    let itemCount: Int
    let lastModifiedAt: Date?
    let riskLevel: CleanupRiskLevel
    let explanation: String
    let reversible: Bool
    let selectedByDefault: Bool

    nonisolated init(
        id: UUID = UUID(),
        category: CleanupCategory,
        path: String,
        kind: CleanupItemKind,
        size: Int64,
        itemCount: Int = 1,
        lastModifiedAt: Date? = nil,
        riskLevel: CleanupRiskLevel,
        explanation: String,
        reversible: Bool,
        selectedByDefault: Bool
    ) {
        self.id = id
        self.category = category
        self.path = path
        self.kind = kind
        self.size = size
        self.itemCount = itemCount
        self.lastModifiedAt = lastModifiedAt
        self.riskLevel = riskLevel
        self.explanation = explanation
        self.reversible = reversible
        self.selectedByDefault = selectedByDefault
    }
}

struct CleanupProgress: Sendable, Equatable {
    let completed: Int
    let discovered: Int
    let category: CleanupCategory?
    let isFinished: Bool

    init(completed: Int = 0, discovered: Int = 0, category: CleanupCategory? = nil, isFinished: Bool = false) {
        self.completed = completed
        self.discovered = discovered
        self.category = category
        self.isFinished = isFinished
    }
}

struct CleanupScanSnapshot: Codable, Identifiable, Sendable {
    let id: UUID
    let startedAt: Date
    let finishedAt: Date?
    let items: [CleanupItem]
    let skippedCount: Int
    let errorCount: Int
    let wasCancelled: Bool

    nonisolated init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        finishedAt: Date? = nil,
        items: [CleanupItem] = [],
        skippedCount: Int = 0,
        errorCount: Int = 0,
        wasCancelled: Bool = false
    ) {
        self.id = id
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.items = items
        self.skippedCount = skippedCount
        self.errorCount = errorCount
        self.wasCancelled = wasCancelled
    }
}

enum CleanupScanPhase: String, Sendable {
    case idle
    case scanningInstallers
    case scanningDeveloperArtifacts
    case scanningCaches
    case completed
    case cancelled
    case failed
}

struct CleanupScanStatus: Sendable, Equatable {
    let phase: CleanupScanPhase
    let completedRoots: Int
    let totalRoots: Int
    let message: String
}

enum CleanupOperation: String, Codable, Sendable {
    case moveToTrash
}

struct CleanupPlan: Codable, Identifiable, Sendable, Equatable {
    let id: UUID
    let scanID: UUID
    let createdAt: Date
    let items: [CleanupItem]
    let operation: CleanupOperation

    nonisolated init(
        id: UUID = UUID(),
        scanID: UUID,
        createdAt: Date = Date(),
        items: [CleanupItem],
        operation: CleanupOperation = .moveToTrash
    ) {
        self.id = id
        self.scanID = scanID
        self.createdAt = createdAt
        self.items = items
        self.operation = operation
    }

    nonisolated var totalSize: Int64 {
        items.reduce(0) { $0 + $1.size }
    }

    nonisolated var containsSensitiveItems: Bool {
        items.contains { $0.riskLevel >= .sensitive }
    }

    nonisolated var allItemsAreReversible: Bool {
        items.allSatisfy(\.reversible)
    }
}

enum CleanupSafetyReason: String, Equatable, Sendable {
    case allowed
    case outsideAllowedRoot
    case rootDirectory
    case protectedSystemPath
    case protectedUserData
    case symbolicLink
    case missingPath
    case inaccessiblePath
}

struct CleanupSafetyDecision: Equatable, Sendable {
    let reason: CleanupSafetyReason
    let normalizedPath: String?

    nonisolated init(reason: CleanupSafetyReason, normalizedPath: String?) {
        self.reason = reason
        self.normalizedPath = normalizedPath
    }

    nonisolated var isAllowed: Bool { reason == .allowed }
}
