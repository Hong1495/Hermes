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
            configureScrollViews(around: view)
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configureScrollViews(around: nsView)
        }
    }

    private func configureScrollViews(around view: NSView) {
        var visited = Set<ObjectIdentifier>()

        if let windowRoot = view.window?.contentView {
            walk(view: windowRoot, visited: &visited)
        }

        var current: NSView? = view
        while let candidate = current {
            walk(view: candidate, visited: &visited)
            current = candidate.superview
        }
    }

    private func walk(view: NSView, visited: inout Set<ObjectIdentifier>) {
        let identifier = ObjectIdentifier(view)
        guard visited.insert(identifier).inserted else { return }

        if let scrollView = view as? NSScrollView {
            hideIndicators(in: scrollView)
        }

        if let textView = view as? NSTextView {
            textView.drawsBackground = false
            if let enclosing = textView.enclosingScrollView {
                hideIndicators(in: enclosing)
            }
        }

        for subview in view.subviews {
            walk(view: subview, visited: &visited)
        }
    }

    private func hideIndicators(in scrollView: NSScrollView) {
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.verticalScroller?.isHidden = true
        scrollView.horizontalScroller?.isHidden = true

        if let textView = scrollView.documentView as? NSTextView {
            textView.drawsBackground = false
        }
    }
}
