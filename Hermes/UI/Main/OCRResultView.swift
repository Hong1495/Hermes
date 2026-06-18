import SwiftUI

struct OCRResultView: View {
    let text: String
    @State private var editableText: String
    @State private var toastMessage: String?
    @State private var isEditing = false

    private let onClose: () -> Void

    init(text: String, onClose: @escaping () -> Void) {
        self.text = text
        self._editableText = State(initialValue: text)
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Image(systemName: "text.viewfinder")
                    .foregroundStyle(Theme.Colors.accent)
                Text("OCR 识别结果")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Button(action: { isEditing.toggle() }) {
                    Image(systemName: isEditing ? "checkmark.circle" : "pencil")
                        .foregroundStyle(isEditing ? Theme.Colors.accent : Theme.Colors.textSecondary)
                }
                .buttonStyle(.plain)

                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(editableText, forType: .string)
                    toastMessage = "已复制"
                }) {
                    Image(systemName: "doc.on.doc")
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .buttonStyle(.plain)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.Colors.panelElevated)

            Divider()
                .foregroundStyle(Theme.Colors.separator)

            // Content
            ScrollView {
                if isEditing {
                    TextEditor(text: $editableText)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .frame(minHeight: 200)
                        .padding(12)
                } else {
                    Text(editableText)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
            }
            .background(Theme.Colors.background)

            // Footer
            HStack {
                Text("\(editableText.count) 字符")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Colors.textTertiary)
                Spacer()
                Button("关闭") {
                    onClose()
                }
                .modernStyle(.secondary)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Theme.Colors.panelElevated)
        }
        .toast(message: $toastMessage)
    }
}
