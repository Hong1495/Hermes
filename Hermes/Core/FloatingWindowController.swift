import Cocoa
import SwiftUI

/// 浮动窗口控制器，管理截图结果和翻译界面的显示
@MainActor
class FloatingWindowController: NSObject, NSWindowDelegate {
    
    // MARK: - Properties
    
    var panel: FloatingPanel!
    
    private let translationSize = NSSize(width: 820, height: 640)
    private let screenshotSize = NSSize(width: 1320, height: 860)
    
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
        panel.alphaValue = 0
        panel.orderOut(nil)
        removeEventMonitors()
    }
    
    func showWindow() {
        guard let screen = screenForMouse() else { return }
        
        // 确保清理旧的监听器
        removeEventMonitors()
        setupEventMonitors()
        
        
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
                return NSSize(
                    width: max(size.width, screenshotSize.width),
                    height: max(size.height, screenshotSize.height)
                )
            }
        }
        return screenshotSize
    }
    
    private func calculateOrigin(for mode: AppMode, size: NSSize, screen: NSScreen) -> NSPoint {
        let screenRect = screen.visibleFrame
        let mouseLoc = NSEvent.mouseLocation
        
        var origin: NSPoint
        if mode == .translation {
            origin = NSPoint(x: mouseLoc.x - size.width / 2, y: mouseLoc.y - size.height / 2)
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
            panel.minSize = NSSize(width: 720, height: 560)
            panel.maxSize = NSSize(width: 1100, height: 900)
        } else {
            panel.minSize = NSSize(width: 1180, height: 760)
            panel.maxSize = NSSize(width: 1800, height: 1280)
        }
    }
    
    // MARK: - Event Monitoring
    
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var activationObserver: NSObjectProtocol?
    
    private func setupEventMonitors() {
        // 1. App Activation Monitor: 监听应用切换
        // 只有当用户切换到“普通应用”（如浏览器、Finder）时才自动关闭。
        // 如果切换到“辅助应用”（如剪贴板工具、截图工具，通常是 .accessory），则保持窗口显示，以便它们能完成操作（如粘贴）。
        if activationObserver == nil {
            activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                let activatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                Task { @MainActor [weak self] in
                    guard let self = self,
                          self.panel.isVisible else { return }

                    if let app = activatedApp {
                        if app.activationPolicy == .regular {
                            self.closeWindow()
                        }
                    }
                }
            }
        }
        
        // 2. Local Monitor: 监听应用内的点击
        if localMonitor == nil {
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }

                    if self.panel.isVisible && !self.isManagedWindow(event.window) {
                        self.closeWindow()
                    }
                }
                return event
            }
        }

        if globalMonitor == nil {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self, self.panel.isVisible else { return }

                    let mouseLocation = NSEvent.mouseLocation
                    if !self.isPointInsideManagedWindows(mouseLocation) {
                        self.closeWindow()
                    }
                }
            }
        }
    }

    private func isManagedWindow(_ window: NSWindow?) -> Bool {
        guard let window else { return false }

        if window == panel {
            return true
        }

        if panel.childWindows?.contains(where: { $0 == window }) == true {
            return true
        }

        if window.parent == panel {
            return true
        }

        // SwiftUI popover windows are not always attached as child windows immediately.
        if NSStringFromClass(type(of: window)).contains("Popover") {
            return true
        }

        return false
    }

    private func isPointInsideManagedWindows(_ point: NSPoint) -> Bool {
        if panel.frame.contains(point) {
            return true
        }

        if let childWindows = panel.childWindows,
           childWindows.contains(where: { $0.isVisible && $0.frame.contains(point) }) {
            return true
        }

        return NSApp.windows.contains { window in
            isManagedWindow(window) && window.isVisible && window.frame.contains(point)
        }
    }
    
    private func removeEventMonitors() {
        if let observer = activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            activationObserver = nil
        }
        
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }

        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
    }
    
    // MARK: - NSWindowDelegate
    
    func windowDidResize(_ notification: Notification) {
        if AppState.shared.mode != .translation {
            let sizeString = NSStringFromSize(panel.frame.size)
            UserDefaults.standard.set(sizeString, forKey: "WindowSize_Screenshot")
        }
    }
}
