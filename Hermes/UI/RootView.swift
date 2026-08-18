import SwiftUI

struct RootView: View {
    @ObservedObject private var appState: AppState
    @StateObject private var annotationState = AnnotationState()

    init(appState: AppState) {
        self.appState = appState
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main content fills the entire panel
            Group {
                if let ocrText = appState.ocrResultText {
                    OCRResultView(text: ocrText) {
                        appState.ocrResultText = nil
                    }
                } else {
                    switch appState.mode {
                    case .actions:
                        ScreenshotResultView(appState: appState, annotationState: annotationState)
                    case .translation:
                        TranslationView(appState: appState)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if appState.isTranslating {
                HStack(spacing: 5) {
                    ProgressView()
                        .controlSize(.small)
                    Text("翻译中")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(10)
            }
        }
        .overlay(alignment: .bottom) {
            if let error = appState.errorMessage {
                errorBanner(error)
                    .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.background)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large, style: .continuous))
        .shadow(
            color: Theme.Shadows.panel.color,
            radius: Theme.Shadows.panel.radius,
            x: Theme.Shadows.panel.x,
            y: Theme.Shadows.panel.y
        )
        .contentShape(Rectangle())
        .gesture(WindowDragGesture())
        .onChange(of: appState.capturedImage) { _, _ in
            annotationState.clear()
        }
    }

    @ViewBuilder
    private func errorBanner(_ message: String) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.Colors.danger)
                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
            }

            if appState.errorIsPermissionRelated {
                Button("打开系统设置") {
                    openScreenCaptureSettings()
                }
                .modernStyle(.secondary)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Theme.Colors.panelElevated)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium, style: .continuous)
                .stroke(Theme.Colors.danger.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        .padding(.horizontal, 24)
    }

    private func openScreenCaptureSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}

#if DEBUG
#Preview("Root — Empty State") {
    RootView(appState: AppState())
        .frame(width: 600, height: 500)
}

#Preview("Root — Screenshot Mode") {
    let appState = AppState()
    let nsImage = NSImage(systemSymbolName: "photo", accessibilityDescription: nil)!
    appState.setScreenshot(nsImage, mode: .area)
    return RootView(appState: appState)
        .frame(width: 600, height: 500)
}

#Preview("Root — Translation Mode") {
    let appState = AppState()
    appState.prepareForTranslationWorkspace()
    appState.translationInput = "こんにちは世界"
    return RootView(appState: appState)
        .frame(width: 820, height: 640)
}
#endif
