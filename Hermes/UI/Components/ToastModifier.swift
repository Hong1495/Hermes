import SwiftUI

struct ToastModifier: ViewModifier {
    @Binding var message: String?
    let duration: TimeInterval

    init(message: Binding<String?>, duration: TimeInterval = 2.5) {
        _message = message
        self.duration = duration
    }

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let msg = message {
                    Text(msg)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.8))
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                        )
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task {
                            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                            withAnimation(.easeOut(duration: 0.2)) {
                                message = nil
                            }
                        }
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: message != nil)
    }
}

extension View {
    func toast(message: Binding<String?>, duration: TimeInterval = 2.5) -> some View {
        modifier(ToastModifier(message: message, duration: duration))
    }
}
