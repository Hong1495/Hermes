import SwiftUI

struct ShortcutsSettingsView: View {
    var body: some View {
        Form {
            Section("截图") {
                ShortcutRow(title: "选区截图", icon: "viewfinder.crop.circle", key: "shortcut_capture", defaultShortcut: Shortcut(key: .x, modifiers: [.command, .shift]))
                ShortcutRow(title: "窗口截图", icon: "macwindow.on.rectangle", key: "shortcut_window", defaultShortcut: Shortcut(key: .w, modifiers: [.command, .shift]))
                ShortcutRow(title: "全屏截图", icon: "rectangle.inset.filled", key: "shortcut_screen", defaultShortcut: Shortcut(key: .s, modifiers: [.command, .shift]))
                ShortcutRow(title: "OCR 截图 (无界面)", icon: "text.viewfinder", key: "shortcut_ocr", defaultShortcut: Shortcut(key: .o, modifiers: [.command, .shift]))
            }
            
            Section("工具") {
                ShortcutRow(title: "翻译", icon: "character.book.closed", key: "shortcut_translate", defaultShortcut: Shortcut(key: .t, modifiers: [.command, .shift]))
            }
        }
        .formStyle(.grouped)
        .padding(.vertical)
    }
}

struct ShortcutRow: View {
    let title: String
    let icon: String
    let key: String
    let defaultShortcut: Shortcut
    
    var body: some View {
        HStack {
            Label {
                Text(title)
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ShortcutRecorder(key: key, defaultShortcut: defaultShortcut)
        }
        .padding(.vertical, 4)
    }
}
