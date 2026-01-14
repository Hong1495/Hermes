import Cocoa

class ScreenshotService {
    static let shared = ScreenshotService()
    
    private init() {}
    
    enum CaptureMode {
        case area
        case window
        case screen
    }

    func capture(mode: CaptureMode, completion: @escaping (NSImage?) -> Void) {
        let tempPath = NSTemporaryDirectory().appending("hermes_capture.png")
        let url = URL(fileURLWithPath: tempPath)
        
        // Remove existing
        try? FileManager.default.removeItem(at: url)
        
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        
        var arguments: [String] = []
        
        switch mode {
        case .area:
            arguments.append("-i") // Interactive
        case .window:
            arguments.append(contentsOf: ["-W"]) // Window mode (interactive implied by context usually, but -W often needs -i or not? Man page says -W: start in window selection mode. -i: interactive mode.)
            // "screencapture -iW [file]" is standard for window selection
            arguments.append("-i")
        case .screen:
            break
        }
        
        // Sound and Path
        arguments.append("-x") // No sound
        // arguments.append("-r") // Do not add shadow? User might want shadow. Default has shadow.
        arguments.append(tempPath)
        
        task.arguments = arguments
        
        task.terminationHandler = { _ in
            if FileManager.default.fileExists(atPath: tempPath) {
                let image = NSImage(contentsOfFile: tempPath)
                DispatchQueue.main.async {
                    completion(image)
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
        
        do {
            try task.run()
        } catch {
            print("Failed to launch screencapture: \(error)")
            completion(nil)
        }
    }
    
    // Legacy alias
    func captureInteractive(completion: @escaping (NSImage?) -> Void) {
        capture(mode: .area, completion: completion)
    }
}
