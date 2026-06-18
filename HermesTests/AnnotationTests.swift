import SwiftUI
import Foundation
import Testing
@testable import Hermes

@Suite struct AnnotationTests {
    @Test func absoluteStartConversion() {
        let annotation = Annotation(
            type: .rectangle,
            normalizedStart: CGPoint(x: 0.5, y: 0.5),
            normalizedEnd: CGPoint(x: 0.75, y: 0.75),
            color: .red
        )
        let canvasSize = CGSize(width: 400, height: 300)

        let start = annotation.absoluteStart(canvasSize: canvasSize)
        #expect(start.x == 200.0)
        #expect(start.y == 150.0)
    }

    @Test func absoluteEndConversion() {
        let annotation = Annotation(
            type: .rectangle,
            normalizedStart: CGPoint(x: 0.5, y: 0.5),
            normalizedEnd: CGPoint(x: 0.75, y: 0.75),
            color: .red
        )
        let canvasSize = CGSize(width: 400, height: 300)

        let end = annotation.absoluteEnd(canvasSize: canvasSize)
        #expect(end.x == 300.0)
        #expect(end.y == 225.0)
    }

    // MARK: - Model extensions

    @Test func markerCounterDerivesFromAnnotations() {
        let state = AnnotationState()
        #expect(state.markerCounter == 1)

        state.add(Annotation(
            type: .numberedMarker,
            normalizedStart: .init(x: 0.5, y: 0.5),
            normalizedEnd: .init(x: 0.5, y: 0.5),
            color: .red,
            text: "1"
        ))
        #expect(state.markerCounter == 2)

        state.add(Annotation(
            type: .numberedMarker,
            normalizedStart: .init(x: 0.5, y: 0.5),
            normalizedEnd: .init(x: 0.5, y: 0.5),
            color: .blue,
            text: "5"
        ))
        #expect(state.markerCounter == 6)
    }

    @Test func markerCounterResetsOnClear() {
        let state = AnnotationState()
        state.add(Annotation(
            type: .numberedMarker,
            normalizedStart: .init(x: 0.5, y: 0.5),
            normalizedEnd: .init(x: 0.5, y: 0.5),
            color: .red,
            text: "3"
        ))
        state.clear()
        #expect(state.markerCounter == 1)
    }

    @Test func freehandPathNormalization() {
        let canvasSize = CGSize(width: 400, height: 300)
        let pixelPoints = [
            CGPoint(x: 100, y: 50),
            CGPoint(x: 200, y: 150),
            CGPoint(x: 300, y: 250)
        ]
        let normalizedPoints = pixelPoints.map { $0.normalized(in: canvasSize) }

        let annotation = Annotation(
            type: .freehand,
            normalizedStart: normalizedPoints.first ?? .zero,
            normalizedEnd: normalizedPoints.last ?? .zero,
            color: .red,
            pathPoints: normalizedPoints
        )

        // Round-trip test
        for (original, normalized) in zip(pixelPoints, annotation.pathPoints) {
            #expect(abs(normalized.x * canvasSize.width - original.x) < 0.01)
            #expect(abs(normalized.y * canvasSize.height - original.y) < 0.01)
        }
    }

    @Test func highlighterAnnotationModel() {
        let annotation = Annotation(
            type: .highlighter,
            normalizedStart: CGPoint(x: 0.1, y: 0.2),
            normalizedEnd: CGPoint(x: 0.8, y: 0.6),
            color: .yellow
        )
        #expect(annotation.type == .highlighter)
        #expect(annotation.absoluteStart(canvasSize: CGSize(width: 100, height: 100)) == CGPoint(x: 10, y: 20))
        #expect(annotation.absoluteEnd(canvasSize: CGSize(width: 100, height: 100)) == CGPoint(x: 80, y: 60))
    }

    @Test func numberedMarkerModel() {
        let annotation = Annotation(
            type: .numberedMarker,
            normalizedStart: CGPoint(x: 0.5, y: 0.5),
            normalizedEnd: CGPoint(x: 0.5, y: 0.5),
            color: .blue,
            text: "3"
        )
        #expect(annotation.type == .numberedMarker)
        #expect(annotation.text == "3")
    }

    @Test func moveAnnotationClampedToBounds() {
        let state = AnnotationState()
        state.canvasSize = CGSize(width: 400, height: 300)
        let annotation = Annotation(
            type: .rectangle,
            normalizedStart: CGPoint(x: 0.5, y: 0.5),
            normalizedEnd: CGPoint(x: 0.6, y: 0.6),
            color: .red
        )
        state.annotations = [annotation]

        // Try moving way past the right edge
        state.moveAnnotation(id: annotation.id, by: CGSize(width: 300, height: 0))

        guard let moved = state.annotations.first else {
            #expect(Bool(false), "Annotation should still exist")
            return
        }

        // maxX should be clamped to 1.0
        #expect(moved.normalizedEnd.x <= 1.0)
        #expect(moved.normalizedStart.x <= 1.0)
    }

    @Test func moveAnnotationZeroCanvasReturnsEarly() {
        let state = AnnotationState()
        state.canvasSize = .zero
        let annotation = Annotation(
            type: .rectangle,
            normalizedStart: .zero,
            normalizedEnd: .zero,
            color: .red
        )
        state.annotations = [annotation]

        state.moveAnnotation(id: annotation.id, by: CGSize(width: 100, height: 100))

        // Should be unchanged since canvasSize is zero
        guard let unmoved = state.annotations.first else {
            #expect(Bool(false), "Annotation should still exist")
            return
        }
        #expect(unmoved.normalizedStart.x == 0)
        #expect(unmoved.normalizedStart.y == 0)
    }
}
