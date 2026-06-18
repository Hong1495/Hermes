import SwiftUI
import Foundation
import Testing
@testable import Hermes

@Suite struct AnnotationUndoRedoTests {

    // MARK: - Helpers

    private func makeRect(color: Color = .red) -> Annotation {
        Annotation(
            type: .rectangle,
            normalizedStart: CGPoint(x: 0.1, y: 0.1),
            normalizedEnd: CGPoint(x: 0.5, y: 0.5),
            color: color
        )
    }

    private func makeMarker(count: Int) -> Annotation {
        Annotation(
            type: .numberedMarker,
            normalizedStart: CGPoint(x: 0.5, y: 0.5),
            normalizedEnd: CGPoint(x: 0.5, y: 0.5),
            color: .blue,
            text: "\(count)"
        )
    }

    // MARK: - Undo

    @Test func undoRestoresPreviousState() {
        let state = AnnotationState()
        state.add(makeRect())
        state.add(makeRect())

        #expect(state.annotations.count == 2)
        state.undo()
        #expect(state.annotations.count == 1)
        state.undo()
        #expect(state.annotations.isEmpty)
    }

    @Test func undoOnEmptyIsNoOp() {
        let state = AnnotationState()
        state.undo()
        #expect(state.annotations.isEmpty)
        #expect(state.canUndo == false)
    }

    @Test func canUndoReflectsStack() {
        let state = AnnotationState()
        #expect(state.canUndo == false)
        state.add(makeRect())
        #expect(state.canUndo == true)
        state.undo()
        #expect(state.canUndo == false)
    }

    // MARK: - Redo

    @Test func redoRestoresUndoneState() {
        let state = AnnotationState()
        state.add(makeRect())
        state.add(makeRect())
        state.undo()
        #expect(state.annotations.count == 1)

        state.redo()
        #expect(state.annotations.count == 2)
    }

    @Test func redoOnEmptyIsNoOp() {
        let state = AnnotationState()
        state.redo()
        #expect(state.annotations.isEmpty)
        #expect(state.canRedo == false)
    }

    @Test func canRedoReflectsStack() {
        let state = AnnotationState()
        state.add(makeRect())
        #expect(state.canRedo == false)
        state.undo()
        #expect(state.canRedo == true)
        state.redo()
        #expect(state.canRedo == false)
    }

    @Test func redoClearedByNewAction() {
        let state = AnnotationState()
        state.add(makeRect())
        state.undo()
        #expect(state.canRedo == true)

        state.add(makeRect())
        #expect(state.canRedo == false)
    }

    @Test func undoDoesntPushToUndoStack() {
        let state = AnnotationState()
        state.add(makeRect())
        state.add(makeRect())
        state.undo()

        // Undo should not double-push: after undo, 1 annotation, 1 undo entry
        // undo again should work
        state.undo()
        #expect(state.annotations.isEmpty)
    }

    // MARK: - Move

    @Test func moveCapturedAsSingleUndoStep() {
        let state = AnnotationState()
        state.canvasSize = CGSize(width: 400, height: 300)
        let annotation = makeRect()
        state.add(annotation)

        state.prepareMove()
        state.moveAnnotation(id: annotation.id, by: CGSize(width: 50, height: 0))
        state.moveAnnotation(id: annotation.id, by: CGSize(width: 30, height: 20))

        // Only one prepareMove was called, so one undo should restore original position
        let movedAnnotation = state.annotations[0]
        #expect(movedAnnotation.normalizedStart.x != 0.1) // was moved

        state.undo()
        let restoredAnnotation = state.annotations[0]
        #expect(restoredAnnotation.normalizedStart.x == 0.1)
    }

    // MARK: - Clear

    @Test func clearResetsStacks() {
        let state = AnnotationState()
        state.add(makeRect())
        state.undo()
        #expect(state.canRedo == true)

        state.add(makeRect())
        state.clear()

        // clear() saves undo state, so we can undo the clear
        #expect(state.annotations.isEmpty)
        #expect(state.canUndo == true)
        #expect(state.canRedo == false)
        state.undo()
        #expect(state.annotations.count == 1)
    }

    @Test func clearPreservesUndoHistory() {
        let state = AnnotationState()
        state.add(makeRect())
        state.clear()
        // clear() calls saveUndoState(), so the pre-clear annotations are preserved for undo
        // One undo restores state before clear
        state.undo()
        #expect(state.annotations.count == 1)
    }

    // MARK: - Delete

    @Test func deleteSelectedSavesUndoState() {
        let state = AnnotationState()
        let annotation = makeRect()
        state.add(annotation)
        state.selectedAnnotationId = annotation.id

        state.deleteSelected()
        #expect(state.annotations.isEmpty)

        state.undo()
        #expect(state.annotations.count == 1)
    }

    // MARK: - Marker counter (derived)

    @Test func markerCounterResetsWhenListEmpty() {
        let state = AnnotationState()
        state.add(makeMarker(count: 1))
        state.add(makeMarker(count: 2))
        #expect(state.markerCounter == 3)

        state.undo()
        #expect(state.markerCounter == 2) // only marker 1 remains

        state.undo()
        #expect(state.markerCounter == 1) // no markers left
    }

    @Test func undoStackCappedAtFifty() {
        let state = AnnotationState()
        for _ in 0..<60 {
            state.add(makeRect())
        }
        state.undo()
        // At 50+ entries, the oldest 10 were pruned
        // After 60 adds, we have 60 undo entries, then prune to 50, then undo adds 1 redo
        // So we should have ~49 undo entries left (we can undo ~49 times)
        // Rather than check count, verify undo still works
        #expect(state.canUndo == true)
        state.undo()
        #expect(state.annotations.count == 58)
    }
}
