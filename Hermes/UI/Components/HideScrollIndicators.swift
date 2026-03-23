import SwiftUI
import AppKit

extension View {
    /// 强制隐藏 macOS 下的滚动条（适用于 Form, TextEditor, ScrollView 等）
    func hideScrollIndicators() -> some View {
        self.modifier(HideScrollIndicatorModifier())
    }
}

struct HideScrollIndicatorModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(ScrollIndicatorHider())
    }
}

struct ScrollIndicatorHider: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            // 向上查找最近的 NSScrollView
            var current: NSView? = view
            while let candidate = current {
                if let scrollView = candidate as? NSScrollView {
                    scrollView.hasVerticalScroller = false
                    scrollView.hasHorizontalScroller = false
                    scrollView.autohidesScrollers = true
                    // 禁用滚动条但保留滚动功能
                    scrollView.verticalScroller?.isHidden = true
                    scrollView.horizontalScroller?.isHidden = true
                    break
                }
                current = candidate.superview
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}
