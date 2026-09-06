import AppKit
import Combine
import Foundation

enum AppManagementTab: String, CaseIterable, Identifiable {
    case installedApps
    case residuals
    case startupItems

    var id: String { rawValue }
    var title: String {
        switch self {
        case .installedApps: "已安装应用"
        case .residuals: "残留清理"
        case .startupItems: "自启动项"
        }
    }
}

@MainActor
final class ApplicationManagementViewModel: ObservableObject {
    @Published private(set) var snapshot: ApplicationScanSnapshot?
    @Published private(set) var startupItems: [StartupItem] = []
    @Published private(set) var isScanning = false
    @Published private(set) var isUninstalling = false
    @Published var selectedTab: AppManagementTab = .installedApps
    @Published var searchText: String = ""
    @Published var selectedAppID: String?
    @Published var selectedFilePaths: Set<String> = []
    @Published var lastOperationMessage: String?

    private let scanner = ApplicationScanner()
    private let uninstaller = ApplicationUninstaller()
    private let startupManager = StartupItemManager()

    var applications: [InstalledApplication] {
        snapshot?.applications ?? []
    }

    var residuals: [ApplicationResidual] {
        snapshot?.residuals ?? []
    }

    var filteredApplications: [InstalledApplication] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return applications
        }
        let query = searchText.lowercased()
        return applications.filter {
            $0.name.lowercased().contains(query) || $0.bundleIdentifier.lowercased().contains(query)
        }
    }

    var selectedApp: InstalledApplication? {
        applications.first { $0.id == selectedAppID } ?? filteredApplications.first
    }

    func loadIfNeeded() async {
        guard snapshot == nil else { return }
        await scan()
    }

    func scan() async {
        guard !isScanning else { return }
        isScanning = true
        lastOperationMessage = nil
        defer { isScanning = false }

        async let appScan = scanner.scan()
        async let startups = startupManager.scanStartupItems()

        let (result, items) = await (appScan, startups)
        snapshot = result
        startupItems = items

        if selectedAppID == nil || !result.applications.contains(where: { $0.id == selectedAppID }) {
            if let first = result.applications.first {
                selectApp(first)
            }
        }
    }

    func disableStartupItem(_ item: StartupItem) async {
        guard !isUninstalling else { return }
        isUninstalling = true
        defer { isUninstalling = false }

        let success = await startupManager.disableItem(path: item.path)
        if success {
            lastOperationMessage = "已移除自启动项：\(item.name)"
            startupItems.removeAll { $0.id == item.id }
        } else {
            lastOperationMessage = "移除自启动项失败，请检查文件权限。"
        }
    }

    func selectApp(_ app: InstalledApplication) {
        selectedAppID = app.id
        // 默认全选关联文件（实现无残留卸载）
        var paths: Set<String> = [app.path]
        for item in app.relatedFiles {
            paths.insert(item.path)
        }
        selectedFilePaths = paths
    }

    func toggleFilePath(_ path: String) {
        if selectedFilePaths.contains(path) {
            selectedFilePaths.remove(path)
        } else {
            selectedFilePaths.insert(path)
        }
    }

    func uninstallSelectedApp() async {
        guard let app = selectedApp, !isUninstalling else { return }
        isUninstalling = true
        defer { isUninstalling = false }

        // 如果应用正在运行，先请求退出
        if app.isRunning {
            _ = await uninstaller.terminateApp(bundleIdentifier: app.bundleIdentifier)
            try? await Task.sleep(nanoseconds: 500_000_000)
        }

        let pathsToTrash = Array(selectedFilePaths)
        let result = await uninstaller.uninstall(paths: pathsToTrash)

        lastOperationMessage = "已移入废纸篓 \(result.successCount) 项，共释放 \(ByteCountFormatter.string(fromByteCount: result.movedBytes, countStyle: .file))"

        // 重新扫描以刷新列表
        await scan()
    }

    func cleanupResidual(_ residual: ApplicationResidual) async {
        guard !isUninstalling else { return }
        isUninstalling = true
        defer { isUninstalling = false }

        let result = await uninstaller.uninstall(paths: [residual.path])
        lastOperationMessage = "已清理残留：\(residual.applicationName) (\(ByteCountFormatter.string(fromByteCount: result.movedBytes, countStyle: .file)))"
        await scan()
    }

    func cleanupAllResiduals() async {
        guard !isUninstalling, !residuals.isEmpty else { return }
        isUninstalling = true
        defer { isUninstalling = false }

        let paths = residuals.map(\.path)
        let result = await uninstaller.uninstall(paths: paths)
        lastOperationMessage = "已清理 \(result.successCount) 项残留，释放 \(ByteCountFormatter.string(fromByteCount: result.movedBytes, countStyle: .file))"
        await scan()
    }
}
