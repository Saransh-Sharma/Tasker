import Foundation

struct BuildNeedsReplanCandidatesUseCase {
    func execute(
        tasks: [TaskDefinition],
        projectsByID: [UUID: Project],
        now: Date = Date(),
        calendar: Calendar = .current,
        scopedTo scopedDate: Date? = nil
    ) -> [HomeReplanCandidate] {
        let todayStart = calendar.startOfDay(for: now)
        let scopedStart = scopedDate.map { calendar.startOfDay(for: $0) }
        var seen: Set<UUID> = []

        return tasks.compactMap { task -> HomeReplanCandidate? in
            guard seen.insert(task.id).inserted else { return nil }
            guard task.isComplete == false,
                  task.parentTaskID == nil,
                  task.repeatPattern == nil,
                  task.recurrenceSeriesID == nil,
                  task.habitDefinitionID == nil,
                  projectsByID[task.projectID]?.isArchived != true else {
                return nil
            }

            if let dueDate = task.dueDate,
               calendar.startOfDay(for: dueDate) < todayStart {
                if let scopedStart,
                   calendar.isDate(calendar.startOfDay(for: dueDate), inSameDayAs: scopedStart) == false {
                   return nil
                }
                return HomeReplanCandidate(
                    task: task,
                    kind: .pastDue,
                    anchorDate: dueDate,
                    anchorEndDate: task.scheduledEndAt,
                    projectName: task.projectName
                )
            }

            if let scheduledStartAt = task.scheduledStartAt,
               calendar.startOfDay(for: scheduledStartAt) < todayStart {
                if let scopedStart,
                   calendar.isDate(calendar.startOfDay(for: scheduledStartAt), inSameDayAs: scopedStart) == false {
                    return nil
                }
                return HomeReplanCandidate(
                    task: task,
                    kind: .scheduledCarryOver,
                    anchorDate: scheduledStartAt,
                    anchorEndDate: task.scheduledEndAt,
                    projectName: task.projectName
                )
            }

            guard scopedStart == nil,
                  task.dueDate == nil,
                  task.scheduledStartAt == nil,
                  task.scheduledEndAt == nil else {
                return nil
            }
            return HomeReplanCandidate(
                task: task,
                kind: .unscheduledBacklog,
                anchorDate: nil,
                anchorEndDate: nil,
                projectName: task.projectName
            )
        }
        .sorted(by: Self.sortCandidates)
    }

    private static func sortCandidates(_ lhs: HomeReplanCandidate, _ rhs: HomeReplanCandidate) -> Bool {
        let lhsIsDated = lhs.anchorDate != nil
        let rhsIsDated = rhs.anchorDate != nil
        if lhsIsDated != rhsIsDated { return lhsIsDated }
        if let lhsDay = lhs.anchorDay, let rhsDay = rhs.anchorDay, lhsDay != rhsDay {
            return lhsDay > rhsDay
        }
        if let lhsAnchor = lhs.anchorDate, let rhsAnchor = rhs.anchorDate, lhsAnchor != rhsAnchor {
            return lhsAnchor > rhsAnchor
        }
        if lhs.task.priority.scorePoints != rhs.task.priority.scorePoints {
            return lhs.task.priority.scorePoints > rhs.task.priority.scorePoints
        }
        if lhs.anchorDate == nil, rhs.anchorDate == nil, lhs.task.updatedAt != rhs.task.updatedAt {
            return lhs.task.updatedAt < rhs.task.updatedAt
        }
        return lhs.task.title.localizedStandardCompare(rhs.task.title) == .orderedAscending
    }
}
