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
    @State private var freehandPoints: [CGPoint] = []
    @FocusState private var isTextFieldFocused: Bool
    @FocusState private var isCanvasFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    // Pass 1: dim overlay with highlighter holes punched through
                    let highlighters = state.annotations.filter { $0.type == .highlighter }
                    if !highlighters.isEmpty {
                        context.fill(
                            Path(CGRect(origin: .zero, size: size)),
                            with: .color(.black.opacity(0.35))
                        )
                        context.blendMode = .clear
                        for ann in highlighters {
                            let start = ann.absoluteStart(canvasSize: size)
                            let end = ann.absoluteEnd(canvasSize: size)
                            let rect = CGRect(
                                x: min(start.x, end.x),
                                y: min(start.y, end.y),
                                width: abs(end.x - start.x),
                                height: abs(end.y - start.y)
                            )
                            context.fill(
                                Path(roundedRect: rect, cornerRadius: Annotation.RenderStyle.cornerRadius),
                                with: .color(.clear)
                            )
                        }
                        context.blendMode = .normal
                    }

                    // Pass 2: draw non-highlighter annotations
                    for annotation in state.annotations where annotation.type != .highlighter {
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
                            if !displayAnnotation.pathPoints.isEmpty {
                                displayAnnotation.pathPoints = displayAnnotation.pathPoints.map { pt in
                                    CGPoint(x: pt.x + normalizedOffset.width, y: pt.y + normalizedOffset.height)
                                }
                            }
                        }

                        drawAnnotation(displayAnnotation, canvasSize: size, in: &context, isSelected: isSelected)
                    }

                    if !freehandPoints.isEmpty, state.currentTool == .freehand {
                        var path = Path()
                        let absPoints = freehandPoints.map { pt in
                            CGPoint(x: pt.x * size.width, y: pt.y * size.height)
                        }
                        if absPoints.count >= 2 {
                            path.move(to: absPoints[0])
                            for pt in absPoints.dropFirst() {
                                path.addLine(to: pt)
                            }
                            context.stroke(
                                path,
                                with: .color(state.selectedColor.opacity(0.55)),
                                style: StrokeStyle(lineWidth: Annotation.RenderStyle.lineWidth, lineCap: .round, lineJoin: .round)
                            )
                        }
                    }

                    if let start = currentDragStart, let end = currentDragEnd, let tool = state.currentTool, tool != .freehand {
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
                        let clampedLocation = clamp(point: location, to: geometry.size)

                        if showingTextInput {
                            commitTextAnnotation()
                            return
                        }

                        if state.currentTool == .text {
                            textInputPosition = clampedLocation
                            textInputValue = ""
                            showingTextInput = true
                            return
                        }

                        if state.currentTool == .numberedMarker {
                            let normalizedCenter = clampedLocation.normalized(in: geometry.size)
                            let marker = Annotation(
                                type: .numberedMarker,
                                normalizedStart: normalizedCenter,
                                normalizedEnd: normalizedCenter,
                                color: state.selectedColor,
                                text: "\(state.markerCounter)"
                            )
                            state.add(marker)
                            state.selectedAnnotationId = marker.id
                            isCanvasFocused = true
                            return
                        }

                        guard state.currentTool == nil else { return }

                        if let hitAnnotation = findAnnotation(at: clampedLocation, canvasSize: geometry.size) {
                            state.selectedAnnotationId = hitAnnotation.id
                            isCanvasFocused = true
                            isTextFieldFocused = false
                        } else {
                            state.selectedAnnotationId = nil
                        }
                    }

                if showingTextInput {
                    let inputWidth = max(120, CGFloat(max(textInputValue.count, 4)) * 11 + 20) + 20
                    let inputHeight: CGFloat = 42
                    let inputX = min(max(0, textInputPosition.x), max(0, geometry.size.width - inputWidth))
                    let inputY = min(max(0, textInputPosition.y), max(0, geometry.size.height - inputHeight))
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
                        .offset(x: inputX, y: inputY)
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
            .onKeyPress { press in
                guard press.key == .init("z") else { return .ignored }
                guard !showingTextInput else { return .ignored }
                if press.modifiers == .command {
                    state.undo()
                    return .handled
                }
                if press.modifiers == [.command, .shift] {
                    state.redo()
                    return .handled
                }
                return .ignored
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
                    state.prepareMove()
                }

                if draggingAnnotationId != nil {
                    dragOffset = CGSize(
                        width: value.translation.width,
                        height: value.translation.height
                    )
                    return
                }

                guard let tool = state.currentTool else { return }

                if tool == .freehand {
                    freehandPoints.append(clampedLocation.normalized(in: canvasSize))
                } else if tool == .text {
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

                guard let tool = state.currentTool else { return }
                guard let start = currentDragStart else {
                    if tool == .freehand {
                        commitFreehand()
                    }
                    return
                }
                guard tool != .freehand else {
                    commitFreehand()
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
                isCanvasFocused = true
            }
    }

    private func commitFreehand() {
        guard freehandPoints.count >= 2 else { return }
        let annotation = Annotation(
            type: .freehand,
            normalizedStart: freehandPoints.first ?? .zero,
            normalizedEnd: freehandPoints.last ?? .zero,
            color: state.selectedColor,
            pathPoints: freehandPoints
        )
        state.add(annotation)
        state.selectedAnnotationId = annotation.id
        isCanvasFocused = true
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
        isCanvasFocused = true
    }

    private func resetDrag() {
        currentDragStart = nil
        currentDragEnd = nil
        freehandPoints = []
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
        case .rectangle, .highlighter:
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
        case .freehand:
            let absPoints = annotation.pathPoints.map { pt in
                CGPoint(x: pt.x * canvasSize.width, y: pt.y * canvasSize.height)
            }
            for i in 0..<max(0, absPoints.count - 1) {
                if distanceFrom(point, toSegmentFrom: absPoints[i], to: absPoints[i + 1]) <= 12 {
                    return true
                }
            }
            return false
        case .numberedMarker:
            return distanceFrom(point, toSegmentFrom: start, to: end) <= Annotation.RenderStyle.markerRadius + 4
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
            drawSelectionHighlight(start: start, end: end, type: annotation.type, annotation: annotation, canvasSize: canvasSize, in: &context)
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
        case .highlighter:
            // Rendered via dim overlay + clear blend hole above; nothing to draw here
            break
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
        case .freehand:
            guard annotation.pathPoints.count >= 2 else { break }
            let absPoints = annotation.pathPoints.map { pt in
                CGPoint(x: pt.x * canvasSize.width, y: pt.y * canvasSize.height)
            }
            var path = Path()
            path.move(to: absPoints[0])
            for pt in absPoints.dropFirst() {
                path.addLine(to: pt)
            }
            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: Annotation.RenderStyle.lineWidth, lineCap: .round, lineJoin: .round)
            )
        case .numberedMarker:
            let radius = Annotation.RenderStyle.markerRadius
            let center = start
            let circleRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: circleRect), with: .color(color))
            let numberText = Text(annotation.text)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
            context.draw(numberText, at: center, anchor: .center)
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
        annotation: Annotation? = nil,
        canvasSize: CGSize = .zero,
        in context: inout GraphicsContext
    ) {
        let highlightColor = Theme.Colors.accent.opacity(0.9)

        switch type {
        case .rectangle, .highlighter:
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
        case .freehand:
            guard let annotation, canvasSize.width > 0, canvasSize.height > 0 else { break }
            let absPoints = annotation.pathPoints.map { pt in
                CGPoint(x: pt.x * canvasSize.width, y: pt.y * canvasSize.height)
            }
            guard !absPoints.isEmpty else { break }
            let minX = absPoints.map(\.x).min()!
            let maxX = absPoints.map(\.x).max()!
            let minY = absPoints.map(\.y).min()!
            let maxY = absPoints.map(\.y).max()!
            let bounds = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            context.stroke(
                Path(roundedRect: bounds.insetBy(dx: -6, dy: -6), cornerRadius: 6),
                with: .color(highlightColor),
                style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
            )
        case .numberedMarker:
            let radius = Annotation.RenderStyle.markerRadius
            context.stroke(
                Path(ellipseIn: CGRect(x: start.x - radius - 4, y: start.y - radius - 4, width: (radius + 4) * 2, height: (radius + 4) * 2)),
                with: .color(highlightColor),
                style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
            )
        }
    }
}
