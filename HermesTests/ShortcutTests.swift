import Cocoa
import Testing
@testable import Hermes

@Suite struct ShortcutTests {
    @Test func macOSScreenCaptureShortcutsAreReserved() {
        #expect(Shortcut(key: .three, modifiers: [.command, .shift]).isSystemScreenshotShortcut)
        #expect(Shortcut(key: .four, modifiers: [.command, .shift]).isSystemScreenshotShortcut)
        #expect(Shortcut(key: .five, modifiers: [.command, .shift]).isSystemScreenshotShortcut)
    }

    @Test func additionalModifierDoesNotMatchSystemScreenCapture() {
        let shortcut = Shortcut(key: .four, modifiers: [.command, .shift, .option])
        #expect(!shortcut.isSystemScreenshotShortcut)
    }

    @Test func globalShortcutRequiresCommandOptionOrControl() {
        #expect(!Shortcut(key: .o, modifiers: [.shift]).hasGlobalModifier)
        #expect(Shortcut(key: .o, modifiers: [.command, .shift]).hasGlobalModifier)
    }
}
