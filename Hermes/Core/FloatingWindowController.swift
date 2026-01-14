import Cocoa
import SwiftUI

class FloatingWindowController: NSObject, NSWindowDelegate {
    var panel: FloatingPanel!
    
    override init() {
        super.init()
        
        // Initial Size can be adjusted; RootView will dictate size mostly.
        let contentView = RootView()
        let hostingView = NSHostingView(rootView: contentView)
        
        panel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 600, height: 500), backing: .buffered, defer: false)
        
        // Embed SwiftUI in the Visual Effect View
        if let visualEffectView = panel.contentView as? NSVisualEffectView {
            hostingView.frame = visualEffectView.bounds
            hostingView.autoresizingMask = [.width, .height]
            visualEffectView.addSubview(hostingView)
        }
        
        panel.delegate = self
        
        // Start hidden
        panel.orderOut(nil)
    }
    
    func toggleWindow() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            showWindow()
        }
    }
    
    func closeWindow() {
        panel.orderOut(nil)
    }
    
    func showWindow() {
        guard let screen = NSScreen.main else { return }
        
        // 1. Resize Panel based on Mode
        // We must sync this with RootView's frame logic
        var targetSize = NSSize(width: 600, height: 500) // Default fallback
        let modeKey = AppState.shared.mode == .translation ? "WindowSize_Translation" : "WindowSize_Screenshot"
        
        // Defaults if no saved size
        let defaultSize: NSSize
        if AppState.shared.mode == .translation {
            defaultSize = NSSize(width: 500, height: 320)
        } else {
            defaultSize = NSSize(width: 900, height: 600)
        }
        
        // Load from Persistence with reasonable limits
        if let savedString = UserDefaults.standard.string(forKey: modeKey) {
            let size = NSSizeFromString(savedString)
            // Validate: must be reasonable size (100-1200 width, 100-900 height)
            // REJECT the problematic 1389 size explicitly
            if size.width > 100 && size.width <= 1200 && size.height > 100 && size.height <= 900 {
                targetSize = size
                print("🪟 Loaded saved size: \(size)")
            } else {
                targetSize = defaultSize
                print("🪟 Saved size \(size) invalid (too large), using default: \(defaultSize)")
                // Clear the invalid size
                UserDefaults.standard.removeObject(forKey: modeKey)
            }
        } else {
            targetSize = defaultSize
            print("🪟 No saved size, using default: \(defaultSize)")
        }
        
        // Apply size FIRST
        var frame = panel.frame
        frame.size = targetSize
        panel.setFrame(frame, display: false)  // false to batch with position update
        
        // 2. Position Panel
        let windowSize = targetSize
        let screenRect = screen.visibleFrame
        
        var newOrigin = NSPoint.zero
        
        if AppState.shared.mode == .translation {
            // Follow Mouse
            let mouseLoc = NSEvent.mouseLocation
            newOrigin = NSPoint(x: mouseLoc.x - windowSize.width / 2, y: mouseLoc.y - windowSize.height - 20)
            
            // Clamp
            if newOrigin.x < screenRect.minX { newOrigin.x = screenRect.minX + 10 }
            else if newOrigin.x + windowSize.width > screenRect.maxX { newOrigin.x = screenRect.maxX - windowSize.width - 10 }
            if newOrigin.y < screenRect.minY { newOrigin.y = screenRect.minY + 10 }
            
        } else {
            // Screenshot / Default: Center of Screen
            newOrigin = NSPoint(
                x: screenRect.midX - windowSize.width / 2,
                y: screenRect.midY - windowSize.height / 2
            )
        }
        
        
        panel.setFrameOrigin(newOrigin)
        
        // Debug: Print to verify this is being called
        print("🪟 Showing window at \(newOrigin) with size \(targetSize)")
        
        // CRITICAL: Order front AFTER setting frame
        panel.alphaValue = 1.0
        panel.isOpaque = false
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        
        print("🪟 After orderFront - isVisible: \(panel.isVisible), level: \(panel.level.rawValue)")
        
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func windowDidResignKey(_ notification: Notification) {
        // Validation: Only Translation mode should auto-close when losing focus
        if AppState.shared.mode == .translation {
            panel.orderOut(nil)
        }
    }
    
    func windowDidResignMain(_ notification: Notification) {
        if AppState.shared.mode == .translation {
            panel.orderOut(nil)
        }
    }
    
    func windowDidResize(_ notification: Notification) {
        // Save current size to persistence
        let modeKey = AppState.shared.mode == .translation ? "WindowSize_Translation" : "WindowSize_Screenshot"
        let sizeString = NSStringFromSize(panel.frame.size)
        UserDefaults.standard.set(sizeString, forKey: modeKey)
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // In actions mode (screenshot), only allow closing via button
        // In translation mode, allow click-outside to close
        return AppState.shared.mode == .translation
    }
}
