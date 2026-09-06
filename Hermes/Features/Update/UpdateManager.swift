import AppKit
import Combine
import Foundation

public protocol UpdateServiceProtocol: Sendable {
    func fetchLatestRelease() async throws -> ReleaseInfo
}

public struct GitHubUpdateService: UpdateServiceProtocol {
    private let endpointURL: URL

    public init(endpointURL: URL = URL(string: "https://api.github.com/repos/Hong1495/Hermes/releases/latest")!) {
        self.endpointURL = endpointURL
    }

    public func fetchLatestRelease() async throws -> ReleaseInfo {
        var request = URLRequest(url: endpointURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Hermes-macOS-App", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 404 {
                throw NSError(domain: "HermesUpdate", code: 404, userInfo: [NSLocalizedDescriptionKey: "未找到公开发行版本"])
            }
            throw NSError(domain: "HermesUpdate", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "GitHub 服务返回异常代码: \(httpResponse.statusCode)"])
        }

        return try Self.parseRelease(from: data)
    }

    public static func parseRelease(from data: Data) throws -> ReleaseInfo {
        struct GitHubAsset: Decodable {
            let name: String
            let browser_download_url: String
            let size: Int64?
        }

        struct GitHubRelease: Decodable {
            let tag_name: String
            let name: String?
            let body: String?
            let html_url: String
            let published_at: String?
            let assets: [GitHubAsset]?
        }

        let decoder = JSONDecoder()
        let release = try decoder.decode(GitHubRelease.self, from: data)

        let tag = release.tag_name
        var cleanVer = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanVer.lowercased().hasPrefix("v") {
            cleanVer.removeFirst()
        }

        let isoFormatter = ISO8601DateFormatter()
        let publishedDate = release.published_at.flatMap { isoFormatter.date(from: $0) }

        var targetAssetURL: URL? = nil
        var targetAssetName: String? = nil
        var targetAssetSize: Int64? = nil

        if let assets = release.assets {
            // 优先选择包含 macOS / Hermes 的 zip 或 dmg 安装包
            let preferred = assets.first { asset in
                let n = asset.name.lowercased()
                return (n.hasSuffix(".zip") || n.hasSuffix(".dmg")) && (n.contains("macos") || n.contains("hermes"))
            } ?? assets.first { $0.name.hasSuffix(".zip") || $0.name.hasSuffix(".dmg") }

            if let chosen = preferred, let url = URL(string: chosen.browser_download_url) {
                targetAssetURL = url
                targetAssetName = chosen.name
                targetAssetSize = chosen.size
            }
        }

        guard let htmlURL = URL(string: release.html_url) else {
            throw URLError(.badURL)
        }

        return ReleaseInfo(
            tagName: tag,
            version: cleanVer,
            name: release.name?.isEmpty == false ? release.name! : tag,
            body: release.body ?? "",
            htmlURL: htmlURL,
            publishedAt: publishedDate,
            assetURL: targetAssetURL,
            assetName: targetAssetName,
            assetSize: targetAssetSize
        )
    }
}

@MainActor
public final class UpdateManager: ObservableObject {
    public static let shared = UpdateManager()

    @Published public private(set) var status: UpdateStatus = .idle
    @Published public private(set) var lastCheckDate: Date? = nil

    private let updateService: UpdateServiceProtocol

    public init(updateService: UpdateServiceProtocol = GitHubUpdateService()) {
        self.updateService = updateService
    }

    public var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }

    public var currentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    public func checkForUpdates(isUserInitiated: Bool = false) {
        status = .checking

        Task { @MainActor in
            do {
                let release = try await updateService.fetchLatestRelease()
                self.lastCheckDate = Date()

                if VersionComparator.isVersion(release.version, newerThan: self.currentVersion) {
                    self.status = .available(release)
                    if isUserInitiated {
                        self.presentUpdateAvailableAlert(release)
                    }
                } else {
                    self.status = .upToDate(currentVersion: self.currentVersion)
                    if isUserInitiated {
                        self.presentUpToDateAlert()
                    }
                }
            } catch {
                self.lastCheckDate = Date()
                let errorMsg = error.localizedDescription
                self.status = .failed(errorMsg)
                if isUserInitiated {
                    self.presentErrorAlert(error)
                }
            }
        }
    }

    public func openReleasePage(for release: ReleaseInfo) {
        NSWorkspace.shared.open(release.htmlURL)
    }

    public func downloadUpdate(for release: ReleaseInfo) {
        if let assetURL = release.assetURL {
            NSWorkspace.shared.open(assetURL)
        } else {
            openReleasePage(for: release)
        }
    }

    // MARK: - Alerts

    private func presentUpToDateAlert() {
        let alert = NSAlert()
        alert.messageText = "已是最新版本"
        alert.informativeText = "Hermes \(currentVersion) 当前已是最新版本，无需更新。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    private func presentUpdateAvailableAlert(_ release: ReleaseInfo) {
        let alert = NSAlert()
        alert.messageText = "发现新版本 \(release.tagName)"
        let previewNotes = release.body.trimmingCharacters(in: .whitespacesAndNewlines)
        alert.informativeText = """
        \(release.name) 现已发布。
        当前版本: v\(currentVersion)
        最新版本: \(release.tagName)

        \(previewNotes.isEmpty ? "建议升级以获取最新的功能与系统优化。" : previewNotes)
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "下载更新")
        alert.addButton(withTitle: "查看详情")
        alert.addButton(withTitle: "稍后")

        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            downloadUpdate(for: release)
        case .alertSecondButtonReturn:
            openReleasePage(for: release)
        default:
            break
        }
    }

    private func presentErrorAlert(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "检查更新失败"
        alert.informativeText = "无法获取 GitHub 升级服务信息，请检查您的网络连接或稍后重试。\n\n详情: \(error.localizedDescription)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "好")
        alert.runModal()
    }
}
