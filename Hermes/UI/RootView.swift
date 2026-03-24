import SwiftUI

struct RootView: View {
    @ObservedObject private var appState = AppState.shared
    @StateObject private var annotationState = AnnotationState()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main content fills the entire panel
            Group {
                switch appState.mode {
                case .actions:
                    ScreenshotResultView(annotationState: annotationState)
                case .translation:
                    TranslationView()
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
