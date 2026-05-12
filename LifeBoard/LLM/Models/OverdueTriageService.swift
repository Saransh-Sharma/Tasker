import Foundation

struct OverdueTriageSuggestion {
    let envelope: AssistantCommandEnvelope
    let summaryLines: [String]
}

struct OverdueTriageService {
    /// Executes buildSuggestion.
    func buildSuggestion(from overdueTasks: [TaskDefinition], now: Date = Date()) -> OverdueTriageSuggestion? {
        let openOverdue = overdueTasks.filter { !$0.isComplete }
        guard openOverdue.count >= 3 else { return nil }

        let calendar = Calendar.current
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
        let nextWeek = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 7, to: now) ?? now)

        var commands: [AssistantCommand] = []
        var movedToNextWeek = 0
        var movedToTomorrow = 0
        var keptToday = 0

        for task in openOverdue {
            switch task.priority {
            case .none, .low:
                commands.append(.updateTask(taskID: task.id, title: nil, dueDate: nextWeek))
                movedToNextWeek += 1
            case .high:
                commands.append(.updateTask(taskID: task.id, title: nil, dueDate: tomorrow))
                movedToTomorrow += 1
            case .max:
                keptToday += 1
            }
        }

        guard commands.isEmpty == false else { return nil }

        let summary = [
            movedToNextWeek > 0 ? "Reschedule \(movedToNextWeek) lowest-priority task(s) to next week" : nil,
            movedToTomorrow > 0 ? "Reschedule \(movedToTomorrow) low-priority task(s) to tomorrow" : nil,
            keptToday > 0 ? "Keep \(keptToday) high-priority task(s) in today focus" : nil
        ].compactMap { $0 }

        return OverdueTriageSuggestion(
            envelope: AssistantCommandEnvelope(
                schemaVersion: 2,
                commands: commands,
                rationaleText: "Reduce overwhelm while keeping critical work visible."
            ),
            summaryLines: summary
        )
    }
}
