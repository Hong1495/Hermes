import SwiftUI

/// 应用根视图，根据当前模式切换显示截图结果或翻译界面
struct RootView: View {
    @ObservedObject var appState = AppState.shared
    
    var body: some View {
        ZStack {
            // 毛玻璃背景
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            // 内容区域
            Group {
                switch appState.mode {
                case .actions:
                    ScreenshotResultView()
                case .translation:
                    TranslationView()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.001))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}
