import Cocoa
import SwiftUI

/// 浮动窗口控制器，管理截图结果和翻译界面的显示
@MainActor
class FloatingWindowController: NSObject, NSWindowDelegate {

    // MARK: - Properties

    var panel: FloatingPanel!
    private let appState: AppState

    private let translationSize = NSSize(width: 820, height: 640)
    private let screenshotSize = NSSize(width: 1320, height: 860)

    /// 窗口刚显示后的宽限期：截图流程结束时 macOS 可能重新激活之前的应用，
    /// 触发 didActivateApplication 而误关窗口。宽限期内忽略自动关闭。
    private var suppressAutoCloseUntil = Date.distantPast
    private var activationTask: Task<Void, Never>?
    private var monitorSetupTask: Task<Void, Never>?

    // MARK: - Initialization

    init(appState: AppState) {
        self.appState = appState
        super.init()

        let hostingView = NSHostingView(rootView: RootView(appState: appState))

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
        activationTask?.cancel()
        activationTask = nil
        monitorSetupTask?.cancel()
        monitorSetupTask = nil
        panel.alphaValue = 0
        panel.orderOut(nil)
        removeEventMonitors()
    }

    func showWindow() {
        guard let screen = screenForMouse() else { return }

        // 清理旧的监听器，并开启自动关闭宽限期（防止截图结束后的应用重新激活误关窗口）
        removeEventMonitors()
        suppressAutoCloseUntil = Date().addingTimeInterval(1.2)

        let mode = appState.mode
        configureWindowConstraints(for: mode, screen: screen)
        let targetSize = calculateSize(for: mode, screen: screen)
        let origin = calculateOrigin(for: mode, size: targetSize, screen: screen)

        // 先把面板加入窗口层级，再激活 accessory 应用。全局快捷键从后台触发时，
        // 对没有可见窗口的 accessory 应用提前 activate 可能不会产生有效激活。
        panel.setFrame(NSRect(origin: origin, size: targetSize), display: true)
        panel.alphaValue = 1.0
        panel.orderFrontRegardless()
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

        // 双重保险：延迟再次激活
        activationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled, let self, self.panel.isVisible else { return }
            self.panel.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
        }

        // 窗口显示后再设置事件监听器，避免 screencapture 残留事件导致的时序竞争
        monitorSetupTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled, let self, self.panel.isVisible else { return }
            self.setupEventMonitors()
        }
    }

    // MARK: - Private Helpers

    private func screenForMouse() -> NSScreen? {
        let mouseLoc = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouseLoc, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    private func calculateSize(for mode: AppMode, screen: NSScreen) -> NSSize {
        let availableWidth = max(1, screen.visibleFrame.width - 20)
        let availableHeight = max(1, screen.visibleFrame.height - 20)
        let preferredSize: NSSize
        if mode == .translation {
            preferredSize = translationSize
        } else if let saved = UserDefaults.standard.string(forKey: AppSettings.Key.windowSizeScreenshot) {
            let savedSize = NSSizeFromString(saved)
            preferredSize = savedSize.width > 200 && savedSize.height > 200
                ? NSSize(
                    width: max(savedSize.width, screenshotSize.width),
                    height: max(savedSize.height, screenshotSize.height)
                )
                : screenshotSize
        } else {
            preferredSize = screenshotSize
        }
        return NSSize(width: min(preferredSize.width, availableWidth), height: min(preferredSize.height, availableHeight))
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
        let maxX = max(screenRect.minX + 10, screenRect.maxX - size.width - 10)
        let maxY = max(screenRect.minY + 10, screenRect.maxY - size.height - 10)
        origin.x = min(max(screenRect.minX + 10, origin.x), maxX)
        origin.y = min(max(screenRect.minY + 10, origin.y), maxY)

        return origin
    }

    private func configureWindowConstraints(for mode: AppMode, screen: NSScreen) {
        let availableSize = NSSize(
            width: max(1, screen.visibleFrame.width - 20),
            height: max(1, screen.visibleFrame.height - 20)
        )
        if mode == .translation {
            panel.minSize = NSSize(width: min(720, availableSize.width), height: min(560, availableSize.height))
            panel.maxSize = NSSize(
                width: max(panel.minSize.width, min(1100, availableSize.width)),
                height: max(panel.minSize.height, min(900, availableSize.height))
            )
        } else {
            panel.minSize = NSSize(width: min(1180, availableSize.width), height: min(760, availableSize.height))
            panel.maxSize = NSSize(
                width: max(panel.minSize.width, min(1800, availableSize.width)),
                height: max(panel.minSize.height, min(1280, availableSize.height))
            )
        }
    }

    // MARK: - Event Monitoring

    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var activationObserver: NSObjectProtocol?

    private func setupEventMonitors() {
        // 1. App Activation Monitor: 监听应用切换
        // 只有当用户切换到"普通应用"（如浏览器、Finder）时才自动关闭。
        // 如果切换到"辅助应用"（如剪贴板工具、截图工具，通常是 .accessory），则保持窗口显示，以便它们能完成操作（如粘贴）。
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
                    guard Date() >= self.suppressAutoCloseUntil else { return }

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
        if appState.mode != .translation {
            let sizeString = NSStringFromSize(panel.frame.size)
            UserDefaults.standard.set(sizeString, forKey: AppSettings.Key.windowSizeScreenshot)
        }
    }
}
