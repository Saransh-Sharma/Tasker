import Foundation

struct HomeProjectionCandidate: Equatable, Sendable {
    let plan: PlanDaySnapshot?
    let track: TrackTodaySnapshot?
    let mood: MoodEnergyCheckInValue?
    let fast: FastingSessionValue?
    let endedFast: FastingSessionValue?
    let meal: Date?
    let focus: FocusSessionV2?
}

struct HomeCoreProjectionInputs: Sendable {
    let tasks: [PlanningTaskSummary]
    let focus: FocusSessionV2?
    var sourceRevisions: SourceRevisionVector? = nil
}

struct HomeProjectionInputs: Sendable {
    var plan: PlanDaySnapshot?
    var tasks: [PlanningTaskSummary]?
    var repairs: [PlanRepairProposal]?
    var focus: FocusSessionV2?
    var track: TrackTodaySnapshot?
    var mood: MoodEnergyCheckInValue?
    var planFailed = false
    var trackFailed = false
    /// Medication names by ID, so Home's care card can say which medicine a
    /// decision is about. Empty when they could not be read.
    var medicationNames: [UUID: String] = [:]
    var sourceRevisions: SourceRevisionVector? = nil
    var trackSourceRevisions: SourceRevisionVector? = nil
    var moodSourceRevisions: SourceRevisionVector? = nil
}

struct HomeHydrationProjectionInputs: Sendable {
    let day: Date
    let amount: Double?
    let target: Double?
    let revisions: SourceRevisionVector
}

struct HomeMoodProjectionInputs: Sendable {
    let value: MoodEnergyCheckInValue?
    let revisions: SourceRevisionVector?
}

