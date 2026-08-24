import Foundation

extension PlanStore {
    /// Applies a reviewed Make It Fit Today diff as one planning receipt.
    /// `planningDay` changes intent; `dueDate` is deliberately untouched.
    @discardableResult
    func applyMakeItFit(
        choices: [UUID: MakeItFitDestination],
        referenceDate: Date = Date()
    ) async -> Bool {
        guard choices.contains(where: { $0.value != .keepToday }) else { return false }
        let byID = Dictionary(tasks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let calendar = Calendar.current
        let today = PlanningDay(date: referenceDate, timeZone: calendar.timeZone, calendar: calendar)

        let mutations: [PlanMutation] = choices.compactMap { taskID, destination in
            guard destination != .keepToday, let task = byID[taskID] else { return nil }
            var after = task.metadata
            switch destination {
            case .keepToday:
                return nil
            case .tomorrow:
                after.planningDay = shiftedDay(today, by: 1, calendar: calendar)
                after.unscheduledDisposition = .inbox
            case .later:
                after.planningDay = shiftedDay(today, by: 14, calendar: calendar)
                after.unscheduledDisposition = .inbox
            case .someday:
                after.planningDay = nil
                after.pinOrder = nil
                after.unscheduledDisposition = .someday
            case .inbox:
                after.planningDay = nil
                after.pinOrder = nil
                after.unscheduledDisposition = .inbox
            }
            after.updatedAt = Date()
            return .saveTaskMetadata(before: task.metadata, after: after)
        }
        guard mutations.isEmpty == false else { return false }

        do {
            _ = try await workspaceCommit(
                .batch(mutations),
                source: "eva.make_it_fit_today",
                summary: mutations.count == 1
                    ? "Made room in today"
                    : "Made room in today · \(mutations.count) changes"
            )
            await load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func shiftedDay(_ day: PlanningDay, by offset: Int, calendar: Calendar) -> PlanningDay? {
        guard let start = day.startDate(calendar: calendar),
              let shifted = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
        return PlanningDay(date: shifted, timeZone: calendar.timeZone, calendar: calendar)
    }
}
