import Foundation
import LifeBoardDomain
import NaturalLanguage

/// The minimum useful context for each Cloud EVA route. Keeping the manifest
/// beside the assembler makes route expansion reviewable and testable: a new
/// route cannot silently inherit the chat firehose.
enum EvaContextRouteManifest {
    static func includes(_ category: EvaCloudContextSection.Category, route: EvaCloudRoute) -> Bool {
        categories(for: route).contains(category)
    }

    static func categories(for route: EvaCloudRoute) -> Set<EvaCloudContextSection.Category> {
        switch route {
        case .chat, .shortcutsAnswer:
            [.planning, .capacity, .calendar, .goals, .habits, .personalMemory,
             .dayLoop, .retrospective, .knowledge, .journal, .health, .lifeMoments]
        case .plan, .planRepair, .topThree, .dailyBrief, .dynamicChips:
            [.planning, .capacity, .calendar, .goals, .habits, .dayLoop,
             .retrospective, .personalMemory]
        case .knowledgeAnswer:
            [.knowledge]
        case .journalAnswer:
            [.journal]
        case .memoryCandidate:
            [.personalMemory]
        case .fieldSuggestion, .taskBreakdown:
            [.planning, .goals]
        case .capture:
            [.planning, .goals, .habits, .knowledge]
        case .navigation, .universalInputClassification, .debugSmoke:
            []
        }
    }
}

/// Assembles the context sections for one turn.
///
/// This is the seam the chat view calls. It exists so the provider split lives
/// in one testable place rather than as a conditional inside a 2,500-line view,
/// and so the offline path keeps calling exactly the code it called before.
enum EvaTurnContextAssembler {
    /// Sections for a turn, sized and shaped by the resolved budget.
    ///
    /// Offline returns the v1 projection unchanged. Cloud projects the task
    /// graph into typed records and drops whole records to fit.
    ///
    /// A failed or timed-out rich projection degrades to the compact sections
    /// rather than to nothing: a smaller honest envelope still answers most
    /// questions, whereas an empty one makes EVA claim it cannot see anything.
    static func sections(
        budget: EvaContextBudget,
        compactProjection: String,
        executiveState: String?,
        slashCommandState: String?,
        personalMemory: String?,
        habitSignals: [LifeBoardHabitSignal],
        evidence: EvaAuthorizedEvidenceContext,
        consent: EvaConsentPolicy?,
        route: EvaCloudRoute = .chat,
        userQuery: String = "",
        now: Date = Date()
    ) async -> [EvaCloudContextSection] {
        let compact = EvaCloudContextProjection.sections(
            taskProjection: compactProjection,
            executiveState: executiveState,
            slashCommandState: slashCommandState,
            personalMemory: personalMemory,
            evidence: evidence,
            consent: consent
        )
        guard budget.isCloud, let projector = EvaPlanningProjector.makeDefault() else {
            return compact
        }

        guard let projection = await projectionWithDeadline(projector, now: now) else {
            let degraded = EvaContextSectionFactory.planning(
                renderedOverview: compactProjection,
                partialSections: ["planningProjectionDeadline"],
                now: now
            )
            return EvaEnvelopeAllocator.allocate([degraded], budget: budget)
        }
        async let prioritizedTasks = semanticallyPrioritized(projection.tasks, query: userQuery)
        async let knowledgeRecords = EvaContextRouteManifest.includes(.knowledge, route: route)
            ? knowledgeRecords(query: userQuery)
            : []
        async let calendarProjection = EvaContextRouteManifest.includes(.calendar, route: route)
            ? calendarProjection(now: now)
            : EvaCalendarProjection.empty
        async let goalRecords = EvaContextRouteManifest.includes(.goals, route: route)
            ? goalRecords(now: now)
            : []
        async let retrospectiveRecord = EvaContextRouteManifest.includes(.retrospective, route: route)
            ? retrospectiveRecord(now: now)
            : nil
        async let journalEvidence = EvaContextRouteManifest.includes(.journal, route: route)
            ? journalEvidenceSection(query: userQuery, consent: consent)
            : nil
        let tasks = await prioritizedTasks
        let knowledge = await knowledgeRecords
        let calendar = await calendarProjection
        let goals = await goalRecords
        let retrospective = await retrospectiveRecord
        let journal = await journalEvidence
        let capacity = EvaContextRouteManifest.includes(.capacity, route: route)
            ? await capacityRecord(tasks: tasks, calendar: calendar.events, now: now)
            : nil

        let envelope = EvaContextEnvelopeBuilder(budget: budget).build(
            compactProjection: compactProjection,
            tasks: tasks,
            summary: projection.summary,
            projects: projection.projects,
            lifeAreas: projection.lifeAreas,
            habits: habitSignals.map(EvaHabitRecord.init(signal:)),
            partialSections: projection.partialSections,
            personalMemory: personalMemory,
            evidence: evidence,
            consent: consent,
            now: now,
            knowledge: knowledge,
            goals: goals,
            calendar: calendar.records,
            calendarSourceIDs: calendar.sourceIDs,
            capacity: capacity,
            dayLoop: EvaContextRouteManifest.includes(.dayLoop, route: route) ? dayLoopRecord(now: now) : nil,
            retrospective: retrospective
        )
        let allowed = EvaContextRouteManifest.categories(for: route)
        var sections = envelope.ordered().filter { allowed.contains($0.category) }
        if let journal {
            sections.removeAll { $0.category == .journal }
            sections.append(journal)
        }
        return EvaEnvelopeAllocator.allocate(sections, budget: budget)
    }