/// Reads only what Home displays; no screen stores, writes or Live Activity updates.
actor HomeProjectionReader {
    let planning: CoreDataPlanningRepository?
    let track: CoreDataTrackFoundationRepository?
    let phaseII: (any PhaseIIRepository)?
    let goalSamples: (any GoalSampleRepository)?
    private let calendarRepository: any PlanningCalendarContextRepository
    private var cachedCalendar: (start: Date, end: Date, context: PlanningCalendarContext)?

    init(planning: CoreDataPlanningRepository?, track: CoreDataTrackFoundationRepository?,
         phaseII: (any PhaseIIRepository)?, goalSamples: (any GoalSampleRepository)?,
         calendarRepository: any PlanningCalendarContextRepository = SystemPlanningCalendarContextRepository()) {
        self.planning = planning; self.track = track; self.phaseII = phaseII; self.goalSamples = goalSamples
        self.calendarRepository = calendarRepository
    }

    func readCore() async throws -> HomeCoreProjectionInputs {
        guard let planning else {
            return .init(tasks: [], focus: nil)
        }
        let revisions = planning.sourceRevisions.snapshot()
        async let tasks = planning.fetchOpenPlanningTasks()
        async let focus = planning.activeSession()
        return try await .init(tasks: tasks, focus: focus, sourceRevisions: revisions)
    }

    func read(now: Date,
              onCore: @escaping @MainActor @Sendable (HomeCoreProjectionInputs) -> Void = { _ in },
              onPlan: @escaping @MainActor @Sendable (HomeProjectionInputs) -> Void = { _ in },
              onTrack: @escaping @MainActor @Sendable (HomeProjectionInputs) -> Void = { _ in }) async -> HomeProjectionInputs {
        async let plan = readPlan(now: now, onCore: onCore, onPlan: onPlan)
        async let track = readTrackAndPublish(now: now, onTrack: onTrack)
        let (planValues, trackValues) = await (plan, track)
        var result = planValues
        result.track = trackValues.track
        result.mood = trackValues.mood
        result.trackFailed = trackValues.trackFailed
        result.medicationNames = trackValues.medicationNames
        return result
    }

    private func readTrackAndPublish(now: Date,
        onTrack: @escaping @MainActor @Sendable (HomeProjectionInputs) -> Void) async -> HomeProjectionInputs {
        let result = await readTrack(now: now)
        guard !Task.isCancelled else { return .init() }
        await onTrack(result)
        return result
    }

    private func readPlan(now: Date,
                          onCore: @escaping @MainActor @Sendable (HomeCoreProjectionInputs) -> Void,
                          onPlan: @escaping @MainActor @Sendable (HomeProjectionInputs) -> Void) async -> HomeProjectionInputs {
        guard let planning else { return .init() }
        let sourceRevisions = planning.sourceRevisions.snapshot()
        let calendar = Calendar.current
        let day = PlanningDay(date: now, timeZone: calendar.timeZone, calendar: calendar)
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
        do {
            async let tasksValue = planning.fetchOpenPlanningTasks()
            async let blocksValue = planning.fetchTimeBlocks(from: start, to: end)
            async let profilesValue = planning.fetchWorkingHoursProfiles()
            async let calendarValue = readCalendar(from: start, to: end)
            async let focusValue = planning.activeSession()
            let (tasks, focus) = try await (tasksValue, focusValue)
            guard !Task.isCancelled else { return .init() }
            await onCore(.init(tasks: tasks, focus: focus, sourceRevisions: sourceRevisions))
            let (blocks, profiles, context) = try await (blocksValue, profilesValue, calendarValue)
            let profile = profiles.first(where: \.isDefault) ?? profiles.first ?? PlanStore.defaultWorkingProfile()
            let snapshot = PlanDayProjectionInputs(tasks: tasks, allBlocks: blocks, workingProfile: profile,
                calendarContext: context.0, calendarState: context.1, calendar: calendar, now: now)
                .snapshot(for: day)
            let proposals = DeterministicPlanRepairService().proposals(for: snapshot, now: now)
            let applied = try await planning.appliedReceiptSources(in: Set(proposals.map { "plan.repair.\($0.id.uuidString)" }))
            let result = HomeProjectionInputs(plan: snapshot, tasks: tasks,
                repairs: proposals.filter { !applied.contains("plan.repair.\($0.id.uuidString)") }, focus: focus, sourceRevisions: sourceRevisions)
            guard !Task.isCancelled else { return .init() }
            await onPlan(result)
            return result
        } catch { return .init(planFailed: true) }
    }

    private func readCalendar(from start: Date, to end: Date) async -> (PlanningCalendarContext, PlanningCalendarState) {
        let authorization = await calendarRepository.authorization()
        guard authorization == .authorized else {
            cachedCalendar = nil
            let state: PlanningCalendarState = switch authorization {
            case .notDetermined: .notRequested
            case .denied, .restricted: .denied
            default: .failed(message: String(localized: "Couldn’t load calendar."))
            }
            return (.init(authorization: authorization), state)
        }
        do {
            let context = try await calendarRepository.fetchCommitments(from: start, to: end)
            cachedCalendar = (start, end, context)
            return (context, .fresh(fetchedAt: context.fetchedAt))
        } catch {
            if let cached = cachedCalendar, cached.start == start, cached.end == end {
                return (cached.context, .staleCached(fetchedAt: cached.context.fetchedAt,
                    message: error.localizedDescription))
            }
            return (.init(authorization: authorization), .failed(message: error.localizedDescription))
        }
    }

    func readHydration(now: Date) async throws -> HomeHydrationProjectionInputs {
        guard let track else { throw CocoaError(.featureUnsupported) }
        let revisions = track.sourceRevisions.snapshot()
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
        async let logsValue = track.fetchHydrationLogs(from: start, to: end)
        async let targetValue = track.fetchHydrationTarget()
        let (logs, target) = try await (logsValue, targetValue)
        let amount = logs.reduce(0) { $0 + HydrationMeasurementService.convert($1.amount, from: $1.unit, to: .milliliters) }
        return .init(day: start, amount: logs.isEmpty && target == nil ? nil : amount,
                     target: target.map { HydrationMeasurementService.convert($0.amount, from: $0.unit, to: .milliliters) },
                     revisions: revisions)
    }

    func readMood(now: Date) async throws -> HomeMoodProjectionInputs {
        guard let phaseII else { throw CocoaError(.featureUnsupported) }
        let revisions = (phaseII as? CoreDataLifeBoardPhaseIIRepository)?.sourceRevisions.snapshot()
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
        let values = try await phaseII.fetchMoodCheckIns(from: calendar.date(byAdding: .day, value: -29, to: start), to: end)
        return .init(value: values.first, revisions: revisions)
    }

    private func readTrack(now: Date) async -> HomeProjectionInputs {
        guard let track, let phaseII else { return .init() }
        let trackRevisions = track.sourceRevisions.snapshot()
        let moodRevisions = (phaseII as? CoreDataLifeBoardPhaseIIRepository)?.sourceRevisions.snapshot()
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
        do {
            async let goalsValue = track.fetchGoals()
            async let linksValue = track.fetchGoalLinks(goalID: nil)
            async let routinesValue = track.fetchRoutines()
            async let schedulesValue = track.fetchRoutineSchedules(routineID: nil)
            async let hydrationValue = track.fetchHydrationLogs(from: start, to: end)
            async let targetValue = track.fetchHydrationTarget()
            async let eventsValue = phaseII.fetchMedicationEvents(from: start, to: end)
            async let moodValue = phaseII.fetchMoodCheckIns(from: calendar.date(byAdding: .day, value: -29, to: start), to: end)
            let (goals, links, routines, schedules, hydration, target, events, moods) = try await
                (goalsValue, linksValue, routinesValue, schedulesValue, hydrationValue, targetValue, eventsValue, moodValue)
            let samples = try await goalSamples?.samples(for: links, asOf: now) ?? []
            let linksByGoal = Dictionary(grouping: links, by: \.goalID)
            let progress = goals.map { DefaultGoalProgressService().progress(for: $0, links: linksByGoal[$0.id] ?? [], samples: samples) }
            let due = TrackFoundationStore.dueRoutines(routines: routines, schedules: schedules, at: now, calendar: calendar)
            let amount = hydration.reduce(0) { $0 + HydrationMeasurementService.convert($1.amount, from: $1.unit, to: .milliliters) }
            let snapshot = TrackTodaySnapshot(unresolvedMedicationEvents: events.filter { $0.status == .unresolved || $0.status == .scheduled },
                habitGrades: [], dueRoutines: due, goals: progress,
                hydrationAmountMilliliters: hydration.isEmpty && target == nil ? nil : amount,
                hydrationTargetMilliliters: target.map { HydrationMeasurementService.convert($0.amount, from: $0.unit, to: .milliliters) },
                completeness: .complete, generatedAt: now)
            // Names only label the care card; a failed read leaves them out
            // rather than failing the whole track projection.
            let medications = (try? await phaseII.fetchMedications()) ?? []
            var result = HomeProjectionInputs(track: snapshot, mood: moods.first, trackSourceRevisions: trackRevisions, moodSourceRevisions: moodRevisions)
            result.medicationNames = Dictionary(medications.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
            return result
        } catch { return .init(trackFailed: true) }
    }
}
