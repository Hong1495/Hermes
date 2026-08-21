import AppKit
import SwiftUI
import UniformTypeIdentifiers
import OSLog

/// 截图导出服务：图片合成、PNG 编码、文件保存、剪贴板复制。
final class ScreenshotExportService {

    static let shared = ScreenshotExportService()

    private let logger = Logger(subsystem: "hera.Hermes", category: "Export")
    private let exportQueue = DispatchQueue(
        label: "hera.Hermes.screenshot-export",
        qos: .userInitiated
    )

    enum CopyResult: Equatable {
        case success
        case encodeFailed
        case writeFailed
    }

    enum SaveResult: Equatable {
        case success
        case encodeFailed
        case writeFailed
        case userCancelled
    }

    private init() {}

    private let exportPadding: CGFloat = 8
    private let exportCornerRadius: CGFloat = 8
    private let shadowMargin: CGFloat = 8

    // MARK: - Image Generation

    func generateFinalImageAsync(
        from original: NSImage,
        annotations: [Annotation],
        showBorder: Bool,
        showCornerRadius: Bool,
        showShadow: Bool,
        captureMode: ScreenshotService.CaptureMode,
        completion: @escaping (NSImage?) -> Void
    ) {
        exportQueue.async { [self] in
            let image = autoreleasepool {
                generateFinalImage(
                    from: original,
                    annotations: annotations,
                    showBorder: showBorder,
                    showCornerRadius: showCornerRadius,
                    showShadow: showShadow,
                    captureMode: captureMode
                )
            }
            completeOnMain(completion, with: image)
        }
    }

