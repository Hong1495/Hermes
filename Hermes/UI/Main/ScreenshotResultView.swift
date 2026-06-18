import SwiftUI
import UniformTypeIdentifiers

struct ScreenshotResultView: View {
    @ObservedObject private var appState: AppState
    @ObservedObject var annotationState: AnnotationState

    @State private var showBorder = false
    @State private var showCornerRadius = false
    @State private var showShadow = true
    @State private var toastMessage: String?

    private let exportService = ScreenshotExportService.shared

    init(appState: AppState, annotationState: AnnotationState) {
        self.appState = appState
        self.annotationState = annotationState
    }

    var body: some View {
        VStack(spacing: 0) {
            annotationBar
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()
                .foregroundStyle(Theme.Colors.separator)

            stage
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toast(message: $toastMessage)
    }

    // MARK: - Toolbar

    private var annotationBar: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.small) {
            annotationTools

            styleToggles

            Spacer(minLength: Theme.Spacing.small)
            utilityButtons
        }
    }

    private var styleToggles: some View {
        HStack(spacing: 6) {
            Toggle("边框", isOn: $showBorder)
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(!hasImage)

            Toggle("圆角", isOn: $showCornerRadius)
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(!hasImage)

            Toggle("阴影", isOn: $showShadow)
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(!hasImage)
        }
    }

    private var annotationTools: some View {
        HStack(spacing: 4) {
            iconToolButton("cursorarrow", isActive: annotationState.currentTool == nil, disabled: !hasImage) {
                annotationState.currentTool = nil
            }
            iconToolButton("square", isActive: annotationState.currentTool == .rectangle, disabled: !hasImage) {
                annotationState.currentTool = .rectangle
            }
            iconToolButton("arrow.up.right", isActive: annotationState.currentTool == .arrow, disabled: !hasImage) {
                annotationState.currentTool = .arrow
            }
            iconToolButton("textformat", isActive: annotationState.currentTool == .text, disabled: !hasImage) {
                annotationState.currentTool = .text
            }
            iconToolButton("highlighter", isActive: annotationState.currentTool == .highlighter, disabled: !hasImage) {
                annotationState.currentTool = .highlighter
            }
            iconToolButton("pencil.tip", isActive: annotationState.currentTool == .freehand, disabled: !hasImage) {
                annotationState.currentTool = .freehand
            }
            iconToolButton("1.circle", isActive: annotationState.currentTool == .numberedMarker, disabled: !hasImage) {
                annotationState.currentTool = .numberedMarker
            }

            Button(action: {
                annotationState.undo()
            }) {
                Image(systemName: "arrow.uturn.backward")
                    .frame(width: 26, height: 26)
            }
            .modernStyle(.icon)
            .disabled(!annotationState.canUndo)

            Button(action: {
                annotationState.redo()
            }) {
                Image(systemName: "arrow.uturn.forward")
                    .frame(width: 26, height: 26)
            }
            .modernStyle(.icon)
            .disabled(!annotationState.canRedo)

            JapaneseColorPicker(selectedColor: $annotationState.selectedJapaneseColor)
                .disabled(!hasImage)
                .opacity(hasImage ? 1 : 0.55)
        }
    }

    private var utilityButtons: some View {
        HStack(spacing: 6) {
            toolbarButton("复制", systemImage: "square.on.square", style: .secondary) {
                copyImage()
            }
            .disabled(!hasImage)

            toolbarButton("保存", systemImage: "arrow.down.circle", style: .primary) {
                saveImage()
            }
            .disabled(!hasImage)
        }
    }

    // MARK: - Stage

    private var stage: some View {
        ZStack {
            Theme.Colors.workspaceBackground

            if let image = appState.capturedImage {
                GeometryReader { geometry in
                    let availableSize = CGSize(
                        width: max(geometry.size.width - 24, 100),
                        height: max(geometry.size.height - 24, 100)
                    )
                    let fittedRect = aspectFitRect(for: image.size, in: availableSize)

                    ZStack(alignment: .topLeading) {
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.high)

                        AnnotationCanvas(state: annotationState)
                    }
                    .frame(width: fittedRect.width, height: fittedRect.height)
                    .padding(showBorder ? 8 : 0)
                    .background(showBorder ? Theme.Colors.panelElevated : Color.clear)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: showCornerRadius ? Theme.CornerRadius.small : 0,
                            style: .continuous
                        )
                    )
                    .shadow(
                        color: showShadow ? .black.opacity(0.15) : .clear,
                        radius: showShadow ? 8 : 0,
                        y: showShadow ? 2 : 0
                    )
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
                .padding(12)
                .contentShape(Rectangle())
                .onTapGesture {
                    annotationState.requestCommitText = true
                }
            } else {
                emptyState
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.medium) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(Theme.Colors.textTertiary)

            VStack(spacing: 4) {
                Text("开始截图")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text("直接用快捷键触发截图，结果会显示在这里。")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: 480)
        .padding(Theme.Spacing.extraLarge)
    }

    // MARK: - Helpers

    private var hasImage: Bool {
        appState.capturedImage != nil
    }

    private func toolbarButton(
        _ title: String,
        systemImage: String,
        style: ModernButtonStyleType,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
        }
        .modernStyle(style)
    }

    private func iconToolButton(_ systemImage: String, isActive: Bool, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 26, height: 26)
                .background(isActive ? Theme.Colors.accentSoft : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(isActive ? Theme.Colors.accent : Theme.Colors.textSecondary)
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
    }

    private func aspectFitRect(for imageSize: CGSize, in availableSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(origin: .zero, size: availableSize)
        }

        let scale = min(availableSize.width / imageSize.width, availableSize.height / imageSize.height)
        let fittedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(origin: .zero, size: fittedSize)
    }

    // MARK: - Export Actions

    private func copyImage() {
        guard let original = appState.capturedImage else {
            toastMessage = "没有可导出的图片"
            return
        }
        guard let image = exportService.generateFinalImage(
            from: original,
            annotations: annotationState.annotations,
            showBorder: showBorder,
            showCornerRadius: showCornerRadius,
            showShadow: showShadow,
            captureMode: appState.lastCaptureMode
        ) else {
            toastMessage = "导出图片生成失败"
            return
        }

        exportService.copyToClipboard(image)
        toastMessage = "已复制到剪贴板"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.closeWindow()
        }
    }

    private func saveImage() {
        guard let original = appState.capturedImage else {
            toastMessage = "没有可保存的图片"
            return
        }
        guard let image = exportService.generateFinalImage(
            from: original,
            annotations: annotationState.annotations,
            showBorder: showBorder,
            showCornerRadius: showCornerRadius,
            showShadow: showShadow,
            captureMode: appState.lastCaptureMode
        ) else {
            toastMessage = "导出图片生成失败"
            return
        }

        let fileName = "Screenshot \(Date().formatted(date: .numeric, time: .shortened)).png"
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: ".")

        exportService.saveImage(image, fileName: fileName) { [self] result in
            switch result {
            case .success:
                self.toastMessage = "保存成功"
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.closeWindow()
                }
            case .encodeFailed:
                self.toastMessage = "图片编码失败"
            case .writeFailed:
                self.toastMessage = "文件写入失败，请检查权限或磁盘空间"
            case .userCancelled:
                break
            }
        }
    }

    private func closeWindow() {
        NotificationCenter.default.post(name: .closeFloatingWindow, object: nil)
    }
}

#if DEBUG
#Preview("Screenshot — Empty") {
    ScreenshotResultView(appState: AppState(), annotationState: AnnotationState())
        .frame(width: 800, height: 600)
}

#Preview("Screenshot — With Image") {
    let appState = AppState()
    let nsImage = NSImage(systemSymbolName: "photo", accessibilityDescription: nil)!
    appState.setScreenshot(nsImage, mode: .area)
    return ScreenshotResultView(appState: appState, annotationState: AnnotationState())
        .frame(width: 800, height: 600)
}
#endif