    private static func projectionWithDeadline(
        _ projector: EvaPlanningProjector,
        now: Date
    ) async -> EvaPlanningProjector.Projection? {
        let race = EvaProjectionDeadlineRace()
        return await withCheckedContinuation { continuation in
            Task { await race.resolve(await projector.project(now: now), continuation: continuation) }
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                await race.resolve(nil, continuation: continuation)
            }
        }
    }

    /// Promotes records the question is actually about.
    ///
    /// The v1 projection selected context by substring matching, which misses
    /// "what should I do about the launch" against a task called "draft the
    /// announcement". The embedding index already exists and is already
    /// maintained on every task write — it was simply never used for EVA's
    /// context, only for search ranking.
    ///
    /// This reorders rather than filters. Relevance decides what survives an
    /// overflow, but it must not be able to hide overdue work from a question
    /// that did not happen to mention it.
    @MainActor
    private static func semanticallyPrioritized(
        _ tasks: [EvaTaskRecord],
        query: String
    ) -> [EvaTaskRecord] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let service = TaskSemanticRetrievalService.shared
        guard trimmed.isEmpty == false, service.isActivated else { return tasks }

        let result = service.searchDetailed(
            query: trimmed,
            topK: max(20, tasks.count),
            limitingTo: Set(tasks.map(\.id))
        )
        let semantic = Dictionary(uniqueKeysWithValues: result.hits.map { ($0.taskID, $0.score) })
        guard semantic.isEmpty == false else {
            return tasks.sorted { $0.retentionScore > $1.retentionScore }
        }
        let original = Dictionary(uniqueKeysWithValues: tasks.enumerated().map { ($1.id, $0) })
        return tasks.sorted { lhs, rhs in
            let lhsScore = Double(lhs.retentionScore) + max(0, semantic[lhs.id] ?? 0) * 180
            let rhsScore = Double(rhs.retentionScore) + max(0, semantic[rhs.id] ?? 0) * 180
            if lhsScore != rhsScore { return lhsScore > rhsScore }
            return (original[lhs.id] ?? 0) < (original[rhs.id] ?? 0)
        }
    }

    private static func knowledgeRecords(query: String) async -> [EvaKnowledgeRecord] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false,
              let repository = LLMContextRepositoryFactory.phaseIIRepository else { return [] }

        let stopWords: Set<String> = [
            "a", "about", "and", "did", "do", "for", "from", "i", "in", "is", "me", "my",
            "of", "on", "the", "to", "was", "what", "when", "where", "which", "with"
        ]
        let terms = trimmed.lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count >= 3 && !stopWords.contains($0) }
        guard terms.isEmpty == false else { return [] }

        let notes = (try? await repository.fetchKnowledgeNotes(search: nil, spaceID: nil)) ?? []
        let scored = notes.compactMap { note -> (KnowledgeNoteValue, Double)? in
            guard note.resolvedState == .active,
                  note.resolvedLockPolicy == .unlocked,
                  note.isMeaningful else { return nil }
            let title = note.title.lowercased()
            let body = note.plainText.lowercased()
            let titleMatches = terms.filter(title.contains).count
            let bodyMatches = terms.filter(body.contains).count
            let lexicalScore = Double(titleMatches * 4 + bodyMatches)
            let semanticScore = semanticSimilarity(query: trimmed, text: "\(note.title). \(note.plainText)")
            let required = terms.count == 1 ? 1 : 2
            guard lexicalScore >= Double(required) || semanticScore >= 0.42 else { return nil }
            return (note, lexicalScore + semanticScore * 8)
        }.sorted { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
            return lhs.0.updatedAt > rhs.0.updatedAt
        }

        return scored.prefix(12).map { note, _ in
            EvaKnowledgeRecord(
                id: note.id,
                title: String(note.displayTitle.prefix(200)),
                matchedExcerpt: matchedExcerpt(in: note.plainText, terms: terms),
                modifiedAt: note.updatedAt,
                matchReason: .semanticMatch
            )
        }
    }

    private static func semanticSimilarity(query: String, text: String) -> Double {
        guard let embedding = NLEmbedding.sentenceEmbedding(for: .english),
              let queryVector = embedding.vector(for: String(query.prefix(512))),
              let textVector = embedding.vector(for: String(text.prefix(2_000))),
              queryVector.count == textVector.count else { return 0 }
        let dot = zip(queryVector, textVector).reduce(0.0) { $0 + $1.0 * $1.1 }
        let left = sqrt(queryVector.reduce(0.0) { $0 + $1 * $1 })
        let right = sqrt(textVector.reduce(0.0) { $0 + $1 * $1 })
        guard left > 0, right > 0 else { return 0 }
        return max(-1, min(1, dot / (left * right)))
    }

    private static func journalEvidenceSection(
        query: String,
        consent: EvaConsentPolicy?
    ) async -> EvaCloudContextSection? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false,
              consent?.grants.contains(.journal) == true,
              JournalPrivacyPolicyPersistence.load(from: .standard).permitsJournalEvidenceForEva,
              let repository = LLMContextRepositoryFactory.phaseIIRepository else { return nil }
        let snapshots: @Sendable () async throws -> [JournalEntrySnapshot] = {
            try await repository
                .fetchJournalDays(search: nil, starredOnly: false, mood: nil)
                .map(JournalEntrySnapshot.init(day:))
        }
        let index = SemanticJournalDerivedIndexRepository(snapshotProvider: snapshots)
        let references = (try? await index.search(query: trimmed, limit: 8)) ?? []
        let events = references.map { reference in
            EvaEvidenceEventPayload(
                reference: "J-\(reference.entryID.uuidString.prefix(8).uppercased())",
                domain: "journal",
                kind: "semantic_match",
                occurredAt: reference.date,
                freshness: EventFreshness.complete.rawValue,
                source: String(reference.snippet.prefix(500)),
                value: reference.score
            )
        }
        return EvaContextSectionFactory.evidence(category: .journal, events: events)
    }

    private static func matchedExcerpt(in text: String, terms: [String]) -> String {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.isEmpty == false else { return "No text content." }
        let lower = normalized.lowercased()
        let match = terms.compactMap { lower.range(of: $0)?.lowerBound }.min()
        guard let match else { return String(normalized.prefix(1_200)) }
        let offset = lower.distance(from: lower.startIndex, to: match)
        let startOffset = max(0, offset - 240)
        let start = normalized.index(normalized.startIndex, offsetBy: min(startOffset, normalized.count))
        return String(normalized[start...].prefix(1_200))
    }

    private struct EvaCalendarProjection: Sendable {
        let records: [EvaCalendarRecord]
        let events: [TaskerCalendarEventSnapshot]
        let sourceIDs: [String]
        static let empty = EvaCalendarProjection(records: [], events: [], sourceIDs: [])
    }

    private static func calendarProjection(now: Date) async -> EvaCalendarProjection {
        guard let repository = LLMContextRepositoryFactory.calendarEventsRepository,
              repository.authorizationStatus().isAuthorizedForRead else { return .empty }
        let calendars = await withCheckedContinuation { continuation in
            repository.fetchCalendars { result in
                continuation.resume(returning: (try? result.get()) ?? [])
            }
        }
        guard calendars.isEmpty == false else { return .empty }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 8, to: start) ?? now.addingTimeInterval(691_200)
        let events = await withCheckedContinuation { continuation in
            repository.fetchEvents(
                startDate: start,
                endDate: end,
                calendarIDs: Set(calendars.map(\.id))
            ) { result in
                continuation.resume(returning: (try? result.get()) ?? [])
            }
        }.filter { !$0.isCanceled && !$0.isDeclined }
            .sorted { $0.startDate < $1.startDate }
        return EvaCalendarProjection(
            records: events.prefix(60).map {
                EvaCalendarRecord(
                    title: String($0.title.prefix(200)),
                    start: $0.startDate,
                    end: $0.endDate,
                    isAllDay: $0.isAllDay,
                    isBusy: $0.isBusy
                )
            },
            events: events,
            sourceIDs: events.prefix(60).map(\.id)
        )
    }

    private static func goalRecords(now: Date) async -> [EvaGoalRecord] {
        guard let repository = LLMContextRepositoryFactory.trackFoundationRepository else { return [] }
        let goals = (try? await repository.fetchGoals()) ?? []
        return goals
            .filter { !$0.isArchived }
            .sorted { lhs, rhs in
                (lhs.targetDate ?? .distantFuture) < (rhs.targetDate ?? .distantFuture)
            }
            .prefix(30)
            .map { goal in
                let status = goal.effectiveStatus
                let risk = goal.targetDate.flatMap { target -> String? in
                    guard target < now, status != .completed else { return nil }
                    return "target date has passed"
                }
                return EvaGoalRecord(
                    id: goal.id,
                    title: String(goal.title.prefix(200)),
                    whyItMatters: goal.whyItMatters.map { String($0.prefix(400)) },
                    status: status.rawValue,
                    confidence: goal.confidenceRaw.map { String($0.prefix(40)) },
                    targetDate: goal.targetDate,
                    progressFraction: status == .completed ? 1 : nil,
                    riskReason: risk
                )
            }
    }

    private static func capacityRecord(
        tasks: [EvaTaskRecord],
        calendar events: [TaskerCalendarEventSnapshot],
        now: Date
    ) async -> EvaCapacityRecord? {
        guard let repository = LLMContextRepositoryFactory.internalTimeBlockRepository else { return nil }
        let profiles = (try? await repository.fetchWorkingHoursProfiles()) ?? []
        guard let profile = profiles.first(where: \.isDefault) ?? profiles.first else { return nil }
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: day)
        let intervals = profile.intervalsByWeekday[weekday] ?? []
        guard intervals.isEmpty == false else { return nil }

        let workWindows = intervals.compactMap { interval -> DateInterval? in
            guard let start = calendar.date(byAdding: .minute, value: interval.startMinute, to: day),
                  let end = calendar.date(byAdding: .minute, value: interval.endMinute, to: day),
                  end > start else { return nil }
            return DateInterval(start: start, end: end)
        }
        let busy = events.filter { event in
            event.isBusy && !event.isAllDay && workWindows.contains { window in
                event.endDate > window.start && event.startDate < window.end
            }
        }
        let workingMinutes = workWindows.reduce(0) { $0 + Int($1.duration / 60) }
        let fixedMinutes = busy.reduce(0) { total, event in
            total + workWindows.reduce(0) { overlap, window in
                let start = max(event.startDate, window.start)
                let end = min(event.endDate, window.end)
                return overlap + max(0, Int(end.timeIntervalSince(start) / 60))
            }
        }
        let bufferMinutes = max(0, Int(profile.bufferDuration / 60))
        let usableMinutes = max(0, workingMinutes - fixedMinutes - bufferMinutes)
        let todaysTasks = tasks.filter { $0.bucket == .today || $0.bucket == .overdue }
        let plannedMinutes = todaysTasks.compactMap(\.estimatedMinutes).reduce(0, +)
        let missingEstimates = todaysTasks.filter { $0.estimatedMinutes == nil }.count
        let freeWindows = subtract(busy: busy, from: workWindows).prefix(24).map {
            EvaCapacityRecord.FreeWindow(start: $0.start, end: $0.end, minutes: Int($0.duration / 60))
        }
        return EvaCapacityRecord(
            day: day,
            workingMinutes: workingMinutes,
            fixedCalendarMinutes: fixedMinutes,
            bufferMinutes: bufferMinutes,
            usableMinutes: usableMinutes,
            plannedMinutes: plannedMinutes,
            overloadMinutes: plannedMinutes - usableMinutes,
            confidence: missingEstimates == 0 ? "high" : (missingEstimates <= 2 ? "medium" : "low"),
            freeWindows: Array(freeWindows)
        )
    }

    private static func subtract(
        busy events: [TaskerCalendarEventSnapshot],
        from windows: [DateInterval]
    ) -> [DateInterval] {
        var free = windows
        for event in events {
            var next: [DateInterval] = []
            for window in free {
                let start = max(event.startDate, window.start)
                let end = min(event.endDate, window.end)
                guard end > start else { next.append(window); continue }
                if start > window.start { next.append(DateInterval(start: window.start, end: start)) }
                if end < window.end { next.append(DateInterval(start: end, end: window.end)) }
            }
            free = next
        }
        return free.filter { $0.duration >= 15 * 60 }.sorted { $0.start < $1.start }
    }

    private static func dayLoopRecord(now: Date) -> EvaDayLoopRecord {
        let calendar = Calendar.current
        let stamps = DayLoopClosureLog().closedStamps()
        var run = 0
        for offset in 0 ..< 14 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now),
                  stamps.contains(DayLoopClosureLog.stamp(for: day, calendar: calendar)) else { break }
            run += 1
        }
        return EvaDayLoopRecord(
            eligibleDays: 14,
            closedDays: stamps.count,
            openedDays: 0,
            currentRunLength: run,
            reversals: 0,
            lastClose: nil
        )
    }

    private static func retrospectiveRecord(now: Date) async -> EvaRetrospectiveRecord? {
        guard let repositories = LLMContextRepositoryFactory.weeklyRepositories else { return nil }
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start
            ?? calendar.startOfDay(for: now)
        let plan = await withCheckedContinuation { continuation in
            repositories.0.fetchPlan(forWeekStarting: weekStart) { result in
                continuation.resume(returning: (try? result.get()) ?? nil)
            }
        }
        guard let plan else { return nil }
        async let outcomes = withCheckedContinuation { continuation in
            repositories.1.fetchOutcomes(weeklyPlanID: plan.id) { result in
                continuation.resume(returning: (try? result.get()) ?? [])
            }
        }
        async let review = withCheckedContinuation { continuation in
            repositories.2.fetchReview(weeklyPlanID: plan.id) { result in
                continuation.resume(returning: (try? result.get()) ?? nil)
            }
        }
        let resolvedOutcomes: [WeeklyOutcome] = await outcomes
        let resolvedReview: WeeklyReview? = await review
        return EvaRetrospectiveRecord(
            weekStart: plan.weekStartDate,
            focusStatement: plan.focusStatement.map { String($0.prefix(400)) },
            outcomes: resolvedOutcomes.sorted { $0.orderIndex < $1.orderIndex }.prefix(10).map {
                .init(
                    title: String($0.title.prefix(200)),
                    whyItMatters: $0.whyItMatters.map { String($0.prefix(400)) },
                    successDefinition: $0.successDefinition.map { String($0.prefix(400)) },
                    status: $0.status.rawValue
                )
            },
            wins: resolvedReview?.wins.map { String($0.prefix(1_000)) },
            blockers: resolvedReview?.blockers.map { String($0.prefix(1_000)) },
            lessons: resolvedReview?.lessons.map { String($0.prefix(1_000)) },
            perceivedWeekRating: resolvedReview?.perceivedWeekRating
        )
    }

}

private actor EvaProjectionDeadlineRace {
    private var didResolve = false

    func resolve(
        _ projection: EvaPlanningProjector.Projection?,
        continuation: CheckedContinuation<EvaPlanningProjector.Projection?, Never>
    ) {
        guard didResolve == false else { return }
        didResolve = true
        continuation.resume(returning: projection)
    }
}
