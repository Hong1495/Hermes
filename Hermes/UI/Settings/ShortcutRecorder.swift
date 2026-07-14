import SwiftUI
import Carbon

struct ShortcutRecorder: View {
    let key: String // UserDefaults key
    let defaultShortcut: Shortcut
    
    @State private var isRecording = false
    @State private var currentShortcut: Shortcut?
    @State private var recordedShortcut: Shortcut?
    @State private var validationMessage: String?
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Button(action: {
                validationMessage = nil
                recordedShortcut = nil
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

            if let validationMessage {
                Text(validationMessage)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
            }
        }
        .overlay(
            ShortcutMonitor(isRecording: $isRecording, shortcut: $recordedShortcut)
                .frame(width: 0, height: 0)
        )
        .onAppear {
            loadShortcut()
        }
        .onChange(of: recordedShortcut) { _, newValue in
            guard let newValue else { return }
            guard newValue.hasGlobalModifier else {
                validationMessage = "请至少使用 ⌘、⌥ 或 ⌃"
                return
            }
            guard !newValue.isSystemScreenshotShortcut else {
                validationMessage = "该组合是 macOS 系统截图快捷键"
                return
            }

            validationMessage = nil
            currentShortcut = newValue
            saveShortcut(newValue)
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
        switch key {
        case .a: return "A"
        case .b: return "B"
        case .c: return "C"
        case .d: return "D"
        case .e: return "E"
        case .f: return "F"
        case .g: return "G"
        case .h: return "H"
        case .i: return "I"
        case .j: return "J"
        case .k: return "K"
        case .l: return "L"
        case .m: return "M"
        case .n: return "N"
        case .o: return "O"
        case .p: return "P"
        case .q: return "Q"
        case .r: return "R"
        case .s: return "S"
        case .t: return "T"
        case .u: return "U"
        case .v: return "V"
        case .w: return "W"
        case .x: return "X"
        case .y: return "Y"
        case .z: return "Z"
        case .zero: return "0"
        case .one: return "1"
        case .two: return "2"
        case .three: return "3"
        case .four: return "4"
        case .five: return "5"
        case .six: return "6"
        case .seven: return "7"
        case .eight: return "8"
        case .nine: return "9"
        case .equal, .keypadEquals: return "="
        case .minus, .keypadMinus: return "-"
        case .leftBracket: return "["
        case .rightBracket: return "]"
        case .quote: return "'"
        case .semicolon: return ";"
        case .backslash: return "\\"
        case .comma: return ","
        case .period, .keypadDecimal: return "."
        case .slash, .keypadDivide: return "/"
        case .grave: return "`"
        case .keypadMultiply: return "*"
        case .keypadPlus: return "+"
        case .keypadClear: return "Clear"
        case .keypadEnter: return "Enter"
        case .keypad0: return "Num 0"
        case .keypad1: return "Num 1"
        case .keypad2: return "Num 2"
        case .keypad3: return "Num 3"
        case .keypad4: return "Num 4"
        case .keypad5: return "Num 5"
        case .keypad6: return "Num 6"
        case .keypad7: return "Num 7"
        case .keypad8: return "Num 8"
        case .keypad9: return "Num 9"
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
