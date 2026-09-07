import Cocoa

/// 自定义无边框浮动面板，用于截图结果和翻译界面
class FloatingPanel: NSPanel {
    
    init(contentRect: NSRect, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: [.borderless], backing: backing, defer: flag)
        
        // 窗口行为配置
        self.isFloatingPanel = true
        self.level = .floating  // 足够覆盖常规窗口即可，screenSaver 会干扰 screencapture
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        
        // 视觉配置
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovableByWindowBackground = false
        self.hidesOnDeactivate = false
    }
    
    // MARK: - Window Behavior Overrides
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        NotificationCenter.default.post(name: .closeFloatingWindow, object: nil)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            NotificationCenter.default.post(name: .closeFloatingWindow, object: nil)
            return
        }
        super.keyDown(with: event)
    }
}
