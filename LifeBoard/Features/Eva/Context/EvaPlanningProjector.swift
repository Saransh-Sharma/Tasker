import Foundation
import LifeBoardDomain

/// Reads the task graph into typed records for the cloud envelope.
///
/// It queries the same buckets and the same repository as the compact
/// plain-text projection, so the two agree on what "today" and "overdue" mean.
/// What differs is the fidelity: every field the model can reason with survives,
/// instead of being flattened to `title | due | project`.
///
/// Only ever invoked in `.rich` mode. Nothing here runs on the offline path.
struct EvaPlanningProjector: Sendable {
    let taskReadModelRepository: TaskReadModelRepositoryProtocol
    let projectRepository: ProjectRepositoryProtocol?
    let lifeAreaRepository: LifeAreaRepositoryProtocol?
    /// Cloud sizes the roster by token budget, not by a device-thermal slice.
    let maxTasksPerBucket: Int

    static func makeDefault(maxTasksPerBucket: Int = 200) -> EvaPlanningProjector? {
        guard let taskReadModelRepository = LLMContextRepositoryFactory.taskReadModelRepository else {
            return nil
        }
        return EvaPlanningProjector(
            taskReadModelRepository: taskReadModelRepository,
            projectRepository: LLMContextRepositoryFactory.projectRepository,
            lifeAreaRepository: LLMContextRepositoryFactory.lifeAreaRepository,
            maxTasksPerBucket: maxTasksPerBucket
        )
    }

    struct Projection: Sendable {
        let tasks: [EvaTaskRecord]
        let summary: EvaPlanningSummary
        let projects: [EvaProjectRecord]
        let lifeAreas: [EvaLifeAreaRecord]
        let partialSections: [String]
    }

    func project(now: Date = Date()) async -> Projection {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now
        let endOfToday = startOfTomorrow.addingTimeInterval(-1)
        let startOfDayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: startOfToday) ?? startOfTomorrow
        let endOfTomorrow = startOfDayAfterTomorrow.addingTimeInterval(-1)
        let endOfWeek = calendar.date(byAdding: DateComponents(day: 7, second: -1), to: startOfTomorrow) ?? endOfTomorrow

        async let overdueFetch = fetch(.init(
            includeCompleted: false, dueDateEnd: startOfToday,
            sortBy: .dueDateAscending, limit: maxTasksPerBucket, offset: 0))
        async let todayFetch = fetch(.init(
            includeCompleted: false, dueDateStart: startOfToday, dueDateEnd: endOfToday,
            sortBy: .dueDateAscending, limit: maxTasksPerBucket, offset: 0))
        async let tomorrowFetch = fetch(.init(
            includeCompleted: false, dueDateStart: startOfTomorrow, dueDateEnd: endOfTomorrow,
            sortBy: .dueDateAscending, limit: maxTasksPerBucket, offset: 0))
        async let weekFetch = fetch(.init(
            includeCompleted: false, dueDateStart: startOfDayAfterTomorrow, dueDateEnd: endOfWeek,
            sortBy: .dueDateAscending, limit: maxTasksPerBucket, offset: 0))
        async let backlogFetch = fetch(.init(
            includeCompleted: false,
            sortBy: .updatedAtDescending, limit: maxTasksPerBucket, offset: 0))
        async let completedFetch = fetch(.init(
            includeCompleted: true, dueDateStart: startOfToday, dueDateEnd: endOfToday,
            sortBy: .dueDateAscending, limit: maxTasksPerBucket, offset: 0))
        async let projectsFetch = fetchProjects()
        async let lifeAreasFetch = fetchLifeAreas()

        // An overdue query bounded by `dueDateEnd` can still include today's
        // items on the boundary; the compact projection filters the same way.
        let overdue = await overdueFetch.filter { ($0.dueDate ?? .distantFuture) < startOfToday }
        let today = await todayFetch
        let tomorrow = await tomorrowFetch
        let week = await weekFetch
        let completedToday = await completedFetch.filter(\.isComplete)
        let scheduledIDs = Set((overdue + today + tomorrow + week).map(\.id))
        let backlog = await backlogFetch.filter { $0.dueDate == nil && !scheduledIDs.contains($0.id) }

