import Foundation
import CoreData

public final class CoreDataHabitRuntimeReadRepository: HabitRuntimeReadRepositoryProtocol {
    private let context: NSManagedObjectContext

    public init(container: NSPersistentContainer) {
        self.context = container.newBackgroundContext()
        self.context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    public func fetchAgendaHabits(
        for date: Date,
        completion: @escaping (Result<[HabitOccurrenceSummary], Error>) -> Void
    ) {
        context.perform {
            do {
                let calendar = Calendar.current
                let habits = try self.fetchHabits()
                let activeHabits = habits.filter { !$0.isArchived && !$0.isPaused && $0.trackingMode == .dailyCheckIn }
                guard !activeHabits.isEmpty else {
                    completion(.success([]))
                    return
                }

                let habitIDs = activeHabits.map(\.id)
                let names = try self.fetchOwnershipLookups(habits: activeHabits)
                let startOfDay = calendar.startOfDay(for: date)
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
                let windowStart = calendar.date(byAdding: .day, value: -45, to: startOfDay) ?? startOfDay
                let occurrences = try self.fetchHabitOccurrences(start: windowStart, end: endOfDay, includeFuture: false)
                    .filter { habitIDs.contains($0.sourceID) }
                let occurrencesByHabitID = Dictionary(grouping: occurrences, by: \.sourceID)

                let summaries = activeHabits.compactMap { habit -> HabitOccurrenceSummary? in
                    let history = occurrencesByHabitID[habit.id] ?? []
                    let todayOccurrence = history
                        .filter { occurrence in
                            let occurrenceDate = self.occurrenceDate(occurrence)
                            return occurrenceDate >= startOfDay && occurrenceDate < endOfDay
                        }
                        .sorted(by: { self.occurrenceDate($0) < self.occurrenceDate($1) })
                        .last
                    let overdueOccurrence = history
                        .filter { occurrence in
                            occurrence.state == .pending && self.occurrenceDate(occurrence) < startOfDay
                        }
                        .sorted(by: { self.occurrenceDate($0) < self.occurrenceDate($1) })
                        .last

                    guard let chosenOccurrence = todayOccurrence ?? overdueOccurrence else {
                        return nil
                    }

                    let marks = HabitRuntimeSupport.dayMarks(
                        from: history,
                        endingOn: date,
                        dayCount: 14,
                        calendar: calendar
                    )
                    return self.buildSummary(
                        habit: habit,
                        occurrence: chosenOccurrence,
                        date: date,
                        last14Days: marks,
                        ownership: names
                    )
                }

                completion(.success(summaries.sorted(by: self.compareAgendaSummary(_:_:))))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func fetchHistory(
        habitIDs: [UUID],
        endingOn date: Date,
        dayCount: Int,
        completion: @escaping (Result<[HabitHistoryWindow], Error>) -> Void
    ) {
        context.perform {
            do {
                guard !habitIDs.isEmpty else {
                    completion(.success([]))
                    return
                }
                let calendar = Calendar.current
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
                let start = calendar.date(byAdding: .day, value: -(dayCount + 7), to: calendar.startOfDay(for: date)) ?? date
                let occurrences = try self.fetchHabitOccurrences(start: start, end: endOfDay, includeFuture: false)
                let grouped = Dictionary(grouping: occurrences.filter { habitIDs.contains($0.sourceID) }, by: \.sourceID)
                let history = habitIDs.map { habitID in
                    HabitHistoryWindow(
                        habitID: habitID,
                        marks: HabitRuntimeSupport.dayMarks(
                            from: grouped[habitID] ?? [],
                            endingOn: date,
                            dayCount: dayCount,
                            calendar: calendar
                        )
                    )
                }
                completion(.success(history))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func fetchSignals(
        start: Date,
        end: Date,
        completion: @escaping (Result<[HabitOccurrenceSummary], Error>) -> Void
    ) {
        context.perform {
            do {
                let calendar = Calendar.current
                let habits = try self.fetchHabits()
                let habitsByID = Dictionary(uniqueKeysWithValues: habits.map { ($0.id, $0) })
                let names = try self.fetchOwnershipLookups(habits: habits)
                let occurrences = try self.fetchHabitOccurrences(start: start, end: end, includeFuture: true)
                let recentHistoryStart = calendar.date(byAdding: .day, value: -14, to: calendar.startOfDay(for: end)) ?? start
                let historyWindowOccurrences = try self.fetchHabitOccurrences(start: recentHistoryStart, end: end, includeFuture: true)
                let historyByHabitID = Dictionary(grouping: historyWindowOccurrences, by: \.sourceID)

                let summaries = occurrences.compactMap { occurrence -> HabitOccurrenceSummary? in
                    guard let habit = habitsByID[occurrence.sourceID], !habit.isArchived else {
                        return nil
                    }
                    let last14Days = HabitRuntimeSupport.dayMarks(
                        from: historyByHabitID[habit.id] ?? [],
                        endingOn: self.occurrenceDate(occurrence),
                        dayCount: 14,
                        calendar: calendar
                    )
                    return self.buildSummary(
                        habit: habit,
                        occurrence: occurrence,
                        date: self.occurrenceDate(occurrence),
                        last14Days: last14Days,
                        ownership: names
                    )
                }

                completion(.success(summaries.sorted { lhs, rhs in
                    let lhsDate = lhs.dueAt ?? .distantPast
                    let rhsDate = rhs.dueAt ?? .distantPast
                    if lhsDate != rhsDate {
                        return lhsDate < rhsDate
                    }
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func fetchHabitLibrary(
        includeArchived: Bool,
        completion: @escaping (Result<[HabitLibraryRow], Error>) -> Void
    ) {
        context.perform {
            do {
                let calendar = Calendar.current
                let habits = try self.fetchHabits()
                    .filter { includeArchived || !$0.isArchived }
                guard !habits.isEmpty else {
                    completion(.success([]))
                    return
                }

                let names = try self.fetchOwnershipLookups(habits: habits)
                let start = calendar.date(byAdding: .day, value: -30, to: calendar.startOfDay(for: Date())) ?? Date()
                let end = calendar.date(byAdding: .day, value: 30, to: calendar.startOfDay(for: Date())) ?? Date()
                let occurrences = try self.fetchHabitOccurrences(start: start, end: end, includeFuture: true)
                let occurrencesByHabitID = Dictionary(grouping: occurrences, by: \.sourceID)

                let rows = habits.map { habit in
                    let history = occurrencesByHabitID[habit.id] ?? []
                    let last14Days = HabitRuntimeSupport.dayMarks(
                        from: history,
                        endingOn: Date(),
                        dayCount: 14,
                        calendar: calendar
                    )
                    let nextDueAt = history
                        .filter { self.occurrenceDate($0) >= calendar.startOfDay(for: Date()) && $0.state == .pending }
                        .map(self.occurrenceDate(_:))
                        .min()
                    let lastCompletedAt = history
                        .filter { $0.state == .completed }
                        .map(self.occurrenceDate(_:))
                        .max()
                    let ownership = names[habit.id]
                    return HabitLibraryRow(
                        habitID: habit.id,
                        title: habit.title,
                        kind: habit.kind,
                        trackingMode: habit.trackingMode,
                        lifeAreaID: habit.lifeAreaID,
                        lifeAreaName: ownership?.lifeAreaName ?? "General",
                        projectID: habit.projectID,
                        projectName: ownership?.projectName,
                        icon: habit.icon,
                        isPaused: habit.isPaused,
                        isArchived: habit.isArchived,
                        currentStreak: habit.streakCurrent,
                        bestStreak: habit.streakBest,
                        last14Days: last14Days,
                        nextDueAt: nextDueAt,
                        lastCompletedAt: lastCompletedAt,
                        notes: habit.notes
                    )
                }

                completion(.success(rows.sorted(by: self.compareLibraryRow(_:_:))))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private func fetchHabits() throws -> [HabitDefinitionRecord] {
        let request = NSFetchRequest<NSManagedObject>(entityName: HabitDefinitionMapper.entityName)
        request.sortDescriptors = [
            NSSortDescriptor(key: "createdAt", ascending: true),
            NSSortDescriptor(key: "id", ascending: true)
        ]
        return try context.fetch(request).map(HabitDefinitionMapper.toDomain)
    }

    private func fetchOwnershipLookups(
        habits: [HabitDefinitionRecord]
    ) throws -> [UUID: (lifeAreaName: String?, projectName: String?)] {
        let lifeAreaIDs = Set(habits.compactMap(\.lifeAreaID))
        let projectIDs = Set(habits.compactMap(\.projectID))
        let lifeAreaNames = try fetchNames(entityName: "LifeArea", ids: lifeAreaIDs)
        let projectNames = try fetchNames(entityName: "Project", ids: projectIDs)
        return Dictionary(uniqueKeysWithValues: habits.map { habit in
            (
                habit.id,
                (
                    lifeAreaNames[habit.lifeAreaID ?? UUID()],
                    projectNames[habit.projectID ?? UUID()]
                )
            )
        })
    }

    private func fetchNames(
        entityName: String,
        ids: Set<UUID>
    ) throws -> [UUID: String] {
        guard !ids.isEmpty else { return [:] }
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.predicate = NSPredicate(format: "id IN %@", Array(ids))
        return Dictionary(uniqueKeysWithValues: try context.fetch(request).compactMap { object in
            guard let id = object.value(forKey: "id") as? UUID,
                  let name = object.value(forKey: "name") as? String else {
                return nil
            }
            return (id, name)
        })
    }

    private func fetchHabitOccurrences(
        start: Date,
        end: Date,
        includeFuture: Bool
    ) throws -> [OccurrenceDefinition] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Occurrence")
        let dueRange = NSPredicate(
            format: "(dueAt >= %@ AND dueAt < %@) OR (dueAt == nil AND scheduledAt >= %@ AND scheduledAt < %@)",
            start as NSDate,
            end as NSDate,
            start as NSDate,
            end as NSDate
        )
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "sourceType == %@", ScheduleSourceType.habit.rawValue),
            dueRange
        ])
        request.sortDescriptors = [
            NSSortDescriptor(key: "dueAt", ascending: true),
            NSSortDescriptor(key: "scheduledAt", ascending: true),
            NSSortDescriptor(key: "id", ascending: true)
        ]
        let objects = try context.fetch(request)
        let mapped = objects.map(self.mapOccurrence(_:))
        if includeFuture {
            return mapped
        }
        return mapped.filter { self.occurrenceDate($0) < end }
    }

    private func mapOccurrence(_ object: NSManagedObject) -> OccurrenceDefinition {
        let scheduleTemplateID = object.value(forKey: "scheduleTemplateID") as? UUID ?? UUID()
        let sourceID = object.value(forKey: "sourceID") as? UUID ?? UUID()
        let scheduledAt = object.value(forKey: "scheduledAt") as? Date ?? Date()
        let occurrenceKey = object.value(forKey: "occurrenceKey") as? String
            ?? OccurrenceKeyCodec.encode(
                scheduleTemplateID: scheduleTemplateID,
                scheduledAt: scheduledAt,
                sourceID: sourceID
            )
        return OccurrenceDefinition(
            id: object.value(forKey: "id") as? UUID ?? UUID(),
            occurrenceKey: occurrenceKey,
            scheduleTemplateID: scheduleTemplateID,
            sourceType: ScheduleSourceType(rawValue: object.value(forKey: "sourceType") as? String ?? "habit") ?? .habit,
            sourceID: sourceID,
            scheduledAt: scheduledAt,
            dueAt: object.value(forKey: "dueAt") as? Date,
            state: OccurrenceState(rawValue: object.value(forKey: "state") as? String ?? "pending") ?? .pending,
            isGenerated: object.value(forKey: "isGenerated") as? Bool ?? true,
            generationWindow: object.value(forKey: "generationWindow") as? String,
            createdAt: object.value(forKey: "createdAt") as? Date ?? Date(),
            updatedAt: object.value(forKey: "updatedAt") as? Date ?? Date()
        )
    }

    private func buildSummary(
        habit: HabitDefinitionRecord,
        occurrence: OccurrenceDefinition,
        date: Date,
        last14Days: [HabitDayMark],
        ownership: [UUID: (lifeAreaName: String?, projectName: String?)]
    ) -> HabitOccurrenceSummary {
        let names = ownership[habit.id]
        return HabitOccurrenceSummary(
            habitID: habit.id,
            occurrenceID: occurrence.id,
            title: habit.title,
            kind: habit.kind,
            trackingMode: habit.trackingMode,
            lifeAreaID: habit.lifeAreaID ?? UUID(),
            lifeAreaName: names?.lifeAreaName ?? "General",
            projectID: habit.projectID,
            projectName: names?.projectName,
            icon: habit.icon,
            dueAt: occurrenceDate(occurrence),
            state: occurrence.state,
            currentStreak: habit.streakCurrent,
            bestStreak: habit.streakBest,
            riskState: HabitRuntimeSupport.riskState(
                for: last14Days,
                dueAt: occurrenceDate(occurrence),
                occurrenceState: occurrence.state,
                referenceDate: date,
                calendar: .current
            ),
            last14Days: last14Days
        )
    }

    private func occurrenceDate(_ occurrence: OccurrenceDefinition) -> Date {
        occurrence.dueAt ?? occurrence.scheduledAt
    }

    private func compareAgendaSummary(_ lhs: HabitOccurrenceSummary, _ rhs: HabitOccurrenceSummary) -> Bool {
        let lhsDate = lhs.dueAt ?? .distantFuture
        let rhsDate = rhs.dueAt ?? .distantFuture
        if lhsDate != rhsDate {
            return lhsDate < rhsDate
        }
        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    private func compareLibraryRow(_ lhs: HabitLibraryRow, _ rhs: HabitLibraryRow) -> Bool {
        if lhs.isArchived != rhs.isArchived {
            return !lhs.isArchived
        }
        if lhs.isPaused != rhs.isPaused {
            return !lhs.isPaused
        }
        if lhs.currentStreak != rhs.currentStreak {
            return lhs.currentStreak > rhs.currentStreak
        }
        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }
}
