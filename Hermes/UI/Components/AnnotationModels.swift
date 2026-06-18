import SwiftUI
import Combine

struct Annotation: Identifiable {
    let id = UUID()
    var type: AnnotationType
    var normalizedStart: CGPoint
    var normalizedEnd: CGPoint
    var color: Color
    var text: String = ""
    var pathPoints: [CGPoint] = []

    enum AnnotationType {
        case rectangle
        case arrow
        case text
        case highlighter
        case freehand
        case numberedMarker
    }

    enum RenderStyle {
        static let lineWidth: CGFloat = 3
        static let arrowLength: CGFloat = 16
        static let arrowAngle: CGFloat = .pi / 6
        static let cornerRadius: CGFloat = 8
        static let textFontSize: CGFloat = 18
        static let markerRadius: CGFloat = 16
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
    @Published var selectedAnnotationId: UUID? = nil
    @Published var requestCommitText: Bool = false
    var canvasSize: CGSize = .zero

    private var undoStack: [[Annotation]] = []
    private var redoStack: [[Annotation]] = []
    private var isUndoRedoOperation = false

    var selectedColor: Color {
        selectedJapaneseColor.color
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    var markerCounter: Int {
        let maxNumber = annotations
            .filter { $0.type == .numberedMarker }
            .compactMap { Int($0.text) }
            .max() ?? 0
        return maxNumber + 1
    }

    private func saveUndoState() {
        guard !isUndoRedoOperation else { return }
        undoStack.append(annotations)
        redoStack.removeAll()
        pruneUndoStack()
    }

    private func pruneUndoStack() {
        if undoStack.count > 50 {
            undoStack.removeFirst(undoStack.count - 50)
        }
    }

    func prepareMove() {
        saveUndoState()
    }

    func add(_ annotation: Annotation) {
        saveUndoState()
        annotations.append(annotation)
    }

    func undo() {
        guard !undoStack.isEmpty else { return }
        isUndoRedoOperation = true
        redoStack.append(annotations)
        annotations = undoStack.removeLast()
        isUndoRedoOperation = false
    }

    func redo() {
        guard !redoStack.isEmpty else { return }
        isUndoRedoOperation = true
        undoStack.append(annotations)
        annotations = redoStack.removeLast()
        isUndoRedoOperation = false
    }

    func clear() {
        saveUndoState()
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

        if !annotations[index].pathPoints.isEmpty {
            annotations[index].pathPoints = annotations[index].pathPoints.map { pt in
                CGPoint(
                    x: max(0, min(1, pt.x + clampedDX)),
                    y: max(0, min(1, pt.y + clampedDY))
                )
            }
        }
    }

    func deleteSelected() {
        guard let selectedAnnotationId else { return }
        saveUndoState()
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
