import SwiftUI

struct AnnotationCanvas: View {
    @ObservedObject var state: AnnotationState
    
    @State private var currentDragStart: CGPoint? = nil
    @State private var currentDragEnd: CGPoint? = nil
    @State private var showingTextInput = false
    @State private var textInputPosition: CGPoint = .zero
    @State private var textInputValue: String = ""
    @FocusState private var isTextFieldFocused: Bool
    @FocusState private var isCanvasFocused: Bool
    @State private var dragStartedWhileEditing: Bool = false
    
    // For moving existing annotations
    @State private var draggingAnnotationId: UUID? = nil
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Draw annotations using Canvas
                Canvas { context, size in
                    for annotation in state.annotations {
                        let isSelected = annotation.id == state.selectedAnnotationId
                        let isDragging = annotation.id == draggingAnnotationId
                        
                        // Get absolute coordinates for display
                        var displayAnnotation = annotation
                        if isDragging {
                            // Apply drag offset in normalized space
                            let normalizedOffset = CGSize(
                                width: dragOffset.width / size.width,
                                height: dragOffset.height / size.height
                            )
                            displayAnnotation.normalizedStart.x += normalizedOffset.width
                            displayAnnotation.normalizedStart.y += normalizedOffset.height
                            displayAnnotation.normalizedEnd.x += normalizedOffset.width
                            displayAnnotation.normalizedEnd.y += normalizedOffset.height
                        }
                        
                        drawAnnotation(displayAnnotation, canvasSize: size, in: &context, isSelected: isSelected)
                    }
                    
                    // Draw current drag preview
                    if let start = currentDragStart, let end = currentDragEnd, let tool = state.currentTool {
                        let normalizedStart = start.normalized(in: size)
                        let normalizedEnd = end.normalized(in: size)
                        let previewAnnotation = Annotation(
                            type: tool,
                            normalizedStart: normalizedStart,
                            normalizedEnd: normalizedEnd,
                            color: state.selectedColor
                        )
                        drawAnnotation(previewAnnotation, canvasSize: size, in: &context, opacity: 0.6)
                    }
                }
                .allowsHitTesting(false)
                
                // Gesture layer
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                // If the drag started while editing, or we just started editing, 
                                // we only commit and then ignore for the rest of this drag.
                                if showingTextInput || dragStartedWhileEditing {
                                    if showingTextInput {
                                        commitTextAnnotation()
                                        dragStartedWhileEditing = true
                                    }
                                    return
                                }
                                
                                let bounds = geometry.size
                                let clampedStart = CGPoint(
                                    x: max(0, min(value.startLocation.x, bounds.width)),
                                    y: max(0, min(value.startLocation.y, bounds.height))
                                )
                                let clampedLocation = CGPoint(
                                    x: max(0, min(value.location.x, bounds.width)),
                                    y: max(0, min(value.location.y, bounds.height))
                                )
                                
                                // Check if dragging existing annotation
                                if state.currentTool == nil && draggingAnnotationId == nil {
                                    if let hitAnnotation = findAnnotation(at: value.startLocation, canvasSize: bounds) {
                                        draggingAnnotationId = hitAnnotation.id
                                        DispatchQueue.main.async {
                                            state.selectedAnnotationId = hitAnnotation.id
                                        }
                                    }
                                }
                                
