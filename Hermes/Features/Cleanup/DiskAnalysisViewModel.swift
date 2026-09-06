import AppKit
import Combine
import Foundation

enum DiskViewMode: String, CaseIterable, Identifiable {
    case explorer
    case largeFiles

    var id: String { rawValue }
    var title: String {
        switch self {
        case .explorer: "目录层级"
        case .largeFiles: "Top 大文件"
        }
    }
}

@MainActor
final class DiskAnalysisViewModel: ObservableObject {
    @Published private(set) var currentURL: URL
    @Published private(set) var snapshot: DiskAnalysisSnapshot?
    @Published private(set) var isAnalyzing = false
    @Published var selectedMode: DiskViewMode = .explorer

    private var history: [URL] = []
    private let analyzer: DiskAnalyzer

    var canGoBack: Bool {
        !history.isEmpty
    }

    var breadcrumbs: [URL] {
        var crumbs: [URL] = []
        var temp = currentURL
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL

        while temp.path != "/" && temp.path.count >= home.path.count {
            crumbs.insert(temp, at: 0)
            if temp.path == home.path { break }
            temp = temp.deletingLastPathComponent()
        }
        return crumbs.isEmpty ? [currentURL] : crumbs
    }

    init(analyzer: DiskAnalyzer = DiskAnalyzer()) {
        self.analyzer = analyzer
        self.currentURL = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
    }

    func loadIfNeeded() async {
        if snapshot == nil && !isAnalyzing {
            await analyze(url: currentURL)
        }
    }

    func analyzeHome() async {
        history.removeAll()
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
        currentURL = home
        await analyze(url: home)
    }

    func navigateTo(url: URL) async {
        guard url.hasDirectoryPath || (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { return }
        history.append(currentURL)
        currentURL = url.standardizedFileURL
        await analyze(url: currentURL)
    }

    func goBack() async {
        guard let previous = history.popLast() else { return }
        currentURL = previous
        await analyze(url: currentURL)
    }

    func goToBreadcrumb(_ url: URL) async {
        guard url != currentURL else { return }
        history.append(currentURL)
        currentURL = url.standardizedFileURL
        await analyze(url: currentURL)
    }

    func analyze(url: URL) async {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        defer { isAnalyzing = false }
        snapshot = await analyzer.analyze(root: url)
    }

    func revealInFinder(path: String) {
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: (path as NSString).deletingLastPathComponent)
    }

    func moveToTrash(path: String) async {
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
        // 重新分析当前目录以刷新数据
        await analyze(url: currentURL)
    }
}
