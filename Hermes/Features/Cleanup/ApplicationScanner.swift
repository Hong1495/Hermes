import AppKit
import Foundation

struct ApplicationRelatedFile: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let path: String
    let name: String
    let relationship: String
    let size: Int64
    let isDirectory: Bool

    init(
        id: UUID = UUID(),
        path: String,
        name: String,
        relationship: String,
        size: Int64,
        isDirectory: Bool
    ) {
        self.id = id
        self.path = path
        self.name = name
        self.relationship = relationship
        self.size = size
        self.isDirectory = isDirectory
    }
}

struct InstalledApplication: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let bundleIdentifier: String
    let name: String
    let path: String
    let version: String?
    let isRunning: Bool
    let bundleSize: Int64
    let relatedFiles: [ApplicationRelatedFile]

    var size: Int64 {
        totalSize
    }

    var totalSize: Int64 {
        bundleSize + relatedFiles.reduce(0) { $0 + $1.size }
    }
}

struct ApplicationResidual: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let applicationID: String
    let applicationName: String
    let path: String
    let size: Int64
    let relationship: String
    let riskLevel: CleanupRiskLevel
    let selectedByDefault: Bool

    nonisolated init(
        id: UUID = UUID(),
        applicationID: String,
        applicationName: String,
        path: String,
        size: Int64,
        relationship: String,
        riskLevel: CleanupRiskLevel = .review,
        selectedByDefault: Bool = true
    ) {
        self.id = id
        self.applicationID = applicationID
        self.applicationName = applicationName
        self.path = path
        self.size = size
        self.relationship = relationship
        self.riskLevel = riskLevel
        self.selectedByDefault = selectedByDefault
    }
}

struct ApplicationScanSnapshot: Codable, Sendable {
    let applications: [InstalledApplication]
    let residuals: [ApplicationResidual]
    let skippedCount: Int
}

