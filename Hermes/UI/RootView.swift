import SwiftUI

struct RootView: View {
    @ObservedObject var appState = AppState.shared
    
    var body: some View {
        ZStack {
            switch appState.mode {
            case .actions:
                ScreenshotResultView()
                    .transition(.opacity)
            case .translation:
                TranslationView()
                    .transition(.opacity)
            }
        }
        .frame(width: appState.mode == .translation ? 500 : 900) // Translation narrower, Screenshot wider (900)
        // Dynamic height is tricky with FloatingPanel because the window frame needs to update.
        // For now, let's keep it fixed or semi-fixed.
        .frame(minHeight: 400)
        .padding(.bottom, 1) // Tiny padding for border
    }
}
