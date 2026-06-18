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
