import SwiftUI

struct AnnotationCanvas: View {
    @ObservedObject var state: AnnotationState

    @State private var currentDragStart: CGPoint?
    @State private var currentDragEnd: CGPoint?
    @State private var showingTextInput = false
    @State private var textInputPosition: CGPoint = .zero
    @State private var textInputValue = ""
    @State private var dragStartedWhileEditing = false
    @State private var draggingAnnotationId: UUID?
    @State private var dragOffset: CGSize = .zero
    @FocusState private var isTextFieldFocused: Bool
    @FocusState private var isCanvasFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    for annotation in state.annotations {
                        let isSelected = annotation.id == state.selectedAnnotationId
                        let isDragging = annotation.id == draggingAnnotationId

                        var displayAnnotation = annotation
                        if isDragging {
                            let normalizedOffset = CGSize(
                                width: dragOffset.width / max(size.width, 1),
                                height: dragOffset.height / max(size.height, 1)
                            )
                            displayAnnotation.normalizedStart.x += normalizedOffset.width
                            displayAnnotation.normalizedStart.y += normalizedOffset.height
                            displayAnnotation.normalizedEnd.x += normalizedOffset.width
                            displayAnnotation.normalizedEnd.y += normalizedOffset.height
                        }

                        drawAnnotation(displayAnnotation, canvasSize: size, in: &context, isSelected: isSelected)
                    }

