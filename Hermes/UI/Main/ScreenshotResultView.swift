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
    
    private func generateFinalImage() -> NSImage? {
        guard let original = appState.capturedImage else { return nil }
        if annotationState.annotations.isEmpty { return original }
        
        let newImage = NSImage(size: original.size)
        newImage.lockFocus()
        original.draw(in: NSRect(origin: .zero, size: original.size))
        
        let _ = NSGraphicsContext.current?.cgContext
        
        // Draw Annotations using normalized coordinates
        for annotation in annotationState.annotations {
            let color = NSColor(annotation.color)
            color.setStroke()
            
            // Convert normalized coordinates to image pixels
            // Note: NSImage uses bottom-left origin, so we flip Y
            let startX = annotation.normalizedStart.x * original.size.width
            let startY = (1.0 - annotation.normalizedStart.y) * original.size.height
            let endX = annotation.normalizedEnd.x * original.size.width
            let endY = (1.0 - annotation.normalizedEnd.y) * original.size.height
            
            let startP = CGPoint(x: startX, y: startY)
            let endP = CGPoint(x: endX, y: endY)
            
            switch annotation.type {
            case .rectangle:
                let rect = CGRect(
                    x: min(startP.x, endP.x),
                    y: min(startP.y, endP.y),
                    width: abs(endP.x - startP.x),
                    height: abs(endP.y - startP.y)
                )
                let path = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
                path.lineWidth = 3.0
                color.setStroke()
                path.stroke()
                
            case .arrow:
                let path = NSBezierPath()
                path.move(to: startP)
                path.line(to: endP)
                
                let angle = atan2(endP.y - startP.y, endP.x - startP.x)
                let arrowLength: CGFloat = 20
                let arrowAngle: CGFloat = .pi / 6
                
                let p1 = CGPoint(x: endP.x - arrowLength * cos(angle - arrowAngle),
                                 y: endP.y - arrowLength * sin(angle - arrowAngle))
                let p2 = CGPoint(x: endP.x - arrowLength * cos(angle + arrowAngle),
                                 y: endP.y - arrowLength * sin(angle + arrowAngle))
                
                path.move(to: endP); path.line(to: p1)
                path.move(to: endP); path.line(to: p2)
                
                path.lineWidth = 3.0
                color.setStroke()
                path.stroke()
                
            case .text:
                let text = annotation.text as NSString
                let attrs: [NSAttributedString.Key: Any] = [
                    .foregroundColor: color,
                    .font: NSFont.systemFont(ofSize: 18, weight: .medium)
                ]
                text.draw(at: startP, withAttributes: attrs)
            }
        }
        
        newImage.unlockFocus()
        return newImage
    }
    
    private func copyImage() {
        if let image = generateFinalImage() {
             let pb = NSPasteboard.general
             pb.clearContents()
             pb.writeObjects([image])
             NotificationCenter.default.post(name: NSNotification.Name("CloseFloatingWindow"), object: nil)
        }
    }
    
    private func saveImage() {
        guard let image = generateFinalImage() else { return }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = "Screenshot \(Date().formatted(date: .numeric, time: .shortened)).png"
        savePanel.directoryURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                if let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let data = bitmap.representation(using: .png, properties: [:]) {
                    try? data.write(to: url)
                    NotificationCenter.default.post(name: NSNotification.Name("CloseFloatingWindow"), object: nil)
                }
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
        initialLocation = event.locationInWindow
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let window = self.window, let initialLocation = initialLocation else { return }
        
        let currentLocation = event.locationInWindow
        let delta = NSPoint(
            x: currentLocation.x - initialLocation.x,
            y: currentLocation.y - initialLocation.y
        )
        
        var origin = window.frame.origin
        origin.x += delta.x
        origin.y += delta.y
        window.setFrameOrigin(origin)
    }
    
    override func mouseUp(with event: NSEvent) {
        initialLocation = nil
    }
}
