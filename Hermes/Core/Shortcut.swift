import Cocoa

/// 快捷键数据模型，可序列化到 UserDefaults。
struct Shortcut: Codable, Equatable {
    var key: KeyCode
    var modifiers: NSEvent.ModifierFlags.RawValue

    var nsModifiers: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifiers)
    }

    init(key: KeyCode, modifiers: NSEvent.ModifierFlags) {
        self.key = key
        self.modifiers = modifiers.rawValue
    }
}
