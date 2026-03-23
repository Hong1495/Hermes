import SwiftUI
import Combine

struct Annotation: Identifiable {
    let id = UUID()
    var type: AnnotationType
    var normalizedStart: CGPoint
    var normalizedEnd: CGPoint
    var color: Color
    var text: String = ""
    
    enum AnnotationType {
        case rectangle
        case arrow
        case text
    }

    func absoluteStart(canvasSize: CGSize) -> CGPoint {
        CGPoint(
            x: normalizedStart.x * canvasSize.width,
            y: normalizedStart.y * canvasSize.height
        )
    }

    func absoluteEnd(canvasSize: CGSize) -> CGPoint {
        CGPoint(
            x: normalizedEnd.x * canvasSize.width,
            y: normalizedEnd.y * canvasSize.height
        )
    }
}

final class AnnotationState: ObservableObject {
    @Published var annotations: [Annotation] = []
    @Published var currentTool: Annotation.AnnotationType? = nil
    @Published var selectedJapaneseColor: JapaneseColor = JapaneseColorPalette.loadSelectedColor()
    var canvasSize: CGSize = .zero
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
        currentTool = nil
        requestCommitText = false
    }
    
    func moveAnnotation(id: UUID, by pixelOffset: CGSize) {
        guard let index = annotations.firstIndex(where: { $0.id == id }) else { return }
        guard canvasSize.width > 0 && canvasSize.height > 0 else { return }

        let normalizedOffset = CGSize(
            width: pixelOffset.width / canvasSize.width,
            height: pixelOffset.height / canvasSize.height
        )

        let start = annotations[index].normalizedStart
        let end = annotations[index].normalizedEnd

        let minX = min(start.x, end.x)
        let maxX = max(start.x, end.x)
        let minY = min(start.y, end.y)
        let maxY = max(start.y, end.y)

        let clampedDX = max(-minX, min(normalizedOffset.width, 1 - maxX))
        let clampedDY = max(-minY, min(normalizedOffset.height, 1 - maxY))

        annotations[index].normalizedStart.x += clampedDX
        annotations[index].normalizedStart.y += clampedDY
        annotations[index].normalizedEnd.x += clampedDX
        annotations[index].normalizedEnd.y += clampedDY
    }

    func deleteSelected() {
        guard let selectedAnnotationId else { return }
        annotations.removeAll { $0.id == selectedAnnotationId }
        self.selectedAnnotationId = nil
    }
}

extension CGPoint {
    func normalized(in size: CGSize) -> CGPoint {
        guard size.width > 0 && size.height > 0 else { return .zero }
        return CGPoint(
            x: max(0.0, min(1.0, x / size.width)),
            y: max(0.0, min(1.0, y / size.height))
        )
    }
}
