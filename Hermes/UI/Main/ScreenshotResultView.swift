import SwiftUI
import UniformTypeIdentifiers

struct ScreenshotResultView: View {
    @ObservedObject var appState = AppState.shared
    @StateObject var annotationState = AnnotationState()

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar (Top)
            HStack(spacing: 12) {
                // Tools
                Group {
                    Button(action: { annotationState.currentTool = nil }) {
                        Image(systemName: "cursorarrow")
                            .frame(width: 32, height: 28)
                            .background(annotationState.currentTool == nil ? Color(hex: "E60012").opacity(0.15) : Color.clear)
                            .foregroundStyle(annotationState.currentTool == nil ? Color(hex: "E60012") : .primary)
                            .cornerRadius(6)
                    }
                    .help("选择")

                    Button(action: { annotationState.currentTool = .rectangle }) {
                        Image(systemName: "square")
                            .frame(width: 32, height: 28)
                            .background(annotationState.currentTool == .rectangle ? Color(hex: "E60012").opacity(0.15) : Color.clear)
                            .foregroundStyle(annotationState.currentTool == .rectangle ? Color(hex: "E60012") : .primary)
                            .cornerRadius(6)
                    }
                    .help("矩形框")

                    Button(action: { annotationState.currentTool = .arrow }) {
                        Image(systemName: "arrow.up.right")
                            .frame(width: 32, height: 28)
                            .background(annotationState.currentTool == .arrow ? Color(hex: "E60012").opacity(0.15) : Color.clear)
                            .foregroundStyle(annotationState.currentTool == .arrow ? Color(hex: "E60012") : .primary)
                            .cornerRadius(6)
                    }
                    .help("箭头")

                    Button(action: { annotationState.currentTool = .text }) {
                        Image(systemName: "textformat")
                            .frame(width: 32, height: 28)
                            .background(annotationState.currentTool == .text ? Color(hex: "E60012").opacity(0.15) : Color.clear)
                            .foregroundStyle(annotationState.currentTool == .text ? Color(hex: "E60012") : .primary)
                            .cornerRadius(6)
                    }
                    .help("文字")

                    // Divider
                    Rectangle().frame(width: 1, height: 16).foregroundStyle(.secondary.opacity(0.3))

                    // Undo before color picker
                    Button(action: { annotationState.undo() }) {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(annotationState.annotations.isEmpty)
                    .help("撤销")

                    // Divider
                    Rectangle().frame(width: 1, height: 16).foregroundStyle(.secondary.opacity(0.3))

                    // Japanese Color Picker
                    JapaneseColorPicker(selectedColor: $annotationState.selectedJapaneseColor)
                }
                .buttonStyle(.plain)
                .font(.system(size: 16))

                Spacer()

                // Copy icon
                Button(action: { copyImage() }) {
                    Image(systemName: "square.on.square")
                }
                .buttonStyle(.plain)
                .font(.system(size: 16))
                .help("拷贝")
                .keyboardShortcut("c", modifiers: .command)

                // Save
                Button(action: { saveImage() }) {
                    Image(systemName: "arrow.down.circle")
                }
                .buttonStyle(.plain)
                .font(.system(size: 16))
                .help("保存")
                .keyboardShortcut("s", modifiers: .command)

                // Close at far right
                Button(action: { NotificationCenter.default.post(name: NSNotification.Name("CloseFloatingWindow"), object: nil) }) {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(Color(hex: "E60012")) // 赤 (Aka)
                }
                .buttonStyle(.plain)
                .font(.system(size: 16))
                .help("关闭")
            }
            .padding(Theme.Spacing.medium)
            .background(
                // Draggable area for window
                WindowDragView()
            )
            // No background - clean toolbar on window blur

            // Image Area with Annotation Canvas
            ZStack {
                    if let image = appState.capturedImage {
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .overlay(
                                GeometryReader { overlayGeo in
                                    AnnotationCanvas(state: annotationState)
                                        .clipped() // Clip annotations to image bounds
                                        .onAppear {
                                            annotationState.canvasSize = overlayGeo.size
                                            annotationState.clear() // Clear on new image
                                        }
                                        .onChange(of: overlayGeo.size) { _, newSize in
                                            annotationState.canvasSize = newSize
                                        }
                                }
                            )
                            .onChange(of: appState.capturedImage) { _, _ in
                                annotationState.clear() // Clear annotations when new screenshot
                            }
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.clear)
            .contentShape(Rectangle())
            .onTapGesture {
                // Clicking anywhere else commits text
                annotationState.requestCommitText = true
            }
        }
    }

