import Cocoa
import SwiftUI

/// 浮动窗口控制器，管理截图结果和翻译界面的显示
class FloatingWindowController: NSObject, NSWindowDelegate {
    
    // MARK: - Properties
    
    var panel: FloatingPanel!
    
    private let translationSize = NSSize(width: 420, height: 450)
    private let screenshotSize = NSSize(width: 900, height: 600)
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        
        let hostingView = NSHostingView(rootView: RootView())
        
        panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            backing: .buffered,
            defer: false
        )
        panel.contentView = hostingView
        panel.backgroundColor = .clear
        panel.delegate = self
        panel.orderOut(nil)
    }
    
    // MARK: - Public Methods
    
    func toggleWindow() {
        panel.isVisible ? closeWindow() : showWindow()
    }
    
    func closeWindow() {
        panel.orderOut(nil)
    }
    
    func showWindow() {
        guard let screen = screenForMouse() else { return }
        
        let mode = AppState.shared.mode
        let targetSize = calculateSize(for: mode)
        let origin = calculateOrigin(for: mode, size: targetSize, screen: screen)
        
        configureWindowConstraints(for: mode)
        
        // 同步显示流程，确保 100% 可靠
        NSApp.activate(ignoringOtherApps: true)
        panel.alphaValue = 1.0
        panel.setFrame(NSRect(origin: origin, size: targetSize), display: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        
        // 双重保险：延迟再次激活
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.panel.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    // MARK: - Private Helpers
    
    private func screenForMouse() -> NSScreen? {
        let mouseLoc = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouseLoc, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }
    
    private func calculateSize(for mode: AppMode) -> NSSize {
        if mode == .translation {
            return translationSize
        }
        
        if let saved = UserDefaults.standard.string(forKey: "WindowSize_Screenshot") {
            let size = NSSizeFromString(saved)
            if size.width > 200 && size.height > 200 {
                return size
            }
        }
        return screenshotSize
    }
    
    private func calculateOrigin(for mode: AppMode, size: NSSize, screen: NSScreen) -> NSPoint {
        let screenRect = screen.visibleFrame
        let mouseLoc = NSEvent.mouseLocation
        
        var origin: NSPoint
        if mode == .translation {
            origin = NSPoint(x: mouseLoc.x - size.width / 2, y: mouseLoc.y - size.height - 10)
        } else {
            origin = NSPoint(x: screenRect.midX - size.width / 2, y: screenRect.midY - size.height / 2)
        }
        
        // 边界安全校验
        origin.x = max(screenRect.minX + 10, min(origin.x, screenRect.maxX - size.width - 10))
        origin.y = max(screenRect.minY + 10, min(origin.y, screenRect.maxY - size.height - 10))
        
        return origin
    }
    
    private func configureWindowConstraints(for mode: AppMode) {
        if mode == .translation {
            panel.minSize = translationSize
            panel.maxSize = translationSize
        } else {
            panel.minSize = NSSize(width: 600, height: 400)
            panel.maxSize = NSSize(width: 1600, height: 1200)
        }
    }
    
    // MARK: - NSWindowDelegate
    
    func windowDidResignKey(_ notification: Notification) {
        if AppState.shared.mode == .translation {
            closeWindow()
        }
    }
    
    func windowDidResignMain(_ notification: Notification) {
        if AppState.shared.mode == .translation {
            closeWindow()
        }
    }
    
    func windowDidResize(_ notification: Notification) {
        if AppState.shared.mode != .translation {
            let sizeString = NSStringFromSize(panel.frame.size)
            UserDefaults.standard.set(sizeString, forKey: "WindowSize_Screenshot")
        }
    }
}
