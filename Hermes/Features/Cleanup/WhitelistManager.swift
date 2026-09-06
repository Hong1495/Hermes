import Combine
import Foundation

@MainActor
final class WhitelistManager: ObservableObject {
    static let shared = WhitelistManager()

    private let userDefaultsKey = "HermesCleanupWhitelist"

    @Published private(set) var excludedPaths: [String] = []

    init() {
        load()
    }

    func load() {
        self.excludedPaths = UserDefaults.standard.stringArray(forKey: userDefaultsKey) ?? []
    }

    func addPath(_ path: String) {
        let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
        guard !excludedPaths.contains(standardized) else { return }
        excludedPaths.append(standardized)
        save()
    }

    func removePath(_ path: String) {
        excludedPaths.removeAll { $0 == path }
        save()
    }

    func isExcluded(path: String) -> Bool {
        let candidate = URL(fileURLWithPath: path).standardizedFileURL.path
        return excludedPaths.contains { excluded in
            candidate == excluded || candidate.hasPrefix(excluded + "/")
        }
    }

    private func save() {
        UserDefaults.standard.set(excludedPaths, forKey: userDefaultsKey)
    }
}