    private let areaPadding: CGFloat = 40
    private let cornerRadius: CGFloat = 16
    private let borderWidth: CGFloat = 1.0

    private func generateFinalImage() -> NSImage? {
        guard let original = appState.capturedImage else { return nil }

        let isArea = appState.lastCaptureMode == .area || appState.lastCaptureMode == .screen
        let isWindow = appState.lastCaptureMode == .window

        // Use CGImage for pixel-perfect control
        guard let cgOriginal = original.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return original
        }

        let pixelWidthOrig = cgOriginal.width
        let pixelHeightOrig = cgOriginal.height

        let scaleX = CGFloat(pixelWidthOrig) / original.size.width
        let scaleY = CGFloat(pixelHeightOrig) / original.size.height

        // Calculate final pixel dimensions including padding
        var pixelWidth = pixelWidthOrig
        var pixelHeight = pixelHeightOrig
        var horizontalPaddingPixels: CGFloat = 0
        var verticalPaddingPixels: CGFloat = 0

        if isArea {
            horizontalPaddingPixels = areaPadding * scaleX
            verticalPaddingPixels = areaPadding * scaleY
            pixelWidth += Int(horizontalPaddingPixels * 2)
            pixelHeight += Int(verticalPaddingPixels * 2)
        }

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? cgOriginal.colorSpace ?? CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return original }

        context.interpolationQuality = .high

        // 1. Draw Background/Original Image/Border
        let outerRect = CGRect(x: 0, y: 0, width: CGFloat(pixelWidth), height: CGFloat(pixelHeight))

        if isArea {
            let innerRect = outerRect.insetBy(dx: horizontalPaddingPixels, dy: verticalPaddingPixels)

            context.saveGState()
            let path = CGPath(roundedRect: innerRect, cornerWidth: cornerRadius * scaleX, cornerHeight: cornerRadius * scaleY, transform: nil)
            context.addPath(path)
            context.clip()

            context.draw(cgOriginal, in: innerRect)
            context.restoreGState()
        } else if isWindow {
            context.draw(cgOriginal, in: outerRect)

            context.setStrokeColor(NSColor.separatorColor.cgColor)
            context.setLineWidth(borderWidth * scaleX)
            context.stroke(outerRect.insetBy(dx: (borderWidth * scaleX) / 2, dy: (borderWidth * scaleY) / 2))
        } else {
            context.draw(cgOriginal, in: outerRect)
        }

        // 2. Setup for Annotation Drawing
        NSGraphicsContext.saveGraphicsState()
        let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.current = nsContext

        context.scaleBy(x: scaleX, y: scaleY)
        if isArea {
            context.translateBy(x: areaPadding, y: areaPadding)
        }

        for annotation in annotationState.annotations {
            let color = NSColor(annotation.color)
            color.setStroke()

            let startX = annotation.normalizedStart.x * original.size.width
            let startY = (1.0 - annotation.normalizedStart.y) * original.size.height
            let endX = annotation.normalizedEnd.x * original.size.width
            let endY = (1.0 - annotation.normalizedEnd.y) * original.size.height

            let startP = CGPoint(x: startX, y: startY)
            let endP = CGPoint(x: endX, y: endY)

            switch annotation.type {
            case .rectangle:
                let rect = CGRect(x: min(startP.x, endP.x), y: min(startP.y, endP.y), width: abs(endP.x - startP.x), height: abs(endP.y - startP.y))
                let path = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
                path.lineWidth = 3.0
                path.stroke()

            case .arrow:
                let path = NSBezierPath()
                path.move(to: startP); path.line(to: endP)
                let angle = atan2(endP.y - startP.y, endP.x - startP.x); let arrowLength: CGFloat = 20; let arrowAngle: CGFloat = .pi / 6
                let p1 = CGPoint(x: endP.x - arrowLength * cos(angle - arrowAngle), y: endP.y - arrowLength * sin(angle - arrowAngle))
                let p2 = CGPoint(x: endP.x - arrowLength * cos(angle + arrowAngle), y: endP.y - arrowLength * sin(angle + arrowAngle))
                path.move(to: endP); path.line(to: p1)
                path.move(to: endP); path.line(to: p2)
                path.lineWidth = 3.0; path.stroke()

            case .text:
                let text = annotation.text as NSString
                let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: color, .font: NSFont.systemFont(ofSize: 18, weight: .medium)]
                text.draw(at: startP, withAttributes: attrs)
            }
        }

        NSGraphicsContext.restoreGraphicsState()

        guard let finalCG = context.makeImage() else { return original }
        let finalSizePoints = isArea ? CGSize(width: original.size.width + areaPadding * 2, height: original.size.height + areaPadding * 2) : original.size
        let finalImage = NSImage(cgImage: finalCG, size: finalSizePoints)
        let rep = NSBitmapImageRep(cgImage: finalCG)
        rep.size = finalSizePoints
        finalImage.addRepresentation(rep)
        return finalImage
    }

    private func copyImage() {
        if let image = generateFinalImage() {
             let pb = NSPasteboard.general
             pb.clearContents()

             // If it's the original image (no annotations), we can just write it.
             // Otherwise, try to preserve the bitmap representation for better quality in pasteboard.
             pb.writeObjects([image])

             NotificationCenter.default.post(name: NSNotification.Name("CloseFloatingWindow"), object: nil)
        }
    }

    /// High quality PNG representation that preserves scale and DPI
    private func pngData(for image: NSImage) -> Data? {
        let rep: NSBitmapImageRep?

        if let firstRep = image.representations.first as? NSBitmapImageRep {
            rep = firstRep
        } else if let tiffData = image.tiffRepresentation {
            rep = NSBitmapImageRep(data: tiffData)
        } else {
            rep = nil
        }

        guard let bitmapRep = rep else { return nil }

        // Ensure DPI metadata is present (important for Retina screenshots)
        if bitmapRep.pixelsWide > 0 && bitmapRep.size.width > 0 {
            let detectedDpi = (CGFloat(bitmapRep.pixelsWide) / bitmapRep.size.width) * 72.0
            let properties: [NSBitmapImageRep.PropertyKey: Any] = [
                .interlaced: false,
                .compressionFactor: 1.0
            ]
            // Note: PNG resolution is often stored in pHYs chunk,
            // NSBitmapImageRep usually handles this via size/pixel mapping.
            return bitmapRep.representation(using: .png, properties: properties)
        }

        return bitmapRep.representation(using: .png, properties: [:])
    }

    @AppStorage("defaultSavePath") var defaultSavePath: String = ""

    private func saveImage() {
        guard let image = generateFinalImage() else { return }
        let fileName = "Screenshot \(Date().formatted(date: .numeric, time: .shortened)).png"
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: ".")

        let imageData = pngData(for: image)
        guard let data = imageData else { return }

        // Try to use Security Scoped Bookmark first (for persistence)
        if let bookmarkData = UserDefaults.standard.data(forKey: "defaultSavePathBookmark") {
            var isStale = false
            do {
                let url = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )

                if isStale {
                    // Bookmark is stale, might need recreation (usually requires user interaction or new access)
                    print("Bookmark is stale")
                }

                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }

                    let fileURL = url.appendingPathComponent(fileName)
                    try data.write(to: fileURL)
                    NotificationCenter.default.post(name: NSNotification.Name("CloseFloatingWindow"), object: nil)
                    return
                }
            } catch {
                print("Failed to resolve bookmark: \(error)")
                // Fallback to path check or panel
            }
        }

        // Use default path string if set (Legacy/Fallback)
        if !defaultSavePath.isEmpty {
            let baseURL = URL(fileURLWithPath: defaultSavePath, isDirectory: true)
            let fileURL = baseURL.appendingPathComponent(fileName)
            do {
                try data.write(to: fileURL)
                NotificationCenter.default.post(name: NSNotification.Name("CloseFloatingWindow"), object: nil)
                return
            } catch {
                print("Failed to save to default path: \(error)")
                // Fallback to save panel on error
            }
        }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = fileName
        savePanel.directoryURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? data.write(to: url)
                NotificationCenter.default.post(name: NSNotification.Name("CloseFloatingWindow"), object: nil)
            }
        }
    }
}

// MARK: - Window Drag Helper
struct WindowDragView: NSViewRepresentable {
    func makeNSView(context: Context) -> DraggableNSView {
        return DraggableNSView()
    }

    func updateNSView(_ nsView: DraggableNSView, context: Context) {
        // View updates itself
    }
}

class DraggableNSView: NSView {
    private var initialLocation: NSPoint?

    override func mouseDown(with event: NSEvent) {
        // 使用系统原生拖动，彻底消除手动计算导致的抖动
        window?.performDrag(with: event)
    }

    // mouseDragged 和 mouseUp 不再需要，由系统接管
}