    func generateFinalImage(
        from original: NSImage,
        annotations: [Annotation],
        showBorder: Bool,
        showCornerRadius: Bool,
        showShadow: Bool,
        captureMode: ScreenshotService.CaptureMode
    ) -> NSImage? {
        guard let cgOriginal = original.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let pixelWidth = cgOriginal.width
        let pixelHeight = cgOriginal.height
        let scaleX = CGFloat(pixelWidth) / max(original.size.width, 1)
        let scaleY = CGFloat(pixelHeight) / max(original.size.height, 1)

        let shouldOutlineWindowCapture = captureMode == .window
        let shadowPad: CGFloat = showShadow ? shadowMargin : 0
        let borderPad: CGFloat = showBorder ? exportPadding : 0
        let totalPad = borderPad + shadowPad

        let finalSizePoints = CGSize(
            width: original.size.width + totalPad * 2,
            height: original.size.height + totalPad * 2
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
            x: totalPad,
            y: totalPad
        )
        let imageRect = CGRect(origin: imageOrigin, size: original.size)

        if showBorder {
            context.setFillColor(NSColor(Theme.Colors.panelElevated).cgColor)
            let borderRect = CGRect(
                x: shadowPad,
                y: shadowPad,
                width: original.size.width + borderPad * 2,
                height: original.size.height + borderPad * 2
            )
            context.fill(borderRect)
        }

        if showShadow {
            context.setShadow(
                offset: CGSize(width: 0, height: -2),
                blur: 8,
                color: NSColor.black.withAlphaComponent(0.15).cgColor
            )
        }

        if showCornerRadius {
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

        renderAnnotations(annotations, into: context, originalSize: original.size, imageOrigin: imageOrigin)

        bitmapRepresentation.size = finalSizePoints

        let image = NSImage(size: finalSizePoints)
        image.addRepresentation(bitmapRepresentation)
        return image
    }

    // MARK: - Annotation Rendering

    private func renderAnnotations(
        _ annotations: [Annotation],
        into context: CGContext,
        originalSize: CGSize,
        imageOrigin: CGPoint
    ) {
        let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext

        // Pass 1: dim overlay with highlighter holes
        let highlighters = annotations.filter { $0.type == .highlighter }
        if !highlighters.isEmpty {
            let overlayPath = CGMutablePath()
            overlayPath.addRect(CGRect(origin: imageOrigin, size: originalSize))

            context.setFillColor(NSColor.black.withAlphaComponent(0.35).cgColor)
            for ann in highlighters {
                let hStart = exportPoint(
                    for: ann.absoluteStart(canvasSize: originalSize),
                    originalHeight: originalSize.height,
                    imageOrigin: imageOrigin
                )
                let hEnd = exportPoint(
                    for: ann.absoluteEnd(canvasSize: originalSize),
                    originalHeight: originalSize.height,
                    imageOrigin: imageOrigin
                )
                let rect = CGRect(
                    x: min(hStart.x, hEnd.x),
                    y: min(hStart.y, hEnd.y),
                    width: abs(hEnd.x - hStart.x),
                    height: abs(hEnd.y - hStart.y)
                )
                let path = NSBezierPath(roundedRect: rect, xRadius: Annotation.RenderStyle.cornerRadius, yRadius: Annotation.RenderStyle.cornerRadius)
                overlayPath.addPath(path.cgPath)
            }
            context.addPath(overlayPath)
            context.drawPath(using: .eoFill)
        }

        // Pass 2: render non-highlighter annotations
        for annotation in annotations where annotation.type != .highlighter {
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
                let path = NSBezierPath(roundedRect: rect, xRadius: Annotation.RenderStyle.cornerRadius, yRadius: Annotation.RenderStyle.cornerRadius)
                color.setStroke()
                path.lineWidth = Annotation.RenderStyle.lineWidth
                path.stroke()
            case .highlighter:
                // Rendered via dim overlay + clear blend hole above
                break
            case .arrow:
                let path = NSBezierPath()
                path.move(to: start)
                path.line(to: end)

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
                path.line(to: tip1)
                path.move(to: end)
                path.line(to: tip2)
                color.setStroke()
                path.lineWidth = Annotation.RenderStyle.lineWidth
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                path.stroke()
            case .freehand:
                guard annotation.pathPoints.count >= 2 else { break }
                let freePath = NSBezierPath()
                let absPoints = annotation.pathPoints.map { pt in
                    exportPoint(for: CGPoint(x: pt.x * originalSize.width, y: pt.y * originalSize.height), originalHeight: originalSize.height, imageOrigin: imageOrigin)
                }
                freePath.move(to: absPoints[0])
                for pt in absPoints.dropFirst() {
                    freePath.line(to: pt)
                }
                color.setStroke()
                freePath.lineWidth = Annotation.RenderStyle.lineWidth
                freePath.lineCapStyle = .round
                freePath.lineJoinStyle = .round
                freePath.stroke()
            case .numberedMarker:
                let radius = Annotation.RenderStyle.markerRadius
                let circleRect = CGRect(x: start.x - radius, y: start.y - radius, width: radius * 2, height: radius * 2)
                color.setFill()
                NSBezierPath(ovalIn: circleRect).fill()
                let numberAttributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: NSColor.white,
                    .font: NSFont.systemFont(ofSize: 14, weight: .bold)
                ]
                let number = NSString(string: annotation.text)
                let numSize = number.size(withAttributes: numberAttributes)
                let numRect = CGRect(
                    x: start.x - numSize.width / 2,
                    y: start.y - numSize.height / 2,
                    width: numSize.width,
                    height: numSize.height
                )
                number.draw(in: numRect, withAttributes: numberAttributes)
            case .text:
                let attributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: color,
                    .font: NSFont.systemFont(ofSize: Annotation.RenderStyle.textFontSize, weight: .medium)
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

    // MARK: - PNG Encoding

    func pngData(for image: NSImage) -> Data? {
        if let bitmapRepresentation = image.representations.first as? NSBitmapImageRep {
            return bitmapRepresentation.representation(using: .png, properties: [.compressionFactor: 1.0])
        }

        guard let tiffData = image.tiffRepresentation,
              let bitmapRepresentation = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        return bitmapRepresentation.representation(using: .png, properties: [.compressionFactor: 1.0])
    }

    // MARK: - Clipboard

    func copyToClipboard(
        _ image: NSImage,
        pasteboard: NSPasteboard = .general,
        completion: @escaping (CopyResult) -> Void
    ) {
        exportQueue.async { [self] in
            guard let data = autoreleasepool(invoking: { pngData(for: image) }) else {
                logger.error("复制失败: PNG编码失败")
                completeOnMain(completion, with: .encodeFailed)
                return
            }

            DispatchQueue.main.async {
                let item = NSPasteboardItem()
                item.setData(data, forType: .png)

                pasteboard.clearContents()
                if pasteboard.writeObjects([item]) {
                    completion(.success)
                } else {
                    self.logger.error("复制失败: 剪贴板写入失败")
                    completion(.writeFailed)
                }
            }
        }
    }

    // MARK: - File Save

    func saveImage(_ image: NSImage, fileName: String, completion: @escaping (SaveResult) -> Void) {
        exportQueue.async { [self] in
            guard let data = autoreleasepool(invoking: { pngData(for: image) }) else {
                logger.error("保存失败: PNG编码失败")
                completeOnMain(completion, with: .encodeFailed)
                return
            }

            saveEncodedImage(data, fileName: fileName, completion: completion)
        }
    }

    private func saveEncodedImage(
        _ data: Data,
        fileName: String,
        completion: @escaping (SaveResult) -> Void
    ) {
        // 1. Try security-scoped bookmark
        if let bookmarkData = UserDefaults.standard.data(forKey: AppSettings.Key.defaultSavePathBookmark) {
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
                    logger.notice("保存成功: \(fileURL.lastPathComponent, privacy: .public)")
                    completeOnMain(completion, with: .success)
                    return
                }
                logger.warning("写入 bookmark 目录失败, 尝试 fallback")
            }
        }

        // 2. Try defaultSavePath string
        let defaultSavePath = UserDefaults.standard.string(forKey: AppSettings.Key.defaultSavePath) ?? ""
        if !defaultSavePath.isEmpty {
            let baseURL = URL(fileURLWithPath: defaultSavePath, isDirectory: true)
            let fileURL = uniqueDestinationURL(for: baseURL.appendingPathComponent(fileName))
            if (try? data.write(to: fileURL, options: .atomic)) != nil {
                logger.notice("保存成功: \(fileURL.lastPathComponent, privacy: .public)")
                completeOnMain(completion, with: .success)
                return
            }
            logger.warning("写入 defaultSavePath 失败: \(defaultSavePath, privacy: .public)")
        }

        // 3. NSSavePanel fallback
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            logger.notice("弹出 NSSavePanel 用户选择保存路径")
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [.png]
            savePanel.canCreateDirectories = true
            savePanel.nameFieldStringValue = fileName
            savePanel.directoryURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first

            savePanel.begin { [weak self] response in
                guard let self else { return }

                if response == .OK, let url = savePanel.url {
                    exportQueue.async {
                        do {
                            try data.write(to: url, options: .atomic)
                            self.logger.notice("用户选择保存: \(url.lastPathComponent, privacy: .public)")
                            self.completeOnMain(completion, with: .success)
                        } catch {
                            self.logger.error("NSSavePanel 写入失败: \(error.localizedDescription, privacy: .public)")
                            self.completeOnMain(completion, with: .writeFailed)
                        }
                    }
                } else {
                    logger.notice("用户取消保存")
                    completion(.userCancelled)
                }
            }
        }
    }

    private func completeOnMain<T>(_ completion: @escaping (T) -> Void, with result: T) {
        DispatchQueue.main.async {
            completion(result)
        }
    }

    func uniqueDestinationURL(for url: URL) -> URL {
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
}

// MARK: - NSBezierPath cgPath Extension

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
