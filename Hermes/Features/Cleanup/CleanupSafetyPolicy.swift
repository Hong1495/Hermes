import Foundation

struct CleanupSafetyPolicy: Sendable {
    private let protectedPrefixes: [String]

    nonisolated init(fileManager: FileManager = .default) {
        let home = fileManager.homeDirectoryForCurrentUser.standardizedFileURL.path
        self.protectedPrefixes = [
            "/System",
            "/Library",
            "/usr",
            "/bin",
            "/sbin",
            "/private/etc",
            "/private/var/db",
            "/private/var/root",
            "\(home)/Documents",
            "\(home)/Desktop",
            "\(home)/Pictures",
            "\(home)/Music",
            "\(home)/Movies",
            "\(home)/Library/Mail",
            "\(home)/Library/Messages",
            "\(home)/Library/CloudStorage"
        ]
    }

    nonisolated func evaluate(path: String, allowedRoot: URL) -> CleanupSafetyDecision {
        let root = allowedRoot.standardizedFileURL
        let candidateURL = URL(fileURLWithPath: path).standardizedFileURL
        let rootPath = root.path
        let candidatePath = candidateURL.path

        guard candidatePath != "/" else {
            return .init(reason: .rootDirectory, normalizedPath: candidatePath)
        }
        guard isWithin(candidatePath, rootPath) else {
            return .init(reason: .outsideAllowedRoot, normalizedPath: candidatePath)
        }
        guard !protectedPrefixes.contains(where: { isWithin(candidatePath, $0) }) else {
            return .init(reason: .protectedSystemPath, normalizedPath: candidatePath)
        }
        guard FileManager.default.fileExists(atPath: candidatePath) else {
            return .init(reason: .missingPath, normalizedPath: candidatePath)
        }

        do {
            let values = try candidateURL.resourceValues(forKeys: [.isSymbolicLinkKey])
            if values.isSymbolicLink == true {
                return .init(reason: .symbolicLink, normalizedPath: candidatePath)
            }
        } catch {
            return .init(reason: .inaccessiblePath, normalizedPath: candidatePath)
        }

        return .init(reason: .allowed, normalizedPath: candidatePath)
    }

    nonisolated private func isWithin(_ path: String, _ root: String) -> Bool {
        path == root || path.hasPrefix(root.hasSuffix("/") ? root : root + "/")
    }
}
