import Cocoa
import SwiftUI

@MainActor
final class MainWindowController: NSWindowController {
    init() {
        let hostingController = NSHostingController(rootView: MainView())
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Hermes"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.setContentSize(NSSize(width: 980, height: 680))
        window.minSize = NSSize(width: 900, height: 600)
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
