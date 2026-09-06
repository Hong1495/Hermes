import Foundation

enum OptimizationTaskType: String, CaseIterable, Identifiable, Sendable {
    case flushDNS
    case rebuildQuickLook
    case clearFontCache
    case purgeMemory
    case rebuildLaunchServices
    case rebuildSpotlight
    case resetIconServices

    var id: String { rawValue }

    var title: String {
        switch self {
        case .flushDNS: "刷新 DNS 缓存"
        case .rebuildQuickLook: "重建 Quick Look 缩略图缓存"
        case .clearFontCache: "清理用户字体缓存"
        case .purgeMemory: "释放未活跃磁盘缓存内存"
        case .rebuildLaunchServices: "重建“打开方式”关联数据库"
        case .rebuildSpotlight: "重新建立 Spotlight 索引"
        case .resetIconServices: "重置应用图标缓存"
        }
    }

    var subtitle: String {
        switch self {
        case .flushDNS: "清理系统 DNS 解析缓存，解决域名解析失效或网页访问延迟"
        case .rebuildQuickLook: "重置 Finder 缩略图生成进程，修复图片/文档预览空白或损坏"
        case .clearFontCache: "清除当前用户的字体排版缓存，解决软件中文字体模糊或渲染异常"
        case .purgeMemory: "强制刷新文件系统未活跃读写缓冲，释放物理内存余量"
        case .rebuildLaunchServices: "清理右键“打开方式”中重复出现的应用条目与失效绑定"
        case .rebuildSpotlight: "重新索引 /Applications 目录，修复聚焦搜索搜不到应用的问题"
        case .resetIconServices: "清理系统图标服务缓存并重启 Dock，修复应用图标变空白或损坏"
        }
    }

    var systemImage: String {
        switch self {
        case .flushDNS: "network"
        case .rebuildQuickLook: "eye"
        case .clearFontCache: "textformat"
        case .purgeMemory: "memorychip"
        case .rebuildLaunchServices: "arrow.triangle.2.circlepath"
        case .rebuildSpotlight: "magnifyingglass"
        case .resetIconServices: "app.badge.checkmark"
        }
    }
}

enum OptimizationStatus: Equatable, Sendable {
    case ready
    case running
    case success(String)
    case failure(String)
}

struct OptimizationTaskItem: Identifiable, Sendable {
    let id: OptimizationTaskType
    var status: OptimizationStatus

    init(id: OptimizationTaskType, status: OptimizationStatus = .ready) {
        self.id = id
        self.status = status
    }
}
