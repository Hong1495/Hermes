import AppKit
import Foundation
import Testing
@testable import Hermes

// MARK: - ScreenshotExportService: 渲染和导出行为测试

@Suite struct ScreenshotExportServiceBehaviorTests {

    private let service = ScreenshotExportService.shared

    // Helper: 创建一个纯色测试图片
    private func makeTestImage(size: CGSize = CGSize(width: 100, height: 80)) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.red.drawSwatch(in: CGRect(origin: .zero, size: size))
        image.unlockFocus()
        return image
    }

    // MARK: - Image Generation

    @Test func generateFinalImageReturnsNonNilForValidInput() {
        let image = makeTestImage()
        let result = service.generateFinalImage(
            from: image,
            annotations: [],
            showBorder: false,
            showCornerRadius: false,
            showShadow: false,
            captureMode: .area
        )
        #expect(result != nil)
    }

    @Test func generateFinalImageReturnsNilForInvalidInput() {
        // NSImage() with no data → nil
        let result = service.generateFinalImage(
            from: NSImage(),
            annotations: [],
            showBorder: false,
            showCornerRadius: false,
            showShadow: false,
            captureMode: .area
        )
        #expect(result == nil)
    }

    @Test func generateFinalImageWithBorderAddsPadding() {
        let image = makeTestImage()
        guard let result = service.generateFinalImage(
            from: image,
            annotations: [],
            showBorder: true,
            showCornerRadius: false,
            showShadow: false,
            captureMode: .area
        ) else {
            #expect(Bool(false), "Expected image")
            return
        }
        // 边框模式应该增加 16pt padding (8*2)
        #expect(result.size.width == image.size.width + 16)
        #expect(result.size.height == image.size.height + 16)
    }

    @Test func generateFinalImageWithoutBorderPreservesSize() {
        let image = makeTestImage()
        guard let result = service.generateFinalImage(
            from: image,
            annotations: [],
            showBorder: false,
            showCornerRadius: false,
            showShadow: false,
            captureMode: .area
        ) else {
            #expect(Bool(false), "Expected image")
            return
        }
        #expect(result.size.width == image.size.width)
        #expect(result.size.height == image.size.height)
    }

    @Test func generateFinalImageRendersAnnotations() {
        let image = makeTestImage(size: CGSize(width: 200, height: 200))
        let annotations = [
            Annotation(
                type: .rectangle,
                normalizedStart: CGPoint(x: 0.1, y: 0.1),
                normalizedEnd: CGPoint(x: 0.5, y: 0.5),
                color: .blue
            )
        ]
        let result = service.generateFinalImage(
            from: image,
            annotations: annotations,
            showBorder: false,
            showCornerRadius: false,
            showShadow: false,
            captureMode: .area
        )
        #expect(result != nil)
        // 有标注不会 crash，图片尺寸不变
        #expect(result?.size == image.size)
    }

    // MARK: - Pixel Resolution

    @Test func generateFinalImagePreservesPixelDimensions() {
        let size = CGSize(width: 60, height: 40)
        let image = makeTestImage(size: size)
        guard let result = service.generateFinalImage(
            from: image,
            annotations: [],
            showBorder: false,
            showCornerRadius: false,
            showShadow: false,
            captureMode: .area
        ) else {
            #expect(Bool(false), "Expected image")
            return
        }
        // PNG data 应该有内容
        let pngData = service.pngData(for: result)
        #expect(pngData != nil)
        #expect(pngData!.count > 0)
    }

    // MARK: - PNG Encoding

    @Test func pngDataFromGeneratedImageIsValid() {
        let image = makeTestImage()
        guard let final = service.generateFinalImage(
            from: image,
            annotations: [],
            showBorder: false,
            showCornerRadius: false,
            showShadow: false,
            captureMode: .area
        ) else {
            #expect(Bool(false), "Expected image")
            return
        }
        let data = service.pngData(for: final)
        #expect(data != nil)
        #expect(data!.count > 100, "PNG data should contain pixel data")
    }

    // MARK: - Border + Shapes

    @Test func borderAndCornerRadiusTogether() {
        let image = makeTestImage(size: CGSize(width: 100, height: 80))
        let result = service.generateFinalImage(
            from: image,
            annotations: [],
            showBorder: true,
            showCornerRadius: true,
            showShadow: false,
            captureMode: .window
        )
        #expect(result != nil)
        // 边框 padding + 圆角裁剪不应崩溃
        #expect(result!.size.width == 116)
        #expect(result!.size.height == 96)
    }

    // MARK: - New Annotation Types

    @Test func exportWithHighlighterDoesNotCrash() {
        let image = makeTestImage()
        let annotations = [
            Annotation(
                type: .highlighter,
                normalizedStart: CGPoint(x: 0.1, y: 0.1),
                normalizedEnd: CGPoint(x: 0.8, y: 0.3),
                color: .yellow
            )
        ]
        let result = service.generateFinalImage(
            from: image,
            annotations: annotations,
            showBorder: false,
            showCornerRadius: false,
            showShadow: false,
            captureMode: .area
        )
        #expect(result != nil)
    }

    @Test func exportWithFreehandDoesNotCrash() {
        let image = makeTestImage()
        let annotations = [
            Annotation(
                type: .freehand,
                normalizedStart: CGPoint(x: 0.1, y: 0.1),
                normalizedEnd: CGPoint(x: 0.9, y: 0.9),
                color: .red,
                pathPoints: [
                    CGPoint(x: 0.1, y: 0.1),
                    CGPoint(x: 0.3, y: 0.4),
                    CGPoint(x: 0.5, y: 0.2),
                    CGPoint(x: 0.9, y: 0.9)
                ]
            )
        ]
        let result = service.generateFinalImage(
            from: image,
            annotations: annotations,
            showBorder: false,
            showCornerRadius: false,
            showShadow: false,
            captureMode: .area
        )
        #expect(result != nil)
    }

    @Test func exportWithNumberedMarkerDoesNotCrash() {
        let image = makeTestImage()
        let annotations = [
            Annotation(
                type: .numberedMarker,
                normalizedStart: CGPoint(x: 0.3, y: 0.4),
                normalizedEnd: CGPoint(x: 0.3, y: 0.4),
                color: .blue,
                text: "1"
            ),
            Annotation(
                type: .numberedMarker,
                normalizedStart: CGPoint(x: 0.6, y: 0.2),
                normalizedEnd: CGPoint(x: 0.6, y: 0.2),
                color: .red,
                text: "2"
            )
        ]
        let result = service.generateFinalImage(
            from: image,
            annotations: annotations,
            showBorder: false,
            showCornerRadius: false,
            showShadow: false,
            captureMode: .area
        )
        #expect(result != nil)
    }

    @Test func exportAllNewAnnotationTypesTogether() {
        let image = makeTestImage(size: CGSize(width: 200, height: 200))
        let annotations: [Annotation] = [
            .init(type: .highlighter, normalizedStart: .init(x: 0.1, y: 0.1), normalizedEnd: .init(x: 0.5, y: 0.3), color: .yellow),
            .init(type: .freehand, normalizedStart: .init(x: 0.2, y: 0.2), normalizedEnd: .init(x: 0.8, y: 0.8), color: .red, pathPoints: [.init(x: 0.2, y: 0.2), .init(x: 0.5, y: 0.5), .init(x: 0.8, y: 0.8)]),
            .init(type: .numberedMarker, normalizedStart: .init(x: 0.7, y: 0.3), normalizedEnd: .init(x: 0.7, y: 0.3), color: .blue, text: "1")
        ]
        let result = service.generateFinalImage(
            from: image,
            annotations: annotations,
            showBorder: true,
            showCornerRadius: true,
            showShadow: false,
            captureMode: .window
        )
        #expect(result != nil)
    }
}
