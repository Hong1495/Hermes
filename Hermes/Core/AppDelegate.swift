import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var windowController: FloatingWindowController?
    var settingsWindowController: SettingsWindowController?
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon if needed (can be done in Info.plist too)
        NSApp.setActivationPolicy(.accessory)
        
        windowController = FloatingWindowController()
        setupStatusItem()
        
        // Notification for auto-closing
        NotificationCenter.default.addObserver(forName: NSNotification.Name("CloseFloatingWindow"), object: nil, queue: .main) { [weak self] _ in
            self?.windowController?.closeWindow()
        }
        
        // Register default Hotkeys (using IDs for re-registration support)
        // If UserDefaults has values, HotKeyManager/ShortcutRecorder could load them, 
        // but for now we register defaults if not present, or just register what we have.
        // We'll trust ShortcutRecorder to update them if changed, but we need initial registration.
        // Ideally HotKeyManager would load from UserDefaults automatically, 
        // but given the structure, let's just register defaults.
        
        // Create initial shortcuts if needed by registering defaults
        // Note: Ideally moving these keys to a specific struct/enum would be cleaner
        
        // 1. Capture Area (X)
        loadAndRegister(key: "shortcut_capture", defaultKey: .x, defaultMods: [.command, .shift], handler: { [weak self] in
            self?.handleCapture(mode: .area)
        })
        
        // 2. Capture Window (W)
        loadAndRegister(key: "shortcut_window", defaultKey: .w, defaultMods: [.command, .shift], handler: { [weak self] in
            self?.handleCapture(mode: .window)
        })
        
        // 3. Capture Fullscreen (S)
        loadAndRegister(key: "shortcut_screen", defaultKey: .s, defaultMods: [.command, .shift], handler: { [weak self] in
            self?.handleCapture(mode: .screen)
        })
        
        // 4. OCR Capture (O) - Silent Mode
        loadAndRegister(key: "shortcut_ocr", defaultKey: .o, defaultMods: [.command, .shift], handler: { [weak self] in
            self?.ocrCaptureSilent()
        })
        
        // 5. Translate (T)
        loadAndRegister(key: "shortcut_translate", defaultKey: .t, defaultMods: [.command, .shift], handler: { [weak self] in
             print("Translate Triggered")
             DispatchQueue.main.async {
                 AppState.shared.mode = .translation
                 self?.windowController?.showWindow()
             }
        })
    }
    
    private func handleCapture(mode: ScreenshotService.CaptureMode) {
        print("📸 handleCapture called with mode: \(mode)")
        windowController?.closeWindow()
        
        // Delay slightly to ensure window animation finishes and isn't captured or reappearing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            print("📸 Starting capture...")
            ScreenshotService.shared.capture(mode: mode) { image in
                print("📸 Capture completed, image: \(image != nil)")
                guard let image = image else { return }
                DispatchQueue.main.async {
                    print("📸 Setting screenshot and showing window")
                    AppState.shared.mode = .actions
                    AppState.shared.setScreenshot(image)
                    self.windowController?.showWindow()
                }
            }
        }
    }
    
    // Helper to load from UserDefaults or use default
    private func loadAndRegister(key: String, defaultKey: KeyCode, defaultMods: NSEvent.ModifierFlags, handler: @escaping () -> Void) {
        if let data = UserDefaults.standard.data(forKey: key),
           let shortcut = try? JSONDecoder().decode(Shortcut.self, from: data) {
            HotKeyManager.shared.register(key: key, shortcut: shortcut, handler: handler)
        } else {
            HotKeyManager.shared.register(id: key, key: defaultKey, modifiers: defaultMods, handler: handler)
        }
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "cursorarrow.click.2", accessibilityDescription: "Hermes")
        }
        
        let menu = NSMenu()
        // Removed "Show Hermes" as requested
        menu.addItem(NSMenuItem(title: "设置...", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
        
        updateMenuBarVisibility()
        NotificationCenter.default.addObserver(self, selector: #selector(updateMenuBarVisibility), name: NSNotification.Name("UpdateMenuBarState"), object: nil)
    }
    
    @objc func updateMenuBarVisibility() {
        let shouldHide = UserDefaults.standard.bool(forKey: "hideMenuBarIcon")
        statusItem?.isVisible = !shouldHide
    }
    
    @objc func showApp() {
        windowController?.showWindow()
    }
    
    @objc func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func ocrCaptureSilent() {
        windowController?.closeWindow()
        // Wait for window to close
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            ScreenshotService.shared.capture(mode: .area) { image in
                guard let image = image else { return }
                DispatchQueue.main.async {
                    OCRService.shared.recognizeText(from: image) { text in
                        if let text = text, !text.isEmpty {
                            let pb = NSPasteboard.general
                            pb.clearContents()
                            pb.setString(text, forType: .string)
                            NSSound(named: "Glass")?.play()
                        }
                    }
                }
            }
        }
    }
    
    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}
