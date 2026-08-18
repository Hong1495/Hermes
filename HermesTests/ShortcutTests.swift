import Cocoa
import Testing
@testable import Hermes

@Suite struct ShortcutTests {
    @Test func systemScreenshotNumberShortcutsAreAllowed() {
        #expect(Shortcut(key: .three, modifiers: [.command, .shift]).hasGlobalModifier)
        #expect(Shortcut(key: .four, modifiers: [.command, .shift]).hasGlobalModifier)
        #expect(Shortcut(key: .five, modifiers: [.command, .shift]).hasGlobalModifier)
    }

    @Test func globalShortcutRequiresCommandOptionOrControl() {
        #expect(!Shortcut(key: .o, modifiers: [.shift]).hasGlobalModifier)
        #expect(Shortcut(key: .o, modifiers: [.command, .shift]).hasGlobalModifier)
    }
}
