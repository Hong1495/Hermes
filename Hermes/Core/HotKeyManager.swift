import Carbon
import Cocoa
import OSLog

class HotKeyManager {
    static let shared = HotKeyManager()

    private var hotKeyRefs: [String: EventHotKeyRef] = [:]
    private var handlers: [String: () -> Void] = [:]
    private var ids: [String: UInt32] = [:]
    private var currentId: UInt32 = 1
    private let logger = Logger(subsystem: "hera.Hermes", category: "HotKey")

    // Make init public if needed, or keep private for singleton
    private init() {
        installEventHandler()
    }

    func register(key: String, shortcut: Shortcut, handler: @escaping () -> Void) {
        // Unregister existing if any
        unregister(key: key)

        let id = currentId
        currentId += 1
        ids[key] = id

        var hotKeyRef: EventHotKeyRef?
        let modifierFlags = carbonFlags(from: shortcut.nsModifiers)
        let keyID = EventHotKeyID(signature: OSType(0x484B5953), id: id) // HKYS

        let err = RegisterEventHotKey(UInt32(shortcut.key.rawValue),
                                      modifierFlags,
                                      keyID,
                                      GetApplicationEventTarget(),
                                      0,
                                      &hotKeyRef)

        if err == noErr, let ref = hotKeyRef {
            hotKeyRefs[key] = ref
            handlers[key] = handler
        } else {
            logger.warning("快捷键注册失败 [\(key, privacy: .public)]: OSStatus=\(err)")
        }
    }
    
    func unregister(key: String) {
        if let ref = hotKeyRefs[key] {
            UnregisterEventHotKey(ref)
            hotKeyRefs.removeValue(forKey: key)
            handlers.removeValue(forKey: key)
            ids.removeValue(forKey: key)
        }
    }
    
    func updateHotKey(id: String, shortcut: Shortcut?) {
        guard let shortcut = shortcut else {
            unregister(key: id)
            return
        }
        
        if let handler = handlers[id] {
            register(key: id, shortcut: shortcut, handler: handler)
        }
    }
    
    // For initial registration using KeyCode/Modifiers
    func register(id: String, key: KeyCode, modifiers: NSEvent.ModifierFlags, handler: @escaping () -> Void) {
        let shortcut = Shortcut(key: key, modifiers: modifiers)
        register(key: id, shortcut: shortcut, handler: handler)
    }
    
    private func installEventHandler() {
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        
        InstallEventHandler(GetApplicationEventTarget(), { (_: EventHandlerCallRef?, event: EventRef?, _: UnsafeMutableRawPointer?) -> OSStatus in
            
            var hotKeyID = EventHotKeyID()
            let err = GetEventParameter(event,
                                        EventParamName(kEventParamDirectObject),
                                        EventParamType(typeEventHotKeyID),
                                        nil,
                                        MemoryLayout<EventHotKeyID>.size,
                                        nil,
                                        &hotKeyID)
            
            if err == noErr {
                // Find key string by validation ID
                if let (key, _) = HotKeyManager.shared.ids.first(where: { $0.value == hotKeyID.id }),
                   let handler = HotKeyManager.shared.handlers[key] {
                    handler()
                }
            }
            
            return noErr
        }, 1, &eventSpec, nil, nil)
    }

    private func carbonFlags(from modifiers: NSEvent.ModifierFlags) -> UInt32 {
        var flags: UInt32 = 0
        if modifiers.contains(.command) { flags |= UInt32(cmdKey) }
        if modifiers.contains(.option) { flags |= UInt32(optionKey) }
        if modifiers.contains(.control) { flags |= UInt32(controlKey) }
        if modifiers.contains(.shift) { flags |= UInt32(shiftKey) }
        return flags
    }
}

enum KeyCode: Int, Codable {
    case a = 0x00
    case s = 0x01
    case d = 0x02
    case f = 0x03
    case h = 0x04
    case g = 0x05
    case z = 0x06
    case x = 0x07
    case c = 0x08
    case v = 0x09
    case b = 0x0B
    case q = 0x0C
    case w = 0x0D
    case e = 0x0E
    case r = 0x0F
    case y = 0x10
    case t = 0x11
    case one = 0x12
    case two = 0x13
    case three = 0x14
    case four = 0x15
    case six = 0x16
    case five = 0x17
    case equal = 0x18
    case nine = 0x19
    case seven = 0x1A
    case minus = 0x1B
    case eight = 0x1C
    case zero = 0x1D
    case rightBracket = 0x1E
    case o = 0x1F
    case u = 0x20
    case leftBracket = 0x21
    case i = 0x22
    case p = 0x23
    case l = 0x25
    case j = 0x26
    case quote = 0x27
    case k = 0x28
    case semicolon = 0x29
    case backslash = 0x2A
    case comma = 0x2B
    case slash = 0x2C
    case n = 0x2D
    case m = 0x2E
    case period = 0x2F
    case grave = 0x32
    case keypadDecimal = 0x41
    case keypadMultiply = 0x43
    case keypadPlus = 0x45
    case keypadClear = 0x47
    case keypadDivide = 0x4B
    case keypadEnter = 0x4C
    case keypadMinus = 0x4E
    case keypadEquals = 0x51
    case keypad0 = 0x52
    case keypad1 = 0x53
    case keypad2 = 0x54
    case keypad3 = 0x55
    case keypad4 = 0x56
    case keypad5 = 0x57
    case keypad6 = 0x58
    case keypad7 = 0x59
    case keypad8 = 0x5B
    case keypad9 = 0x5C
    
    // Fallback for unknown keys (optional, but good for robustness when decoding)
    // case unknown = -1
}
