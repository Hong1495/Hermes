import SwiftUI
import Combine

// MARK: - Annotation Model
struct Annotation: Identifiable {
    let id = UUID()
    var type: AnnotationType
    
    // 归一化坐标 (0.0-1.0，相对于图片的比例)
    var normalizedStart: CGPoint
    var normalizedEnd: CGPoint
    
    var color: Color
    var text: String = "文字"
    
    enum AnnotationType {
        case rectangle
        case arrow
        case text
    }
    
    // 辅助方法：转换为绝对像素坐标
    func absoluteStart(canvasSize: CGSize) -> CGPoint {
        return CGPoint(
            x: normalizedStart.x * canvasSize.width,
            y: normalizedStart.y * canvasSize.height
        )
    }
    
    func absoluteEnd(canvasSize: CGSize) -> CGPoint {
        return CGPoint(
            x: normalizedEnd.x * canvasSize.width,
            y: normalizedEnd.y * canvasSize.height
        )
    }
}

// MARK: - Annotation State
class AnnotationState: ObservableObject {
    @Published var annotations: [Annotation] = []
    @Published var currentTool: Annotation.AnnotationType? = nil
    @Published var selectedJapaneseColor: JapaneseColor = JapaneseColorPalette.loadSelectedColor()
    var canvasSize: CGSize = .zero // Not @Published to avoid view update warnings
    @Published var selectedAnnotationId: UUID? = nil
    @Published var requestCommitText: Bool = false
    
    var selectedColor: Color {
        selectedJapaneseColor.color
    }
    
    func add(_ annotation: Annotation) {
        annotations.append(annotation)
    }
    
    func undo() {
        if !annotations.isEmpty {
            annotations.removeLast()
        }
    }
    
    func clear() {
        annotations.removeAll()
        selectedAnnotationId = nil
    }
    
    // 移动标注（使用归一化偏移）
    func moveAnnotation(id: UUID, by pixelOffset: CGSize) {
        guard let index = annotations.firstIndex(where: { $0.id == id }) else { return }
        guard canvasSize.width > 0 && canvasSize.height > 0 else { return }
        
        // 将像素偏移转换为归一化偏移
        let normalizedOffset = CGSize(
            width: pixelOffset.width / canvasSize.width,
            height: pixelOffset.height / canvasSize.height
        )
        
        // 应用偏移并严格限制在 0.0-1.0 范围内
        annotations[index].normalizedStart.x = clamp(annotations[index].normalizedStart.x + normalizedOffset.width)
        annotations[index].normalizedStart.y = clamp(annotations[index].normalizedStart.y + normalizedOffset.height)
        annotations[index].normalizedEnd.x = clamp(annotations[index].normalizedEnd.x + normalizedOffset.width)
        annotations[index].normalizedEnd.y = clamp(annotations[index].normalizedEnd.y + normalizedOffset.height)
    }
    
    private func clamp(_ value: CGFloat) -> CGFloat {
        return max(0.0, min(1.0, value))
    }
}

// MARK: - Helper Functions
extension CGPoint {
    // 将像素坐标转换为归一化坐标
    func normalized(in size: CGSize) -> CGPoint {
        guard size.width > 0 && size.height > 0 else { return .zero }
        return CGPoint(
            x: max(0.0, min(1.0, x / size.width)),
            y: max(0.0, min(1.0, y / size.height))
        )
    }
}
