import SwiftUI
import UniformTypeIdentifiers

struct ScreenshotResultView: View {
    @ObservedObject private var appState = AppState.shared
    @ObservedObject var annotationState: AnnotationState

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar: directly at top, no extra wrapping
            annotationBar
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()
                .foregroundStyle(Theme.Colors.separator)

            // Image stage: fills remaining space, no nested borders
            stage
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var annotationBar: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.small) {
            annotationTools
            Spacer(minLength: Theme.Spacing.small)
            utilityButtons
        }
    }

    private var annotationTools: some View {
        HStack(spacing: 4) {
            iconToolButton("cursorarrow", isActive: annotationState.currentTool == nil, disabled: !hasImage) {
                annotationState.currentTool = nil
            }
            iconToolButton("square", isActive: annotationState.currentTool == .rectangle, disabled: !hasImage) {
                annotationState.currentTool = .rectangle
            }
            iconToolButton("arrow.up.right", isActive: annotationState.currentTool == .arrow, disabled: !hasImage) {
                annotationState.currentTool = .arrow
            }
            iconToolButton("textformat", isActive: annotationState.currentTool == .text, disabled: !hasImage) {
                annotationState.currentTool = .text
            }

            Button(action: {
                annotationState.undo()
            }) {
                Image(systemName: "arrow.uturn.backward")
                    .frame(width: 26, height: 26)
            }
            .modernStyle(.icon)
            .disabled(annotationState.annotations.isEmpty)

            JapaneseColorPicker(selectedColor: $annotationState.selectedJapaneseColor)
                .disabled(!hasImage)
                .opacity(hasImage ? 1 : 0.55)
        }
    }

    private var utilityButtons: some View {
        HStack(spacing: 6) {
            toolbarButton("复制", systemImage: "square.on.square", style: .secondary) {
                copyImage()
            }
            .disabled(!hasImage)

            toolbarButton("保存", systemImage: "arrow.down.circle", style: .primary) {
                saveImage()
            }
            .disabled(!hasImage)
        }
    }

    private var stage: some View {
        ZStack {
            Theme.Colors.workspaceBackground

            if let image = appState.capturedImage {
                GeometryReader { geometry in
                    let availableSize = CGSize(
                        width: max(geometry.size.width - 24, 100),
                        height: max(geometry.size.height - 24, 100)
                    )
                    let fittedRect = aspectFitRect(for: image.size, in: availableSize)

                    ZStack(alignment: .topLeading) {
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: fittedRect.width, height: fittedRect.height)

                        AnnotationCanvas(state: annotationState)
                            .frame(width: fittedRect.width, height: fittedRect.height)
                    }
                    .frame(width: fittedRect.width, height: fittedRect.height)
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
                .padding(12)
                .contentShape(Rectangle())
                .onTapGesture {
                    annotationState.requestCommitText = true
                }
            } else {
                emptyState
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.medium) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(Theme.Colors.textTertiary)

            VStack(spacing: 4) {
                Text("开始截图")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text("直接用快捷键触发截图，结果会显示在这里。")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: 480)
        .padding(Theme.Spacing.extraLarge)
    }

    private var hasImage: Bool {
        appState.capturedImage != nil
    }

    private func toolbarButton(
        _ title: String,
        systemImage: String,
        style: ModernButtonStyleType,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
        }
        .modernStyle(style)
    }

    private func iconToolButton(_ systemImage: String, isActive: Bool, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 26, height: 26)
                .background(isActive ? Theme.Colors.accentSoft : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(isActive ? Theme.Colors.accent : Theme.Colors.textSecondary)
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
    }

    private func aspectFitRect(for imageSize: CGSize, in availableSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(origin: .zero, size: availableSize)
        }

        let scale = min(availableSize.width / imageSize.width, availableSize.height / imageSize.height)
        let fittedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(origin: .zero, size: fittedSize)
    }

    private let exportPadding: CGFloat = 8
    private let exportCornerRadius: CGFloat = 8

    private func generateFinalImage() -> NSImage? {
        guard let original = appState.capturedImage,
              let cgOriginal = original.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let pixelWidth = cgOriginal.width
        let pixelHeight = cgOriginal.height
        let scaleX = CGFloat(pixelWidth) / max(original.size.width, 1)
        let scaleY = CGFloat(pixelHeight) / max(original.size.height, 1)

        let shouldDecorateAreaCapture = appState.lastCaptureMode == .area
        let shouldOutlineWindowCapture = appState.lastCaptureMode == .window
        let finalSizePoints = CGSize(
            width: original.size.width + (shouldDecorateAreaCapture ? exportPadding * 2 : 0),
            height: original.size.height + (shouldDecorateAreaCapture ? exportPadding * 2 : 0)
        )

        let finalPixelWidth = Int(round(finalSizePoints.width * scaleX))
        let finalPixelHeight = Int(round(finalSizePoints.height * scaleY))

        guard let bitmapRepresentation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: finalPixelWidth,
            pixelsHigh: finalPixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ),
        let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmapRepresentation) else {
            return nil
        }

        let context = graphicsContext.cgContext
        context.interpolationQuality = .high
        context.clear(CGRect(x: 0, y: 0, width: CGFloat(finalPixelWidth), height: CGFloat(finalPixelHeight)))
        context.scaleBy(x: scaleX, y: scaleY)

        let imageOrigin = CGPoint(
            x: shouldDecorateAreaCapture ? exportPadding : 0,
            y: shouldDecorateAreaCapture ? exportPadding : 0
        )
        let imageRect = CGRect(origin: imageOrigin, size: original.size)

        if shouldDecorateAreaCapture {
            context.setFillColor(NSColor(Theme.Colors.panelElevated).cgColor)
            context.fill(CGRect(origin: .zero, size: finalSizePoints))
            let path = NSBezierPath(
                roundedRect: imageRect,
                xRadius: exportCornerRadius,
                yRadius: exportCornerRadius
            )
            context.saveGState()
            context.addPath(path.cgPath)
            context.clip()
            context.draw(cgOriginal, in: imageRect)
            context.restoreGState()
        } else {
            context.draw(cgOriginal, in: imageRect)
        }

        if shouldOutlineWindowCapture {
            context.setStrokeColor(NSColor(Theme.Colors.borderStrong).cgColor)
            context.setLineWidth(1)
            context.stroke(imageRect.insetBy(dx: 0.5, dy: 0.5))
        }

        renderAnnotations(
            into: context,
            originalSize: original.size,
            imageOrigin: imageOrigin
        )

        bitmapRepresentation.size = finalSizePoints

        let image = NSImage(size: finalSizePoints)
        image.addRepresentation(bitmapRepresentation)
        return image
    }

    private func renderAnnotations(
        into context: CGContext,
        originalSize: CGSize,
        imageOrigin: CGPoint
    ) {
        let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext

        for annotation in annotationState.annotations {
            let start = exportPoint(
                for: annotation.absoluteStart(canvasSize: originalSize),
                originalHeight: originalSize.height,
                imageOrigin: imageOrigin
            )
            let end = exportPoint(
                for: annotation.absoluteEnd(canvasSize: originalSize),
                originalHeight: originalSize.height,
                imageOrigin: imageOrigin
            )
            let color = NSColor(annotation.color)

            switch annotation.type {
            case .rectangle:
                let rect = CGRect(
                    x: min(start.x, end.x),
                    y: min(start.y, end.y),
                    width: abs(end.x - start.x),
                    height: abs(end.y - start.y)
                )
                let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
                color.setStroke()
                path.lineWidth = 3
                path.stroke()
            case .arrow:
                let path = NSBezierPath()
                path.move(to: start)
                path.line(to: end)

                let angle = atan2(end.y - start.y, end.x - start.x)
                let arrowLength: CGFloat = 16
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
                path.line(to: tip1)
                path.move(to: end)
                path.line(to: tip2)
                color.setStroke()
                path.lineWidth = 3
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                path.stroke()
            case .text:
                let attributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: color,
                    .font: NSFont.systemFont(ofSize: 18, weight: .medium)
                ]
                let textSize = NSString(string: annotation.text).size(withAttributes: attributes)
                let textRect = CGRect(
                    x: start.x,
                    y: start.y - textSize.height,
                    width: ceil(textSize.width) + 4,
                    height: ceil(textSize.height) + 2
                )
                NSString(string: annotation.text).draw(in: textRect, withAttributes: attributes)
            }
        }

        NSGraphicsContext.restoreGraphicsState()
    }

    private func exportPoint(for point: CGPoint, originalHeight: CGFloat, imageOrigin: CGPoint) -> CGPoint {
        CGPoint(
            x: imageOrigin.x + point.x,
            y: imageOrigin.y + (originalHeight - point.y)
        )
    }

    private func copyImage() {
        guard let image = generateFinalImage(),
              let data = pngData(for: image) else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(data, forType: .png)
        closeWindow()
    }

    @AppStorage("defaultSavePath") private var defaultSavePath: String = ""

    private func saveImage() {
        guard let image = generateFinalImage(),
              let data = pngData(for: image) else { return }

        let fileName = "Screenshot \(Date().formatted(date: .numeric, time: .shortened)).png"
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: ".")

        if let bookmarkData = UserDefaults.standard.data(forKey: "defaultSavePathBookmark") {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ),
            url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }

                let fileURL = uniqueDestinationURL(for: url.appendingPathComponent(fileName))
                if (try? data.write(to: fileURL, options: .atomic)) != nil {
                    closeWindow()
                    return
                }
            }
        }

        if !defaultSavePath.isEmpty {
            let baseURL = URL(fileURLWithPath: defaultSavePath, isDirectory: true)
            let fileURL = uniqueDestinationURL(for: baseURL.appendingPathComponent(fileName))
            if (try? data.write(to: fileURL, options: .atomic)) != nil {
                closeWindow()
                return
            }
        }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = fileName
        savePanel.directoryURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? data.write(to: url, options: .atomic)
            }
            closeWindow()
        }
    }

    private func closeWindow() {
        NotificationCenter.default.post(name: NSNotification.Name("CloseFloatingWindow"), object: nil)
    }

    private func uniqueDestinationURL(for url: URL) -> URL {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return url
        }

        let directory = url.deletingLastPathComponent()
        let fileName = url.deletingPathExtension().lastPathComponent
        let fileExtension = url.pathExtension

        for index in 2...999 {
            let candidate = directory.appendingPathComponent("\(fileName) \(index)").appendingPathExtension(fileExtension)
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        return url
    }

    private func pngData(for image: NSImage) -> Data? {
        if let bitmapRepresentation = image.representations.first as? NSBitmapImageRep {
            return bitmapRepresentation.representation(using: .png, properties: [.compressionFactor: 1.0])
        }

        guard let tiffData = image.tiffRepresentation,
              let bitmapRepresentation = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        return bitmapRepresentation.representation(using: .png, properties: [.compressionFactor: 1.0])
    }
}

private extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [NSPoint](repeating: .zero, count: 3)

        for index in 0..<elementCount {
            switch element(at: index, associatedPoints: &points) {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .curveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .cubicCurveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .quadraticCurveTo:
                path.addQuadCurve(to: points[1], control: points[0])
            case .closePath:
                path.closeSubpath()
            @unknown default:
                break
            }
        }

        return path
    }
}

private extension CGPoint {
    func offset(by offset: CGPoint) -> CGPoint {
        CGPoint(x: x + offset.x, y: y + offset.y)
    }
}
