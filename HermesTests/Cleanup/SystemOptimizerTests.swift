import Foundation
import Testing
@testable import Hermes

@Suite struct SystemOptimizerTests {
    @Test func optimizationTasksAreDefinedAndStructured() {
        let tasks = OptimizationTaskType.allCases
        #expect(tasks.count == 7)
        #expect(tasks.contains(.flushDNS))
        #expect(tasks.contains(.rebuildQuickLook))
        #expect(tasks.contains(.clearFontCache))
        #expect(tasks.contains(.purgeMemory))
        #expect(tasks.contains(.rebuildLaunchServices))
        #expect(tasks.contains(.rebuildSpotlight))
        #expect(tasks.contains(.resetIconServices))

        for task in tasks {
            #expect(!task.title.isEmpty)
            #expect(!task.subtitle.isEmpty)
            #expect(!task.systemImage.isEmpty)
        }
    }
}
