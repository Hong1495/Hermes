import Foundation

actor SystemOptimizer {
    func execute(task: OptimizationTaskType) async -> OptimizationStatus {
        switch task {
        case .flushDNS:
            return runProcess(executable: "/usr/bin/dscacheutil", arguments: ["-flushcache"], successMessage: "DNS 解析缓存已成功刷新")

        case .rebuildQuickLook:
            return runProcess(executable: "/usr/bin/qlmanage", arguments: ["-r", "cache"], successMessage: "Quick Look 缩略图缓存服务已重置")

        case .clearFontCache:
            return runProcess(executable: "/usr/bin/atsutil", arguments: ["databases", "-removeUser"], successMessage: "用户字体数据库缓存已清除")

        case .purgeMemory:
            return runProcess(executable: "/usr/bin/purge", arguments: [], successMessage: "未活跃文件缓存已释放")

        case .rebuildLaunchServices:
            let lsregister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
            return runProcess(
                executable: lsregister,
                arguments: ["-kill", "-r", "-domain", "local", "-domain", "user"],
                successMessage: "启动服务关联数据库已重新注册"
            )

        case .rebuildSpotlight:
            return runProcess(
                executable: "/usr/bin/mdimport",
                arguments: ["-r", "/Applications"],
                successMessage: "已向 Spotlight 请求重新扫描并索引应用"
            )

        case .resetIconServices:
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            let script = "rm -rf '\(home)/Library/Caches/com.apple.iconservices'* 2>/dev/null; killall Dock 2>/dev/null || true"
            return runProcess(
                executable: "/bin/zsh",
                arguments: ["-c", script],
                successMessage: "图标缓存已重置，Dock 服务已重新唤醒"
            )
        }
    }

    private func runProcess(executable: String, arguments: [String], successMessage: String) -> OptimizationStatus {
        guard FileManager.default.fileExists(atPath: executable) else {
            return .failure("系统未找到组件：\(executable)")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                return .success(successMessage)
            } else {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return .failure("执行退出码 \(process.terminationStatus)：\(output.isEmpty ? "未能完成该任务" : output)")
            }
        } catch {
            return .failure(error.localizedDescription)
        }
    }
}