                                if draggingAnnotationId != nil {
                                    // Moving existing annotation
                                    dragOffset = CGSize(
                                        width: value.translation.width,
                                        height: value.translation.height
                                    )
                                } else if state.currentTool != nil {
                                    // Drawing new annotation
                                    if state.currentTool == .text {
                                        currentDragStart = clampedStart
                                        currentDragEnd = clampedStart
                                    } else {
                                        if currentDragStart == nil { currentDragStart = clampedStart }
                                        currentDragEnd = clampedLocation
                                    }
                                }
                            }
                            .onEnded { value in
                                if dragStartedWhileEditing {
                                    dragStartedWhileEditing = false
                                    return
                                }
                                if showingTextInput { return }
                                if let draggingId = draggingAnnotationId {
                                    // Commit annotation move
                                    state.moveAnnotation(id: draggingId, by: dragOffset)
                                    draggingAnnotationId = nil
                                    dragOffset = .zero
                                } else if let tool = state.currentTool, let start = currentDragStart {
                                    // Commit new annotation
                                    let bounds = geometry.size
                                    let end = CGPoint(
                                        x: max(0, min(value.location.x, bounds.width)),
                                        y: max(0, min(value.location.y, bounds.height))
                                    )
                                    
                                    if tool == .text {
                                        textInputPosition = start
                                        textInputValue = "文字"
                                        showingTextInput = true
                                    } else {
                                        // Convert to normalized coordinates
                                        let normalizedStart = start.normalized(in: bounds)
                                        let normalizedEnd = end.normalized(in: bounds)
                                        
                                        let annotation = Annotation(
                                            type: tool,
                                            normalizedStart: normalizedStart,
                                            normalizedEnd: normalizedEnd,
                                            color: state.selectedColor
                                        )
                                        DispatchQueue.main.async {
                                            state.add(annotation)
                                            state.selectedAnnotationId = annotation.id
                                        }
                                    }
                                }
                                
                                resetDrag()
                            }
                    )
                    .onTapGesture { location in
                        // Tap outside text field commits it
                        // Use a smaller threshold or just check if showingTextInput
                        if showingTextInput {
                            commitTextAnnotation()
                            return
                        }
                        
                        if state.currentTool == nil {
                            // Select annotation on tap
                            if let hitAnnotation = findAnnotation(at: location, canvasSize: geometry.size) {
                                DispatchQueue.main.async {
                                    state.selectedAnnotationId = hitAnnotation.id
                                    isCanvasFocused = true
                                    isTextFieldFocused = false
                                }
                            } else {
                                DispatchQueue.main.async {
                                    state.selectedAnnotationId = nil
                                }
                            }
                        } else if state.currentTool == .text {
                            textInputPosition = location
                            textInputValue = "文字"
                            showingTextInput = true
                        }
                    }
                
                // Text input overlay at mouse location
                if showingTextInput {
                    TextField("文字", text: $textInputValue)
                        .textFieldStyle(.plain)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(state.selectedColor)
                        .frame(width: max(100, CGFloat(textInputValue.count) * 12 + 20))
                        .padding(4)
                        .background(.white.opacity(0.9))
                        .cornerRadius(4)
                        .position(textInputPosition)
                        .multilineTextAlignment(.center)
                        .focused($isTextFieldFocused)
                        .task {
                            isTextFieldFocused = true
                        }
                        .onSubmit {
                            commitTextAnnotation()
                        }
                        .onExitCommand {
                            showingTextInput = false
                            textInputValue = ""
                        }
                }
            }
            .task {
                state.canvasSize = geometry.size
            }
            .onChange(of: geometry.size) { _, newSize in
                state.canvasSize = newSize
            }
            .onChange(of: state.requestCommitText) { _, requested in
                if requested && showingTextInput {
                    commitTextAnnotation()
                    state.requestCommitText = false
                }
            }
            .onKeyPress(.delete) {
                guard let selectedId = state.selectedAnnotationId else { return .ignored }
                DispatchQueue.main.async {
                    state.annotations.removeAll { $0.id == selectedId }
                    state.selectedAnnotationId = nil
                }
                return .handled
            }
            .onKeyPress(.deleteForward) {
                guard let selectedId = state.selectedAnnotationId else { return .ignored }
                DispatchQueue.main.async {
                    state.annotations.removeAll { $0.id == selectedId }
                    state.selectedAnnotationId = nil
                }
                return .handled
            }
            .contentShape(Rectangle())
            .focused($isCanvasFocused)
            .focusable()
            .focusEffectDisabled()
            
            // Hidden button for reliable delete shortcut
            Button("") {
                if let selectedId = state.selectedAnnotationId {
                    DispatchQueue.main.async {
                        state.annotations.removeAll { $0.id == selectedId }
                        state.selectedAnnotationId = nil
                    }
                }
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.delete, modifiers: [])
            .opacity(0)
            
            Button("") {
                if let selectedId = state.selectedAnnotationId {
                    DispatchQueue.main.async {
                        state.annotations.removeAll { $0.id == selectedId }
                        state.selectedAnnotationId = nil
                    }
                }
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.deleteForward, modifiers: [])
            .opacity(0)
        }
    }
    
    
    // MARK: - Helper Functions
    private func commitTextAnnotation() {
        if !textInputValue.isEmpty {
            let normalizedPos = textInputPosition.normalized(in: state.canvasSize)
            let annotation = Annotation(
                type: .text,
                normalizedStart: normalizedPos,
                normalizedEnd: normalizedPos,
                color: state.selectedColor,
                text: textInputValue
            )
            DispatchQueue.main.async {
                self.state.add(annotation)
                self.state.selectedAnnotationId = annotation.id
            }
        }
        showingTextInput = false
        textInputValue = ""
    }
    
    private func resetDrag() {
        currentDragStart = nil
        currentDragEnd = nil
    }
    
    private func isNearPosition(_ point: CGPoint, _ target: CGPoint, threshold: CGFloat = 80) -> Bool {
        let dx = point.x - target.x
        let dy = point.y - target.y
        return sqrt(dx * dx + dy * dy) < threshold
    }
    
    private func findAnnotation(at point: CGPoint, canvasSize: CGSize) -> Annotation? {
        for annotation in state.annotations.reversed() {
            if annotationContains(annotation, point: point, canvasSize: canvasSize) {
                return annotation
            }
        }
        return nil
    }
    
    private func annotationContains(_ annotation: Annotation, point: CGPoint, canvasSize: CGSize) -> Bool {
        let hitMargin: CGFloat = 10
        let start = annotation.absoluteStart(canvasSize: canvasSize)
        let end = annotation.absoluteEnd(canvasSize: canvasSize)
        
        switch annotation.type {
        case .rectangle:
            let rect = CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            )
            return rect.insetBy(dx: -hitMargin, dy: -hitMargin).contains(point)
            
        case .arrow:
            let lineRect = CGRect(
                x: min(start.x, end.x) - hitMargin,
                y: min(start.y, end.y) - hitMargin,
                width: abs(end.x - start.x) + hitMargin * 2,
                height: abs(end.y - start.y) + hitMargin * 2
            )
            return lineRect.contains(point)
            
        case .text:
            let textRect = CGRect(x: start.x, y: start.y - 20, width: 100, height: 40)
            return textRect.contains(point)
        }
    }
    
    // MARK: - Drawing Functions
    private func drawAnnotation(_ annotation: Annotation, canvasSize: CGSize, in context: inout GraphicsContext, isSelected: Bool = false, opacity: Double = 1.0) {
        let color = annotation.color.opacity(opacity)
        
        // Convert normalized to absolute coordinates
        let start = annotation.absoluteStart(canvasSize: canvasSize)
        let end = annotation.absoluteEnd(canvasSize: canvasSize)
        
        // Draw selection highlight
        if isSelected {
            drawSelectionHighlight(start: start, end: end, type: annotation.type, in: &context)
        }
        
        switch annotation.type {
        case .rectangle:
            drawRectangle(from: start, to: end, color: color, in: &context)
            
        case .arrow:
            drawArrow(from: start, to: end, color: color, in: &context)
            
        case .text:
            drawText(annotation.text, at: start, color: color, in: &context)
        }
    }
    
    private func drawSelectionHighlight(start: CGPoint, end: CGPoint, type: Annotation.AnnotationType, in context: inout GraphicsContext) {
        let highlightColor = Color.blue
        
        switch type {
        case .rectangle:
            let rect = CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            )
            context.stroke(Path(roundedRect: rect.insetBy(dx: -3, dy: -3), cornerRadius: 6), with: .color(highlightColor), lineWidth: 2)
            
        case .arrow, .text:
            // Simple dot indicator at start point
            context.fill(Path(ellipseIn: CGRect(x: start.x - 5, y: start.y - 5, width: 10, height: 10)), with: .color(highlightColor))
        }
    }
    
    private func drawRectangle(from start: CGPoint, to end: CGPoint, color: Color, in context: inout GraphicsContext) {
        let rect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
        
        let path = Path(roundedRect: rect, cornerRadius: 4)
        context.stroke(path, with: .color(color), lineWidth: 3)
    }
    
    private func drawArrow(from start: CGPoint, to end: CGPoint, color: Color, in context: inout GraphicsContext) {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength: CGFloat = 15
        let arrowAngle: CGFloat = .pi / 6
        
        let tip1 = CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        )
        let tip2 = CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        )
        
        path.move(to: end)
        path.addLine(to: tip1)
        path.move(to: end)
        path.addLine(to: tip2)
        
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
    }
    
    private func drawText(_ text: String, at point: CGPoint, color: Color, in context: inout GraphicsContext) {
        let attributedString = AttributedString(text)
        let text = Text(attributedString)
            .font(.system(size: 18, weight: .medium))
            .foregroundColor(color)
        
        context.draw(text, at: point, anchor: .center)
    }
}
