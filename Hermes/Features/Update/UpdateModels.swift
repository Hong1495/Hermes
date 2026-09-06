import Foundation

public struct ReleaseInfo: Sendable, Equatable {
    public let tagName: String
    public let version: String
    public let name: String
    public let body: String
    public let htmlURL: URL
    public let publishedAt: Date?
    public let assetURL: URL?
    public let assetName: String?
    public let assetSize: Int64?

    public init(
        tagName: String,
        version: String,
        name: String,
        body: String,
        htmlURL: URL,
        publishedAt: Date? = nil,
        assetURL: URL? = nil,
        assetName: String? = nil,
        assetSize: Int64? = nil
    ) {
        self.tagName = tagName
        self.version = version
        self.name = name
        self.body = body
        self.htmlURL = htmlURL
        self.publishedAt = publishedAt
        self.assetURL = assetURL
        self.assetName = assetName
        self.assetSize = assetSize
    }
}

public enum UpdateStatus: Sendable, Equatable {
    case idle
    case checking
    case upToDate(currentVersion: String)
    case available(ReleaseInfo)
    case failed(String)
}

public enum VersionComparator {
    /// Compares two version strings (e.g. "0.2.0" vs "0.1.0" or "v0.1.0" vs "0.1.0").
    /// Returns true if `remote` is strictly newer than `local`.
    public static func isVersion(_ remote: String, newerThan local: String) -> Bool {
        let remoteComponents = parse(remote)
        let localComponents = parse(local)

        let maxCount = max(remoteComponents.count, localComponents.count)
        for i in 0..<maxCount {
            let r = i < remoteComponents.count ? remoteComponents[i] : 0
            let l = i < localComponents.count ? localComponents[i] : 0
            if r > l { return true }
            if r < l { return false }
        }
        return false
    }

    /// Strips leading 'v' or 'V' and extracts integer segments separated by '.'
    public static func parse(_ versionString: String) -> [Int] {
        var clean = versionString.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.lowercased().hasPrefix("v") {
            clean.removeFirst()
        }
        // If there are pre-release suffixes like -beta or -rc, isolate the main semver
        if let dashIndex = clean.firstIndex(of: "-") {
            clean = String(clean[..<dashIndex])
        }
        return clean.split(separator: ".").compactMap { Int($0.filter { $0.isNumber }) }
    }
}