        let projects = await projectsFetch
        let lifeAreas = await lifeAreasFetch
        let projectNameByID = Dictionary(projects.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let lifeAreaNameByID = Dictionary(lifeAreas.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })

        var records: [EvaTaskRecord] = []
        func add(_ tasks: [TaskDefinition], _ bucket: EvaTaskRecord.Bucket) {
            for task in tasks {
                records.append(EvaTaskRecord(
                    task: task,
                    bucket: bucket,
                    projectName: task.projectName ?? projectNameByID[task.projectID],
                    lifeAreaName: task.lifeAreaID.flatMap { lifeAreaNameByID[$0] },
                    rankReasons: Self.reasons(for: task, bucket: bucket, now: now),
                    now: now
                ))
            }
        }
        add(overdue, .overdue)
        add(today, .today)
        add(tomorrow, .tomorrow)
        add(week, .thisWeek)
        add(backlog, .unscheduled)
        add(completedToday, .completed)

        let openCountByProject = records.reduce(into: [UUID: Int]()) { partial, record in
            guard record.bucket != .completed, let projectID = record.projectID else { return }
            partial[projectID, default: 0] += 1
        }
        let openCountByLifeArea = records.reduce(into: [String: Int]()) { partial, record in
            guard record.bucket != .completed, let lifeArea = record.lifeArea else { return }
            partial[lifeArea, default: 0] += 1
        }

        return Projection(
            tasks: records,
            summary: EvaPlanningSummary(
                overdue: overdue.count,
                today: today.count,
                tomorrow: tomorrow.count,
                thisWeek: week.count,
                unscheduled: backlog.count,
                completedToday: completedToday.count
            ),
            projects: projects.map {
                EvaProjectRecord(
                    id: $0.id,
                    name: $0.name,
                    lifeArea: $0.lifeAreaID.flatMap { id in lifeAreaNameByID[id] },
                    openTaskCount: openCountByProject[$0.id] ?? 0,
                    motivationWhy: $0.motivationWhy
                )
            },
            lifeAreas: lifeAreas.map {
                EvaLifeAreaRecord(id: $0.id, name: $0.name, openTaskCount: openCountByLifeArea[$0.name] ?? 0)
            },
            partialSections: []
        )
    }

    /// Short, checkable statements about why a record is worth attention.
    ///
    /// Deliberately factual rather than advisory: EVA should be able to cite the
    /// signal and then disagree with it. A reason that already contains a verdict
    /// gives it nothing to reason about.
    private static func reasons(for task: TaskDefinition, bucket: EvaTaskRecord.Bucket, now: Date) -> [String] {
        var reasons: [String] = []
        if bucket == .overdue, let due = task.dueDate {
            let days = max(1, Calendar.current.dateComponents([.day], from: due, to: now).day ?? 1)
            reasons.append("overdue by \(days) day\(days == 1 ? "" : "s")")
        }
        if task.deferredCount > 0 {
            reasons.append("deferred \(task.deferredCount) time\(task.deferredCount == 1 ? "" : "s")")
        }
        if task.replanCount > 0 {
            reasons.append("rescheduled \(task.replanCount) time\(task.replanCount == 1 ? "" : "s")")
        }
        if task.priority == .max || task.priority == .high {
            reasons.append("priority \(task.priority.rawValue)")
        }
        return reasons
    }

    private func fetch(_ query: TaskReadQuery) async -> [TaskDefinition] {
        guard !Task.isCancelled else { return [] }
        return await withCheckedContinuation { continuation in
            taskReadModelRepository.fetchTasks(query: query) { result in
                continuation.resume(returning: (try? result.get().tasks) ?? [])
            }
        }
    }

    private func fetchProjects() async -> [Project] {
        guard let projectRepository, !Task.isCancelled else { return [] }
        return await withCheckedContinuation { continuation in
            projectRepository.fetchAllProjects { result in
                continuation.resume(returning: ((try? result.get()) ?? []).filter { !$0.isArchived })
            }
        }
    }

    private func fetchLifeAreas() async -> [LifeArea] {
        guard let lifeAreaRepository, !Task.isCancelled else { return [] }
        return await withCheckedContinuation { continuation in
            lifeAreaRepository.fetchAll { result in
                continuation.resume(returning: ((try? result.get()) ?? []).filter { !$0.isArchived })
            }
        }
    }
}
