import Foundation
import CoreData

public final class CoreDataHabitRuntimeReadRepository: HabitRuntimeReadRepositoryProtocol {
    private let context: NSManagedObjectContext
    private static let missingLifeAreaID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

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
                let activeHabits = try self.fetchHabits(
                    predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [
                        NSPredicate(format: "archivedAt == nil"),
                        NSPredicate(format: "isPaused == NO"),
                        NSPredicate(format: "lifeAreaID != nil")
                    ])
                ).filter { $0.trackingMode == .dailyCheckIn }
                guard !activeHabits.isEmpty else {
                    completion(.success([]))
                    return
                }

                let habitIDs = Set(activeHabits.map(\.id))
                let names = try self.fetchOwnershipLookups(habits: activeHabits)
                let scheduleMetadata = try self.fetchHabitScheduleMetadata(habitIDs: habitIDs)
                let startOfDay = calendar.startOfDay(for: date)
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
                let windowStart = calendar.date(byAdding: .day, value: -45, to: startOfDay) ?? startOfDay
                let occurrences = try self.fetchHabitOccurrences(
                    start: windowStart,
                    end: endOfDay,
                    sourceIDs: habitIDs,
                    includeFuture: false
                )
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
                        dayCount: 30,
                        calendar: calendar
                    )
                    return self.buildSummary(
                        habit: habit,
                        occurrence: chosenOccurrence,
                        date: date,
                        last14Days: marks,
                        ownership: names,
                        cadence: scheduleMetadata[habit.id]?.cadence ?? .daily()
                    )
                }

                completion(.success(summaries.sorted(by: self.compareAgendaSummary(_:_:))))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func fetchAgendaHabit(
        habitID: UUID,
        for date: Date,
        completion: @escaping (Result<HabitOccurrenceSummary?, Error>) -> Void
    ) {
        context.perform {
            do {
                let calendar = Calendar.current
                guard let habit = try self.fetchHabits(
                    predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [
                        NSPredicate(format: "id == %@", habitID as CVarArg),
                        NSPredicate(format: "archivedAt == nil"),
                        NSPredicate(format: "isPaused == NO"),
                        NSPredicate(format: "lifeAreaID != nil")
                    ])
                ).first, habit.trackingMode == .dailyCheckIn else {
                    completion(.success(nil))
                    return
                }

                let habitIDs = Set([habit.id])
                let names = try self.fetchOwnershipLookups(habits: [habit])
                let scheduleMetadata = try self.fetchHabitScheduleMetadata(habitIDs: habitIDs)
                let startOfDay = calendar.startOfDay(for: date)
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
                let windowStart = calendar.date(byAdding: .day, value: -45, to: startOfDay) ?? startOfDay
                let history = try self.fetchHabitOccurrences(
                    start: windowStart,
                    end: endOfDay,
                    sourceIDs: habitIDs,
                    includeFuture: false
                )
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
                    completion(.success(nil))
                    return
                }

                let marks = HabitRuntimeSupport.dayMarks(
                    from: history,
                    endingOn: date,
                    dayCount: 30,
                    calendar: calendar
                )
                completion(.success(
                    self.buildSummary(
                        habit: habit,
                        occurrence: chosenOccurrence,
                        date: date,
                        last14Days: marks,
                        ownership: names,
                        cadence: scheduleMetadata[habit.id]?.cadence ?? .daily()
                    )
                ))
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
                let occurrences = try self.fetchHabitOccurrences(
                    start: start,
                    end: endOfDay,
                    sourceIDs: Set(habitIDs),
                    includeFuture: false
                )
                let grouped = Dictionary(grouping: occurrences, by: \.sourceID)
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
                let habits = try self.fetchHabits(
                    predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [
                        NSPredicate(format: "archivedAt == nil"),
                        NSPredicate(format: "isPaused == NO"),
                        NSPredicate(format: "lifeAreaID != nil")
                    ])
                )
                let habitsByID = Dictionary(uniqueKeysWithValues: habits.map { ($0.id, $0) })
                let habitIDs = Set(habitsByID.keys)
                guard habitIDs.isEmpty == false else {
                    completion(.success([]))
                    return
                }
                let names = try self.fetchOwnershipLookups(habits: habits)
                let scheduleMetadata = try self.fetchHabitScheduleMetadata(habitIDs: habitIDs)
                let occurrences = try self.fetchHabitOccurrences(
                    start: start,
                    end: end,
                    sourceIDs: habitIDs,
                    includeFuture: true
                )
                let recentHistoryStart = calendar.date(byAdding: .day, value: -14, to: calendar.startOfDay(for: end)) ?? start
                let historyWindowOccurrences = try self.fetchHabitOccurrences(
                    start: recentHistoryStart,
                    end: end,
                    sourceIDs: habitIDs,
                    includeFuture: true
                )
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
                        ownership: names,
                        cadence: scheduleMetadata[habit.id]?.cadence ?? .daily()
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
                let habits = try self.fetchHabits(
                    predicate: includeArchived ? nil : NSPredicate(format: "archivedAt == nil")
                )
                guard !habits.isEmpty else {
                    completion(.success([]))
                    return
                }

                let habitIDs = Set(habits.map(\.id))
                let names = try self.fetchOwnershipLookups(habits: habits)
                let scheduleMetadata = try self.fetchHabitScheduleMetadata(habitIDs: habitIDs)
                let start = calendar.date(byAdding: .day, value: -30, to: calendar.startOfDay(for: Date())) ?? Date()
                let end = calendar.date(byAdding: .day, value: 30, to: calendar.startOfDay(for: Date())) ?? Date()
                let occurrences = try self.fetchHabitOccurrences(
                    start: start,
                    end: end,
                    sourceIDs: habitIDs,
                    includeFuture: true
                )
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
                    let schedule = scheduleMetadata[habit.id]
                    return HabitLibraryRow(
                        habitID: habit.id,
                        title: habit.title,
                        kind: habit.kind,
                        trackingMode: habit.trackingMode,
                        cadence: schedule?.cadence ?? .daily(),
                        lifeAreaID: habit.lifeAreaID,
                        lifeAreaName: ownership?.lifeAreaName ?? "Needs Repair",
                        projectID: habit.projectID,
                        projectName: ownership?.projectName,
                        icon: habit.icon,
                        colorHex: habit.colorHex,
                        isPaused: habit.isPaused,
                        isArchived: habit.isArchived,
                        currentStreak: habit.streakCurrent,
                        bestStreak: habit.streakBest,
                        last14Days: last14Days,
                        nextDueAt: nextDueAt,
                        lastCompletedAt: lastCompletedAt,
                        reminderWindowStart: schedule?.reminderWindowStart,
                        reminderWindowEnd: schedule?.reminderWindowEnd,
                        notes: habit.notes
                    )
                }

                completion(.success(rows.sorted(by: self.compareLibraryRow(_:_:))))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func fetchHabitLibrary(
        habitIDs: [UUID]?,
        includeArchived: Bool,
        completion: @escaping (Result<[HabitLibraryRow], Error>) -> Void
    ) {
        context.perform {
            do {
                let requestedIDs = habitIDs.map(Set.init)
                if let requestedIDs, requestedIDs.isEmpty {
                    completion(.success([]))
                    return
                }

                let calendar = Calendar.current
                var predicates: [NSPredicate] = []
                if includeArchived == false {
                    predicates.append(NSPredicate(format: "archivedAt == nil"))
                }
                if let requestedIDs, requestedIDs.isEmpty == false {
                    predicates.append(NSPredicate(format: "id IN %@", Array(requestedIDs)))
                }

                let predicate: NSPredicate?
                switch predicates.count {
                case 0:
                    predicate = nil
                case 1:
                    predicate = predicates[0]
                default:
                    predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
                }

                let habits = try self.fetchHabits(predicate: predicate)
                guard !habits.isEmpty else {
                    completion(.success([]))
                    return
                }

                let resolvedHabitIDs = Set(habits.map(\.id))
                let names = try self.fetchOwnershipLookups(habits: habits)
                let scheduleMetadata = try self.fetchHabitScheduleMetadata(habitIDs: resolvedHabitIDs)
                let start = calendar.date(byAdding: .day, value: -30, to: calendar.startOfDay(for: Date())) ?? Date()
                let end = calendar.date(byAdding: .day, value: 30, to: calendar.startOfDay(for: Date())) ?? Date()
                let occurrences = try self.fetchHabitOccurrences(
                    start: start,
                    end: end,
                    sourceIDs: resolvedHabitIDs,
                    includeFuture: true
                )
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
                    let schedule = scheduleMetadata[habit.id]
                    return HabitLibraryRow(
                        habitID: habit.id,
                        title: habit.title,
                        kind: habit.kind,
                        trackingMode: habit.trackingMode,
                        cadence: schedule?.cadence ?? .daily(),
                        lifeAreaID: habit.lifeAreaID,
                        lifeAreaName: ownership?.lifeAreaName ?? "Needs Repair",
                        projectID: habit.projectID,
                        projectName: ownership?.projectName,
                        icon: habit.icon,
                        colorHex: habit.colorHex,
                        isPaused: habit.isPaused,
                        isArchived: habit.isArchived,
                        currentStreak: habit.streakCurrent,
                        bestStreak: habit.streakBest,
                        last14Days: last14Days,
                        nextDueAt: nextDueAt,
                        lastCompletedAt: lastCompletedAt,
                        reminderWindowStart: schedule?.reminderWindowStart,
                        reminderWindowEnd: schedule?.reminderWindowEnd,
                        notes: habit.notes
                    )
                }

                completion(.success(rows.sorted(by: self.compareLibraryRow(_:_:))))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func fetchHabitDetailSummary(
        habitID: UUID,
        includeArchived: Bool,
        completion: @escaping (Result<HabitLibraryRow?, Error>) -> Void
    ) {
        context.perform {
            do {
                var predicates: [NSPredicate] = [NSPredicate(format: "id == %@", habitID as CVarArg)]
                if includeArchived == false {
                    predicates.append(NSPredicate(format: "archivedAt == nil"))
                }

                let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
                guard let habit = try self.fetchHabits(predicate: predicate).first else {
                    completion(.success(nil))
                    return
                }

                let calendar = Calendar.current
                let ownership = try self.fetchOwnershipLookups(habits: [habit])[habit.id]
                let schedule = try self.fetchHabitScheduleMetadata(habitIDs: [habit.id])[habit.id]
                let today = calendar.startOfDay(for: Date())
                let historyStart = calendar.date(byAdding: .day, value: -7, to: today) ?? today
                let lookaheadEnd = calendar.date(byAdding: .day, value: 21, to: today) ?? today
                let occurrences = try self.fetchHabitOccurrences(
                    start: historyStart,
                    end: lookaheadEnd,
                    sourceIDs: [habit.id],
                    includeFuture: true
                )

                let row = self.makeDetailSummaryRow(
                    habit: habit,
                    ownership: ownership,
                    schedule: schedule,
                    occurrences: occurrences,
                    calendar: calendar
                )
                completion(.success(row))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private func fetchHabits(predicate: NSPredicate? = nil) throws -> [HabitDefinitionRecord] {
        let request = NSFetchRequest<NSManagedObject>(entityName: HabitDefinitionMapper.entityName)
        request.predicate = predicate
        request.sortDescriptors = [
            NSSortDescriptor(key: "createdAt", ascending: true),
            NSSortDescriptor(key: "id", ascending: true)
        ]
        return try context.fetch(request).map(HabitDefinitionMapper.toDomain)
    }

    private func makeDetailSummaryRow(
        habit: HabitDefinitionRecord,
        ownership: (lifeAreaName: String?, projectName: String?)?,
        schedule: (cadence: HabitCadenceDraft, reminderWindowStart: String?, reminderWindowEnd: String?)?,
        occurrences: [OccurrenceDefinition],
        calendar: Calendar
    ) -> HabitLibraryRow {
        let today = calendar.startOfDay(for: Date())
        let nextDueAt = occurrences
            .filter { self.occurrenceDate($0) >= today && $0.state == .pending }
            .map(self.occurrenceDate(_:))
            .min()
        let lastCompletedAt = occurrences
            .filter { $0.state == .completed }
            .map(self.occurrenceDate(_:))
            .max()

        return HabitLibraryRow(
            habitID: habit.id,
            title: habit.title,
            kind: habit.kind,
            trackingMode: habit.trackingMode,
            cadence: schedule?.cadence ?? .daily(),
            lifeAreaID: habit.lifeAreaID,
            lifeAreaName: ownership?.lifeAreaName ?? "Needs Repair",
            projectID: habit.projectID,
            projectName: ownership?.projectName,
            icon: habit.icon,
            colorHex: habit.colorHex,
            isPaused: habit.isPaused,
            isArchived: habit.isArchived,
            currentStreak: habit.streakCurrent,
            bestStreak: habit.streakBest,
            last14Days: [],
            nextDueAt: nextDueAt,
            lastCompletedAt: lastCompletedAt,
            reminderWindowStart: schedule?.reminderWindowStart,
            reminderWindowEnd: schedule?.reminderWindowEnd,
            notes: habit.notes
        )
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
        sourceIDs: Set<UUID>? = nil,
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
        var predicates: [NSPredicate] = [
            NSPredicate(format: "sourceType == %@", ScheduleSourceType.habit.rawValue),
            dueRange
        ]
        if let sourceIDs, !sourceIDs.isEmpty {
            predicates.append(NSPredicate(format: "sourceID IN %@", Array(sourceIDs)))
        }
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
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

    private func mapTemplate(_ object: NSManagedObject) -> ScheduleTemplateDefinition {
        ScheduleTemplateDefinition(
            id: object.value(forKey: "id") as? UUID ?? UUID(),
            sourceType: ScheduleSourceType(rawValue: object.value(forKey: "sourceType") as? String ?? "habit") ?? .habit,
            sourceID: object.value(forKey: "sourceID") as? UUID ?? UUID(),
            timezoneID: object.value(forKey: "timezoneID") as? String,
            temporalReference: TemporalReference(rawValue: object.value(forKey: "temporalReference") as? String ?? "anchored") ?? .anchored,
            anchorAt: object.value(forKey: "anchorAt") as? Date,
            windowStart: object.value(forKey: "windowStart") as? String,
            windowEnd: object.value(forKey: "windowEnd") as? String,
            isActive: object.value(forKey: "isActive") as? Bool ?? true,
            createdAt: object.value(forKey: "createdAt") as? Date ?? Date(),
            updatedAt: object.value(forKey: "updatedAt") as? Date ?? Date()
        )
    }

    private func mapRule(_ object: NSManagedObject) -> ScheduleRuleDefinition {
        ScheduleRuleDefinition(
            id: object.value(forKey: "id") as? UUID ?? UUID(),
            scheduleTemplateID: object.value(forKey: "scheduleTemplateID") as? UUID ?? UUID(),
            ruleType: object.value(forKey: "ruleType") as? String ?? "daily",
            interval: Int(object.value(forKey: "interval") as? Int32 ?? 1),
            byDayMask: (object.value(forKey: "byDayMask") as? Int32).map(Int.init),
            byMonthDay: (object.value(forKey: "byMonthDay") as? Int32).map(Int.init),
            byHour: (object.value(forKey: "byHour") as? Int32).map(Int.init),
            byMinute: (object.value(forKey: "byMinute") as? Int32).map(Int.init),
            rawRuleData: object.value(forKey: "rawRuleData") as? Data,
            createdAt: object.value(forKey: "createdAt") as? Date ?? Date()
        )
    }

    private func buildSummary(
        habit: HabitDefinitionRecord,
        occurrence: OccurrenceDefinition,
        date: Date,
        last14Days: [HabitDayMark],
        ownership: [UUID: (lifeAreaName: String?, projectName: String?)],
        cadence: HabitCadenceDraft
    ) -> HabitOccurrenceSummary {
        let names = ownership[habit.id]
        return HabitOccurrenceSummary(
            habitID: habit.id,
            occurrenceID: occurrence.id,
            title: habit.title,
            kind: habit.kind,
            trackingMode: habit.trackingMode,
            lifeAreaID: habit.lifeAreaID ?? Self.missingLifeAreaID,
            lifeAreaName: names?.lifeAreaName ?? "Needs Repair",
            projectID: habit.projectID,
            projectName: names?.projectName,
            icon: habit.icon,
            colorHex: habit.colorHex,
            cadence: cadence,
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

    private func fetchHabitScheduleMetadata(
        habitIDs: Set<UUID>
    ) throws -> [UUID: (cadence: HabitCadenceDraft, reminderWindowStart: String?, reminderWindowEnd: String?)] {
        guard !habitIDs.isEmpty else { return [:] }

        let templateRequest = NSFetchRequest<NSManagedObject>(entityName: "ScheduleTemplate")
        templateRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "sourceType == %@", ScheduleSourceType.habit.rawValue),
            NSPredicate(format: "sourceID IN %@", Array(habitIDs))
        ])
        templateRequest.sortDescriptors = [
            NSSortDescriptor(key: "updatedAt", ascending: false),
            NSSortDescriptor(key: "createdAt", ascending: false),
            NSSortDescriptor(key: "id", ascending: true)
        ]
        let templates = try context.fetch(templateRequest).map(self.mapTemplate(_:))
        guard !templates.isEmpty else { return [:] }

        var preferredTemplatesByHabitID: [UUID: ScheduleTemplateDefinition] = [:]
        for template in templates {
            preferredTemplatesByHabitID[template.sourceID] = preferredTemplatesByHabitID[template.sourceID] ?? template
        }
        let templateIDs = Array(Set(preferredTemplatesByHabitID.values.map(\.id)))
        let ruleRequest = NSFetchRequest<NSManagedObject>(entityName: "ScheduleRule")
        ruleRequest.predicate = NSPredicate(format: "scheduleTemplateID IN %@", templateIDs)
        ruleRequest.sortDescriptors = [
            NSSortDescriptor(key: "createdAt", ascending: true),
            NSSortDescriptor(key: "id", ascending: true)
        ]
        let rulesByTemplateID = Dictionary(grouping: try context.fetch(ruleRequest).map(self.mapRule(_:)), by: \.scheduleTemplateID)

        return Dictionary(uniqueKeysWithValues: preferredTemplatesByHabitID.map { habitID, template in
            (
                habitID,
                (
                    cadence: HabitRuntimeSupport.cadence(from: template, rules: rulesByTemplateID[template.id] ?? []),
                    reminderWindowStart: template.windowStart,
                    reminderWindowEnd: template.windowEnd
                )
            )
        })
    }
}
