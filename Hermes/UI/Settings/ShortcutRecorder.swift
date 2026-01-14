import SwiftUI
import Carbon

struct Shortcut: Codable, Equatable {
    var key: KeyCode
    var modifiers: NSEvent.ModifierFlags.RawValue
    
    var nsModifiers: NSEvent.ModifierFlags {
        return NSEvent.ModifierFlags(rawValue: modifiers)
    }
    
    init(key: KeyCode, modifiers: NSEvent.ModifierFlags) {
        self.key = key
        self.modifiers = modifiers.rawValue
    }
}

struct ShortcutRecorder: View {
    let key: String // UserDefaults key
    let defaultShortcut: Shortcut
    
    @State private var isRecording = false
    @State private var currentShortcut: Shortcut?
    
    var body: some View {
        Button(action: {
            isRecording = true
        }) {
            HStack {
                if isRecording {
                    Text("请输入快捷键...")
                        .foregroundColor(.gray)
                } else {
                    Text(shortcutString(for: currentShortcut))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.1)))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .overlay(
            ShortcutMonitor(isRecording: $isRecording, shortcut: $currentShortcut)
                .frame(width: 0, height: 0)
        )
        .onAppear {
            loadShortcut()
        }
        .onChange(of: currentShortcut) { _, newValue in
            saveShortcut(newValue)
            // HotKeyManager update triggers here or via observation elsewhere
            HotKeyManager.shared.updateHotKey(id: key, shortcut: newValue)
        }
    }
    
    private func shortcutString(for shortcut: Shortcut?) -> String {
        guard let shortcut = shortcut else { return "None" }
        
        var str = ""
        if shortcut.nsModifiers.contains(.control) { str += "⌃" }
        if shortcut.nsModifiers.contains(.option) { str += "⌥" }
        if shortcut.nsModifiers.contains(.shift) { str += "⇧" }
        if shortcut.nsModifiers.contains(.command) { str += "⌘" }
        
        str += keyString(for: shortcut.key)
        return str
    }
    
    private func keyString(for key: KeyCode) -> String {
        // Simple mapping for common keys, incomplete but sufficient for demo
        switch key {
        case .x: return "X"
        case .t: return "T"
        case .a: return "A"
        case .b: return "B"
            // ... Add more mappings or use Carbon functions to get key string
        default: return "\(key)"
        }
    }
    
    private func loadShortcut() {
        if let data = UserDefaults.standard.data(forKey: key),
           let shortcut = try? JSONDecoder().decode(Shortcut.self, from: data) {
            currentShortcut = shortcut
        } else {
            currentShortcut = defaultShortcut
        }
    }
    
    private func saveShortcut(_ shortcut: Shortcut?) {
        if let shortcut = shortcut,
           let data = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

struct ShortcutMonitor: NSViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var shortcut: Shortcut?
    
    func makeNSView(context: Context) -> MonitorView {
        let view = MonitorView()
        // Use a local monitor to capture keys even if focus is slightly off within the app
        view.startMonitoring { event in
            if isRecording {
                // Escape to cancel
                if event.keyCode == 53 { // Escape
                    DispatchQueue.main.async { isRecording = false }
                    return true
                }
                
                // Allow modifiers only events to pass through, but don't record them as final shortcut yet
                // Or better, just wait for a keydown that has a specific keycode + modifiers
                
                // Check valid key (not just modifier)
                // 65535 is often unrelated or pure modifier in legacy
                // But simplified: check event.type == .keyDown
                
                if let mappedKey = KeyCode(rawValue: Int(event.keyCode)) {
                    let pureFlags = event.modifierFlags.intersection([.command, .option, .control, .shift])
                    
                    // Don't record pure modifier presses usually
                    // But if user wants just a key, we allow it? Ideally modifier + key
                    // Let's accept any valid keypress
                    DispatchQueue.main.async {
                        shortcut = Shortcut(key: mappedKey, modifiers: pureFlags)
                        isRecording = false
                    }
                    return true // Consume event
                }
            }
            return false
        }
        return view
    }
    
    func updateNSView(_ nsView: MonitorView, context: Context) {
        // Could update state if needed
    }
}

class MonitorView: NSView {
    var monitor: Any?
    
    func startMonitoring(handler: @escaping (NSEvent) -> Bool) {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if handler(event) {
                return nil // Consume
            }
            return event
        }
    }
    
    deinit {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
