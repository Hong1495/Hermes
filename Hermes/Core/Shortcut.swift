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

    var isSystemScreenshotShortcut: Bool {
        let relevant = nsModifiers.intersection([.command, .option, .control, .shift])
        guard relevant == [.command, .shift] else { return false }
        return key == .three || key == .four || key == .five
    }

    var hasGlobalModifier: Bool {
        !nsModifiers.intersection([.command, .option, .control]).isEmpty
    }
}
