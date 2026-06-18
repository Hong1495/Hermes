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