actor ApplicationScanner {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func scan() async -> ApplicationScanSnapshot {
        let applications = discoverApplications()
        let installedIdentifiers = Set(applications.map(\.bundleIdentifier))
        let installedNames = Set(applications.map { $0.name.lowercased() })
        let residualItems = orphanResiduals(excludingIdentifiers: installedIdentifiers, excludingNames: installedNames)
        return ApplicationScanSnapshot(applications: applications, residuals: residualItems, skippedCount: 0)
    }

    /// Lightweight path used by the cleanup flow. It avoids traversing every
    /// installed app bundle just to identify orphaned Library directories.
    func scanResiduals() async -> [ApplicationResidual] {
        let identifiers = discoverInstalledIdentifiers()
        let names = discoverInstalledNames()
        return orphanResiduals(excludingIdentifiers: identifiers, excludingNames: names)
    }

    private func discoverInstalledIdentifiers() -> Set<String> {
        discoverBundles().compactMap(\.bundleIdentifier).reduce(into: Set<String>()) { $0.insert($1) }
    }

    private func discoverInstalledNames() -> Set<String> {
        Set(discoverBundles().map { bundle in
            ((bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                ?? "").lowercased()
        }.filter { !$0.isEmpty })
    }

    private func discoverBundles() -> [Bundle] {
        let home = fileManager.homeDirectoryForCurrentUser
        let roots = [URL(fileURLWithPath: "/Applications", isDirectory: true), home.appendingPathComponent("Applications", isDirectory: true)]
        return roots.flatMap { root in
            (try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
        }.filter { $0.pathExtension.caseInsensitiveCompare("app") == .orderedSame }
            .compactMap { Bundle(url: $0) }
    }

    private func discoverApplications() -> [InstalledApplication] {
        let home = fileManager.homeDirectoryForCurrentUser
        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            home.appendingPathComponent("Applications", isDirectory: true)
        ]
        var results: [InstalledApplication] = []

        for root in roots where fileManager.fileExists(atPath: root.path) {
            guard let urls = try? fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in urls where url.pathExtension.caseInsensitiveCompare("app") == .orderedSame {
                guard let bundle = Bundle(url: url),
                      let bundleIdentifier = bundle.bundleIdentifier else { continue }

                let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                    ?? url.deletingPathExtension().lastPathComponent

                let running = NSWorkspace.shared.runningApplications.contains {
                    $0.bundleIdentifier == bundleIdentifier
                }
                let bundleSize = directorySize(url)
                let related = findRelatedFiles(bundleIdentifier: bundleIdentifier, appName: name)

                results.append(InstalledApplication(
                    id: bundleIdentifier,
                    bundleIdentifier: bundleIdentifier,
                    name: name,
                    path: url.path,
                    version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
                    isRunning: running,
                    bundleSize: bundleSize,
                    relatedFiles: related
                ))
            }
        }
        return results.sorted { $0.totalSize > $1.totalSize }
    }

    private func findRelatedFiles(bundleIdentifier: String, appName: String) -> [ApplicationRelatedFile] {
        let home = fileManager.homeDirectoryForCurrentUser
        let library = home.appendingPathComponent("Library", isDirectory: true)

        let candidatePaths: [(URL, String)] = [
            (library.appendingPathComponent("Application Support/\(appName)", isDirectory: true), "应用支持数据"),
            (library.appendingPathComponent("Application Support/\(bundleIdentifier)", isDirectory: true), "应用支持数据"),
            (library.appendingPathComponent("Caches/\(bundleIdentifier)", isDirectory: true), "应用缓存"),
            (library.appendingPathComponent("Caches/\(appName)", isDirectory: true), "应用缓存"),
            (library.appendingPathComponent("Preferences/\(bundleIdentifier).plist", isDirectory: false), "偏好设置"),
            (library.appendingPathComponent("Containers/\(bundleIdentifier)", isDirectory: true), "沙盒容器"),
            (library.appendingPathComponent("Saved Application State/\(bundleIdentifier).savedState", isDirectory: true), "恢复状态"),
            (library.appendingPathComponent("WebKit/\(bundleIdentifier)", isDirectory: true), "WebKit 存储"),
            (library.appendingPathComponent("HTTPStorages/\(bundleIdentifier)", isDirectory: true), "网络缓存"),
            (library.appendingPathComponent("Logs/\(appName)", isDirectory: true), "日志文件"),
            (library.appendingPathComponent("Logs/\(bundleIdentifier)", isDirectory: true), "日志文件")
        ]

        var found: [ApplicationRelatedFile] = []
        var visitedPaths = Set<String>()

        for (url, relationship) in candidatePaths {
            guard fileManager.fileExists(atPath: url.path), !visitedPaths.contains(url.path) else { continue }
            visitedPaths.insert(url.path)

            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
            let size = isDir ? directorySize(url) : (Int64((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0))

            found.append(ApplicationRelatedFile(
                path: url.path,
                name: url.lastPathComponent,
                relationship: relationship,
                size: size,
                isDirectory: isDir
            ))
        }

        return found.sorted { $0.size > $1.size }
    }

    private func orphanResiduals(excludingIdentifiers: Set<String>, excludingNames: Set<String>) -> [ApplicationResidual] {
        let home = fileManager.homeDirectoryForCurrentUser
        let roots: [(URL, String)] = [
            (home.appendingPathComponent("Library/Application Support", isDirectory: true), "应用支持残留"),
            (home.appendingPathComponent("Library/Caches", isDirectory: true), "应用缓存残留"),
            (home.appendingPathComponent("Library/Saved Application State", isDirectory: true), "应用状态残留")
        ]

        var results: [ApplicationResidual] = []

        for (root, relationship) in roots where fileManager.fileExists(atPath: root.path) {
            guard let urls = try? fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in urls {
                let name = url.lastPathComponent
                let cleanName = name.hasSuffix(".savedState") ? String(name.dropLast(11)) : name

                // 排除系统 Apple 自带的组件
                if cleanName.hasPrefix("com.apple.") || cleanName == "Apple" || cleanName == "System" || cleanName == "Dock" {
                    continue
                }

                // 判断是否是 bundle id 格式
                let isBundleID = cleanName.contains(".") && cleanName.split(separator: ".").count >= 2
                let appExists: Bool

                if isBundleID {
                    appExists = excludingIdentifiers.contains(cleanName)
                } else {
                    appExists = excludingNames.contains(cleanName.lowercased())
                }

                guard !appExists else { continue }

                // Residual discovery runs alongside the full cleanup scan. A
                // shallow estimate keeps large, abandoned containers from
                // blocking the result; cleanup still validates the path.
                let size = shallowSize(url)
                // 仅显示体积 >= 1MB 的残留项，避免过多杂讯
                guard size >= 1024 * 1024 else { continue }

                results.append(ApplicationResidual(
                    applicationID: cleanName,
                    applicationName: cleanName,
                    path: url.path,
                    size: size,
                    relationship: relationship,
                    riskLevel: .review,
                    selectedByDefault: false
                ))
            }
        }
        return results.sorted { $0.size > $1.size }
    }

    private func shallowSize(_ url: URL) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .totalFileSizeKey]),
              values.isDirectory == true else {
            return Int64(valuesOrZero(url).fileSize ?? 0)
        }
        let children = (try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .totalFileSizeKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return children.reduce(Int64(0)) { total, child in
            let childValues = valuesOrZero(child)
            return total + Int64(childValues.isDirectory == true ? (childValues.totalFileSize ?? 0) : (childValues.fileSize ?? childValues.totalFileSize ?? 0))
        }
    }

    private func valuesOrZero(_ url: URL) -> URLResourceValues {
        (try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .totalFileSizeKey])) ?? URLResourceValues()
    }

    private func directorySize(_ url: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .totalFileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return 0 }

        var total: Int64 = 0
        for case let child as URL in enumerator {
            if let values = try? child.resourceValues(forKeys: [.fileSizeKey, .totalFileSizeKey, .isDirectoryKey]),
               values.isDirectory != true {
                total += Int64(values.totalFileSize ?? values.fileSize ?? 0)
            }
        }
        return max(0, total)
    }
}