                    if let start = currentDragStart, let end = currentDragEnd, let tool = state.currentTool {
                        let previewAnnotation = Annotation(
                            type: tool,
                            normalizedStart: start.normalized(in: size),
                            normalizedEnd: end.normalized(in: size),
                            color: state.selectedColor
                        )
                        drawAnnotation(previewAnnotation, canvasSize: size, in: &context, opacity: 0.55)
                    }
                }
                .allowsHitTesting(false)

                Color.clear
                    .contentShape(Rectangle())
                    .gesture(dragGesture(in: geometry.size))
                    .onTapGesture { location in
                        if showingTextInput {
                            commitTextAnnotation()
                            return
                        }

                        if state.currentTool == .text {
                            textInputPosition = clamp(point: location, to: geometry.size)
                            textInputValue = ""
                            showingTextInput = true
                            return
                        }

                        guard state.currentTool == nil else { return }

                        if let hitAnnotation = findAnnotation(at: location, canvasSize: geometry.size) {
                            state.selectedAnnotationId = hitAnnotation.id
                            isCanvasFocused = true
                            isTextFieldFocused = false
                        } else {
                            state.selectedAnnotationId = nil
                        }
                    }

                if showingTextInput {
                    TextField("输入标注", text: $textInputValue)
                        .textFieldStyle(.plain)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(state.selectedColor)
                        .frame(width: max(120, CGFloat(max(textInputValue.count, 4)) * 11 + 20))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Theme.Colors.panelElevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.small, style: .continuous)
                                .stroke(Theme.Colors.glassBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small, style: .continuous))
                        .offset(x: textInputPosition.x, y: textInputPosition.y)
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
                }
                if requested {
                    state.requestCommitText = false
                }
            }
            .onKeyPress(.delete) {
                guard state.selectedAnnotationId != nil else { return .ignored }
                state.deleteSelected()
                return .handled
            }
            .onKeyPress(.deleteForward) {
                guard state.selectedAnnotationId != nil else { return .ignored }
                state.deleteSelected()
                return .handled
            }
            .focused($isCanvasFocused)
            .focusable()
            .focusEffectDisabled()
        }
    }

    private func dragGesture(in canvasSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if showingTextInput || dragStartedWhileEditing {
                    if showingTextInput {
                        commitTextAnnotation()
                        dragStartedWhileEditing = true
                    }
                    return
                }

                let clampedStart = clamp(point: value.startLocation, to: canvasSize)
                let clampedLocation = clamp(point: value.location, to: canvasSize)

                if state.currentTool == nil && draggingAnnotationId == nil,
                   let hitAnnotation = findAnnotation(at: clampedStart, canvasSize: canvasSize) {
                    draggingAnnotationId = hitAnnotation.id
                    state.selectedAnnotationId = hitAnnotation.id
                }

                if draggingAnnotationId != nil {
                    dragOffset = CGSize(
                        width: value.translation.width,
                        height: value.translation.height
                    )
                    return
                }

                guard let tool = state.currentTool else { return }

                if tool == .text {
                    currentDragStart = clampedStart
                    currentDragEnd = clampedStart
                } else {
                    if currentDragStart == nil {
                        currentDragStart = clampedStart
                    }
                    currentDragEnd = clampedLocation
                }
            }
            .onEnded { value in
                defer { resetDrag() }

                if dragStartedWhileEditing {
                    dragStartedWhileEditing = false
                    return
                }

                if showingTextInput {
                    return
                }

                if let draggingAnnotationId {
                    state.moveAnnotation(id: draggingAnnotationId, by: dragOffset)
                    self.draggingAnnotationId = nil
                    dragOffset = .zero
                    return
                }

                guard let tool = state.currentTool, let start = currentDragStart else {
                    return
                }

                let end = clamp(point: value.location, to: canvasSize)

                if tool == .text {
                    textInputPosition = start
                    textInputValue = ""
                    showingTextInput = true
                    return
                }

                let annotation = Annotation(
                    type: tool,
                    normalizedStart: start.normalized(in: canvasSize),
                    normalizedEnd: end.normalized(in: canvasSize),
                    color: state.selectedColor
                )
                state.add(annotation)
                state.selectedAnnotationId = annotation.id
            }
    }

    private func commitTextAnnotation() {
        let trimmed = textInputValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmed.isEmpty {
            let normalizedPosition = textInputPosition.normalized(in: state.canvasSize)
            let annotation = Annotation(
                type: .text,
                normalizedStart: normalizedPosition,
                normalizedEnd: normalizedPosition,
                color: state.selectedColor,
                text: trimmed
            )
            state.add(annotation)
            state.selectedAnnotationId = annotation.id
        }

        showingTextInput = false
        textInputValue = ""
    }

    private func resetDrag() {
        currentDragStart = nil
        currentDragEnd = nil
    }

    private func clamp(point: CGPoint, to canvasSize: CGSize) -> CGPoint {
        CGPoint(
            x: max(0, min(point.x, canvasSize.width)),
            y: max(0, min(point.y, canvasSize.height))
        )
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
            return rect.insetBy(dx: -10, dy: -10).contains(point)
        case .arrow:
            return distanceFrom(point, toSegmentFrom: start, to: end) <= 12
        case .text:
            let textWidth = max(80, CGFloat(annotation.text.count) * 10)
            let textRect = CGRect(x: start.x, y: start.y, width: textWidth, height: 30)
            return textRect.insetBy(dx: -8, dy: -8).contains(point)
        }
    }

    private func distanceFrom(_ point: CGPoint, toSegmentFrom start: CGPoint, to end: CGPoint) -> CGFloat {
        let segmentDX = end.x - start.x
        let segmentDY = end.y - start.y
        let lengthSquared = segmentDX * segmentDX + segmentDY * segmentDY

        guard lengthSquared > 0 else {
            return hypot(point.x - start.x, point.y - start.y)
        }

        let projected = ((point.x - start.x) * segmentDX + (point.y - start.y) * segmentDY) / lengthSquared
        let t = max(0, min(1, projected))
        let projectedPoint = CGPoint(
            x: start.x + segmentDX * t,
            y: start.y + segmentDY * t
        )
        return hypot(point.x - projectedPoint.x, point.y - projectedPoint.y)
    }

    private func drawAnnotation(
        _ annotation: Annotation,
        canvasSize: CGSize,
        in context: inout GraphicsContext,
        isSelected: Bool = false,
        opacity: Double = 1.0
    ) {
        let color = annotation.color.opacity(opacity)
        let start = annotation.absoluteStart(canvasSize: canvasSize)
        let end = annotation.absoluteEnd(canvasSize: canvasSize)

        if isSelected {
            drawSelectionHighlight(start: start, end: end, type: annotation.type, in: &context)
        }

        switch annotation.type {
        case .rectangle:
            let rect = CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            )
            context.stroke(
                Path(roundedRect: rect, cornerRadius: Annotation.RenderStyle.cornerRadius),
                with: .color(color),
                style: StrokeStyle(lineWidth: Annotation.RenderStyle.lineWidth, lineCap: .round, lineJoin: .round)
            )
        case .arrow:
            var path = Path()
            path.move(to: start)
            path.addLine(to: end)

            let angle = atan2(end.y - start.y, end.x - start.x)
            let arrowLength: CGFloat = Annotation.RenderStyle.arrowLength
            let arrowAngle: CGFloat = Annotation.RenderStyle.arrowAngle

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

            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: Annotation.RenderStyle.lineWidth, lineCap: .round, lineJoin: .round)
            )
        case .text:
            let text = Text(annotation.text)
                .font(.system(size: Annotation.RenderStyle.textFontSize, weight: .medium))
                .foregroundStyle(color)
            context.draw(text, at: start, anchor: .topLeading)
        }
    }

    private func drawSelectionHighlight(
        start: CGPoint,
        end: CGPoint,
        type: Annotation.AnnotationType,
        in context: inout GraphicsContext
    ) {
        let highlightColor = Theme.Colors.accent.opacity(0.9)

        switch type {
        case .rectangle:
            let rect = CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            )
            context.stroke(
                Path(roundedRect: rect.insetBy(dx: -4, dy: -4), cornerRadius: 10),
                with: .color(highlightColor),
                style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
            )
        case .arrow, .text:
            context.fill(
                Path(ellipseIn: CGRect(x: start.x - 5, y: start.y - 5, width: 10, height: 10)),
                with: .color(highlightColor)
            )
        }
    }
}
