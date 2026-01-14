import Cocoa

class FloatingPanel: NSPanel {
    init(contentRect: NSRect, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        // Borderless + resizable for floating utility window
        super.init(contentRect: contentRect, styleMask: [.borderless], backing: backing, defer: flag)
        
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Visuals
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovableByWindowBackground = false // Must be false so annotation gestures work
        
        // Native Blur Effect
        let visualEffect = NSVisualEffectView()
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.material = .sidebar // Standard macOS light/dark theme, lighter than hudWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 16
        visualEffect.layer?.masksToBounds = true
        visualEffect.layer?.borderWidth = 0.5 // Thinner, sharper border
        visualEffect.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor // Explicit glass edge
        
        self.contentView = visualEffect
        
        // We need to set the SwiftUI view as a subview of this visual effect view in the controller,
        // or just set contentView to NSHostingView and make it transparent?
        // Better approach: Make the window content view the VisualEffectView, and put the hosting view inside it.
    }
    
    // Allow the panel to become key so text fields work, even if it's "nonactivating"
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}
