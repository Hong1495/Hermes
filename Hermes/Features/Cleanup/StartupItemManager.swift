import AppKit
import Combine
import Foundation

struct StartupItem: Identifiable, Sendable {
    let id: String
    let name: String
    let path: String
    let label: String
    let programPath: String?
    let isUserAgent: Bool
    var isEnabled: Bool
    let isMissingTarget: Bool
}

actor StartupItemManager {
    func scanStartupItems() -> [StartupItem] {
        var items: [StartupItem] = []

        let userAgentsURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
        items.append(contentsOf: scanDirectory(url: userAgentsURL, isUserAgent: true))

        let globalAgentsURL = URL(fileURLWithPath: "/Library/LaunchAgents", isDirectory: true)
        items.append(contentsOf: scanDirectory(url: globalAgentsURL, isUserAgent: false))

        return items
    }

    private func scanDirectory(url: URL, isUserAgent: Bool) -> [StartupItem] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else {
            return []
        }

        var results: [StartupItem] = []

        for file in files where file.pathExtension.lowercased() == "plist" {
            guard let dict = NSDictionary(contentsOf: file) as? [String: Any] else {
                continue
            }

            let label = dict["Label"] as? String ?? file.deletingPathExtension().lastPathComponent
            let disabled = dict["Disabled"] as? Bool ?? false

            var program: String? = nil
            if let p = dict["Program"] as? String {
                program = p
            } else if let args = dict["ProgramArguments"] as? [String], let first = args.first {
                program = first
            }

            let displayName = formatDisplayName(label: label, program: program)
            let isMissing = program != nil && !FileManager.default.fileExists(atPath: program!)

            results.append(StartupItem(
                id: file.path,
                name: displayName,
                path: file.path,
                label: label,
                programPath: program,
                isUserAgent: isUserAgent,
                isEnabled: !disabled,
                isMissingTarget: isMissing
            ))
        }

        return results
    }

    func disableItem(path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            return true
        } catch {
            return false
        }
    }

    private func formatDisplayName(label: String, program: String?) -> String {
        if let program = program {
            let appName = URL(fileURLWithPath: program).deletingPathExtension().lastPathComponent
            if !appName.isEmpty && appName != "sh" && appName != "bash" && appName != "zsh" {
                return appName
            }
        }
        let parts = label.split(separator: ".")
        if let last = parts.last {
            return String(last)
        }
        return label
    }
}
