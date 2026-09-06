import Combine
import Foundation

@MainActor
final class SystemOptimizationViewModel: ObservableObject {
    @Published var tasks: [OptimizationTaskItem] = OptimizationTaskType.allCases.map { OptimizationTaskItem(id: $0) }
    @Published private(set) var isExecuting = false

    private let optimizer = SystemOptimizer()

    func runAll() async {
        guard !isExecuting else { return }
        isExecuting = true
        defer { isExecuting = false }

        for index in tasks.indices {
            tasks[index].status = .running
            let result = await optimizer.execute(task: tasks[index].id)
            tasks[index].status = result
        }
    }

    func run(task: OptimizationTaskType) async {
        guard !isExecuting, let index = tasks.firstIndex(where: { $0.id == task }) else { return }
        tasks[index].status = .running
        let result = await optimizer.execute(task: task)
        tasks[index].status = result
    }
}
