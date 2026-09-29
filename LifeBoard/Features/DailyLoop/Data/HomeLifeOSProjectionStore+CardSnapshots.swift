import Foundation

extension HomeLifeOSProjectionStore {
    /// Home renders only these display-ready projections. The provider registry
    /// is deliberately assembled at the domain boundary so card views do not
    /// know which repositories produced the values.
    func makeHomeCardProviderRegistry(at date: Date = HomeReferenceClock.now,
        requestedSizes: [DashboardWidgetKind: Set<HomeCardSize>]? = nil) throws -> HomeCardProviderRegistry {
        let registry = DefaultDashboardWidgetRegistry.shared
        let kinds: [(DashboardWidgetKind, Destination)] = [
            (.setupChecklist, .track),
            (.focusNow, .plan),
            (.tasks, .plan),
            (.scheduleCapacity, .plan),
            (.compactTimeline, .plan),
            (.lifeSnapshot, .track),
            (.care, .track),
            (.routines, .track),
            (.goals, .track),
            (.fasting, .track),
            (.journal, .track),
            (.progressReflection, .insights),
            (.quickCapture, .home),
            (.evaConversation, .eva)
        ]
        var providers: [any HomeCardSource] = kinds.compactMap { kind, destination in
            guard requestedSizes == nil || requestedSizes?[kind] != nil,
                  let definition = registry.descriptor(for: kind) else { return nil }
            let sizes = definition.supportedSizes.filter { requestedSizes?[kind]?.contains($0) ?? true }
            let snapshots = Dictionary(uniqueKeysWithValues: sizes.map { size in
                var snapshot = homeCardSnapshot(kind: kind, size: size, date: date)
                if projectionFailures.contains(kind) {
                    snapshot.availability = .degraded
                    snapshot.detail = String(localized: "Couldn’t refresh. Showing last update.")
                }
                return (size, snapshot)
            })
            let route = homeCardPrimaryRoute(kind: kind)
            return ProjectionHomeCardSource(
                definition: definition,
                destination: destination,
                snapshotBuilder: { size, date in
                    snapshots[size] ?? HomeCardSnapshot(availability: .unavailable, title: String(localized: "Unavailable"), updatedAt: date)
                },
                routeBuilder: { route }
            )
        }
        if let wellnessRepository {
            let focuses: [(DashboardWidgetKind, WellnessHomeCardFocus)] = [
                (.bodyMetric, .bodyMetric(.bodyMass)), (.workout, .workouts), (.sleep, .sleep), (.movement, .movement)
            ]
            providers += focuses.compactMap { kind, focus -> (any HomeCardSource)? in
                guard requestedSizes == nil || requestedSizes?[kind] != nil else { return nil }
                return registry.descriptor(for: kind).map {
                    WellnessHomeCardSource(
                        definition: $0,
                        focus: focus,
                        repository: wellnessRepository,
                        healthMetrics: healthMetrics
                    )
                }
            }
        }
        if let nutritionRepository {
            let focuses: [(DashboardWidgetKind, NutritionHomeCardFocus)] = [
                (.nutritionSummary, .dailySummary), (.recentMeal, .recentMeal), (.logMeal, .logMeal)
            ]
            providers += focuses.compactMap { kind, focus -> (any HomeCardSource)? in
                guard requestedSizes == nil || requestedSizes?[kind] != nil else { return nil }
                return registry.descriptor(for: kind).map {
                    NutritionHomeCardSource(
                        definition: $0,
                        focus: focus,
                        repository: nutritionRepository,
                        healthMetrics: healthMetrics
                    )
                }
            }
        }
        if requestedSizes == nil || requestedSizes?[.lifeMoment] != nil,
           let lifeMomentRepository, let definition = registry.descriptor(for: .lifeMoment) {
            providers.append(LifeMomentsOverviewHomeCardSource(definition: definition, repository: lifeMomentRepository))
        }
        return try HomeCardProviderRegistry(providers: providers)
    }

    private func homeCardSnapshot(
        kind: DashboardWidgetKind,
        size: HomeCardSize,
        date: Date
    ) -> HomeCardSnapshot {
        let title = DefaultDashboardWidgetRegistry.shared.descriptor(for: kind)?.title ?? "Home"
        switch kind {
        case .focusNow:
            guard let focusTask else { return emptySnapshot(title, String(localized: "Nothing next"), date) }
            return densitySnapshot(
                title: title,
                value: focusTask.title,
                compactDetail: focusResult?.reasons.first?.text ?? String(localized: "Up next"),
                storyDetail: String(localized: "Fits your free time"),
                size: size,
                date: date
            )
        case .tasks:
            guard let planSnapshot else { return unavailableSnapshot(title, date) }
            let planned = planSnapshot.plannedTasks
            let unscheduled = planSnapshot.unscheduledTasks
            let count = planned.count + unscheduled.count
            guard count > 0 else {
                return emptySnapshot(title, String(localized: "Nothing planned"), date)
            }
            // Planned work first, then flexible; overdue rises above both.
            let rows = (planned + unscheduled).map { task in
                HomeQueueItem(
                    id: task.id.uuidString,
                    title: task.title,
                    supporting: task.dueDate.map {
                        String(localized: "Due \($0.formatted(date: .abbreviated, time: .omitted))")
                    },
                    state: Self.queueState(for: task, at: date)
                )
            }
            .sorted { lhs, rhs -> Bool in
                let lhsRank = lhs.state == .overdue ? 0 : 1
                let rhsRank = rhs.state == .overdue ? 0 : 1
                return lhsRank < rhsRank
            }
            return densitySnapshot(
                title: title,
                value: "\(count)",
                compactDetail: count == 1 ? String(localized: "task") : String(localized: "tasks"),
                storyDetail: String(localized: "\(planned.count) planned · \(unscheduled.count) unscheduled"),
                size: size,
                date: date,
                payload: .queue(rows)
            )
        case .scheduleCapacity, .compactTimeline:
            guard let planSnapshot else { return unavailableSnapshot(title, date) }
            let count = planSnapshot.commitments.count
            // The spine reads as the day's shape: what is fixed, in order.
            let spine = planSnapshot.commitments
                .sorted { $0.startAt < $1.startAt }
                .map { commitment in
                    HomeQueueItem(
                        id: commitment.id,
                        title: commitment.title,
                        supporting: commitment.startAt.formatted(date: .omitted, time: .shortened),
                        state: commitment.endAt < date ? .done : .pending,
                        systemImage: "circle.fill"
                    )
                }
            return densitySnapshot(
                title: title,
                value: "\(count)",
                compactDetail: count == 1 ? String(localized: "event") : String(localized: "events"),
                storyDetail: planSnapshot.freeWindows.isEmpty
                    ? String(localized: "No free time")
                    : String(localized: "Free time left"),
                size: size,
                date: date,
                payload: .queue(spine)
            )
        case .lifeSnapshot:
            guard let latestMood else { return emptySnapshot(title, String(localized: "No check-in yet"), date) }
            return densitySnapshot(
                title: title,
                value: latestMood.mood.title,
                compactDetail: latestMood.energy.map { String(localized: "Energy \($0)/5") } ?? String(localized: "Mood checked in"),
                storyDetail: String(localized: "Last check-in"),
                size: size,
                date: date
            )
        case .care:
            guard let trackSnapshot else { return unavailableSnapshot(title, date) }
            let pending = trackSnapshot.unresolvedMedicationEvents.filter { $0.status == .unresolved }
            guard pending.isEmpty == false else {
                return emptySnapshot(title, String(localized: "No doses to log"), date)
            }
            // The event carries only a medication ID; the store reads names
            // alongside the snapshot. Without one the row leads with its time.
            let rows = pending.map { event in
                let time = event.scheduledAt.formatted(date: .omitted, time: .shortened)
                let name = medicationNames[event.medicationID]
                return HomeQueueItem(
                    id: event.id.uuidString,
                    title: name.map { "\($0) · \(time)" } ?? time,
                    supporting: event.note,
                    state: event.scheduledAt < date ? .overdue : .pending,
                    systemImage: "cross.case"
                )
            }
            return densitySnapshot(
                title: title,
                value: "\(pending.count)",
                compactDetail: pending.count == 1 ? String(localized: "dose to log") : String(localized: "doses to log"),
                storyDetail: String(localized: "Log each dose when taken."),
                size: size,
                date: date,
                payload: .queue(rows)
            )
        case .routines:
            guard let trackSnapshot else { return unavailableSnapshot(title, date) }
            let due = trackSnapshot.dueRoutines
            guard due.isEmpty == false else {
                return emptySnapshot(title, String(localized: "Nothing due"), date)
            }
            let rows = due.map { routine in
                HomeQueueItem(
                    id: routine.id.uuidString,
                    title: routine.title,
                    supporting: routine.steps.isEmpty ? nil : (routine.steps.count == 1 ? String(localized: "1 step") : String(localized: "\(routine.steps.count) steps")),
                    state: .pending,
                    systemImage: "repeat"
                )
            }
            return densitySnapshot(
                title: title,
                value: "\(due.count)",
                compactDetail: due.count == 1 ? String(localized: "routine ready") : String(localized: "routines ready"),
                storyDetail: String(localized: "Ready to start"),
                size: size,
                date: date,
                payload: .queue(rows)
            )
        case .goals:
            guard let trackSnapshot else { return unavailableSnapshot(title, date) }
            let goals = trackSnapshot.goals
            guard goals.isEmpty == false else {
                return emptySnapshot(title, String(localized: "No goals yet"), date)
            }
            // Lead with the goal nearest completion rather than an arbitrary
            // first row, so the ring reads as momentum.
            let ranked = goals.max { Self.goalFraction($0) < Self.goalFraction($1) }
            let fraction = ranked.map(Self.goalFraction) ?? 0
            let percent = Int((fraction * 100).rounded())
            return densitySnapshot(
                title: title,
                value: "\(goals.count)",
                compactDetail: goals.count == 1 ? String(localized: "goal") : String(localized: "goals"),
                storyDetail: ranked?.nextUsefulAction ?? String(localized: "Open Track for progress"),
                size: size,
                date: date,
                payload: .progress(fraction: fraction, label: "\(percent)%")
            )
        case .fasting:
            guard let activeFast else { return emptySnapshot(title, String(localized: "No fast running"), date) }
            let elapsed = max(0, activeFast.elapsed(at: date))
            let hours = Int(elapsed) / 3_600
            let minutes = (Int(elapsed) % 3_600) / 60
            let fraction = activeFast.targetDuration.map { target in
                target > 0 ? min(1, elapsed / target) : 0
            } ?? 0
            return densitySnapshot(
                title: title,
                value: String(format: "%d:%02d", hours, minutes),
                compactDetail: activeFast.targetDuration.map { String(localized: "Goal \(LifeBoardDuration.text(seconds: $0))") } ?? String(localized: "Running"),
                storyDetail: String(localized: "Started \(activeFast.startedAt.formatted(date: .omitted, time: .shortened))"),
                size: size,
                date: date,
                payload: .progress(
                    fraction: fraction,
                    label: String(format: "%d:%02d", hours, minutes)
                )
            )
        case .journal:
            // Previously hard-coded to `.degraded` with no way to grant consent,
            // so this card could never become useful. It now reflects a real
            // setting the user can turn on in Journal privacy.
            guard JournalHomeConsentStore.isGranted else {
                return HomeCardSnapshot(
                    availability: .degraded,
                    title: title,
                    value: size == .compact ? nil : String(localized: "Show journal here?"),
                    detail: String(localized: "Turn on in Journal privacy."),
                    updatedAt: date
                )
            }
            return densitySnapshot(
                title: title,
                value: String(localized: "Open"),
                compactDetail: String(localized: "Today’s entry"),
                storyDetail: String(localized: "Write about today"),
                size: size,
                date: date
            )
        case .progressReflection:
            guard let planSnapshot, let trackSnapshot else { return unavailableSnapshot(title, date) }
            let planned = planSnapshot.plannedTasks.count
            let goals = trackSnapshot.goals.count
            return densitySnapshot(
                title: title,
                value: planned == 0 ? String(localized: "Nothing planned") : String(localized: "\(planned) planned"),
                compactDetail: goals == 0 ? String(localized: "Look back on today") : (goals == 1 ? String(localized: "1 goal") : String(localized: "\(goals) goals")),
                storyDetail: String(localized: "Review today"),
                size: size,
                date: date
            )
        case .quickCapture:
            return densitySnapshot(
                title: title,
                value: String(localized: "Capture"),
                compactDetail: String(localized: "Task, note, or check-in"),
                storyDetail: String(localized: "You review before it saves."),
                size: size,
                date: date
            )
        case .evaConversation:
            return emptySnapshot(title, String(localized: "Saved Eva replies show here."), date)
        case .setupChecklist:
            let outstanding = outstandingSetupItems()
            guard let first = outstanding.first else {
                // Nothing left to offer: the card reports empty and the Home
                // canvas drops it rather than leaving a permanent placeholder.
                return emptySnapshot(title, String(localized: "All set up"), date)
            }
            return densitySnapshot(
                title: title,
                value: first,
                compactDetail: outstanding.count == 1 ? String(localized: "1 optional step") : String(localized: "\(outstanding.count) optional steps"),
                storyDetail: outstanding.prefix(3).joined(separator: " \u{00B7} "),
                size: size,
                date: date
            )
        default:
            return unavailableSnapshot(title, date)
        }
    }
}

extension HomeLifeOSProjectionStore {
    private func homeCardPrimaryRoute(kind: DashboardWidgetKind) -> AppRoute? {
        guard kind == .goals,
              let ranked = trackSnapshot?.goals.max(by: {
                  Self.goalFraction($0) < Self.goalFraction($1)
              }) else { return nil }
        return .goal(ranked.goalID)
    }

    /// What the user still has not set up, in the order worth offering it.
    ///
    /// Onboarding deliberately does not ask for everything; this is where the
    /// remainder lives so the flow can stay short. Each row disappears as soon as
    /// it is satisfied, and the card removes itself when the list empties.
    private func outstandingSetupItems() -> [String] {
        var items: [String] = []

        if PermissionPromptState.hasRequested(.notifications) == false {
            items.append(String(localized: "Turn on reminders"))
        }
        if PermissionKind.appleHealth.isSupportedOnThisDevice,
           PermissionPromptState.hasRequested(.appleHealth) == false {
            items.append(String(localized: "Connect Apple Health"))
        }
        if PermissionPromptState.hasRequested(.calendar) == false {
            items.append(String(localized: "Connect your calendar"))
        }
        if let trackSnapshot {
            if trackSnapshot.hydrationTargetMilliliters == nil {
                items.append(String(localized: "Set a water goal"))
            }
            if trackSnapshot.dueRoutines.isEmpty, trackSnapshot.goals.isEmpty {
                items.append(String(localized: "Add a routine"))
            }
        }
        if V2FeatureFlags.journalV1Enabled, JournalHomeConsentStore.isGranted == false {
            items.append(String(localized: "Show journal on Home"))
        }
        return items
    }

    private func densitySnapshot(
        title: String,
        value: String,
        compactDetail: String,
        storyDetail: String,
        size: HomeCardSize,
        date: Date,
        payload: HomeCardPayload = .none
    ) -> HomeCardSnapshot {
        let detail: String?
        switch size {
        case .compact: detail = nil
        case .standard, .wide: detail = compactDetail
        case .tall, .expanded: detail = storyDetail
        }
        return HomeCardSnapshot(
            availability: .ready,
            title: title,
            value: value,
            detail: detail,
            payload: payload,
            updatedAt: date
        )
    }

    private func emptySnapshot(
        _ title: String,
        _ detail: String,
        _ date: Date,
        payload: HomeCardPayload = .none
    ) -> HomeCardSnapshot {
        HomeCardSnapshot(
            availability: .empty,
            title: title,
            detail: detail,
            payload: payload,
            updatedAt: date
        )
    }

    /// Overdue is the only state worth surfacing distinctly on Home — the rest
    /// is noise at glance size.
    private static func queueState(
        for task: PlanningTaskSummary,
        at date: Date
    ) -> HomeQueueItem.State {
        if let due = task.dueDate, due < date { return .overdue }
        switch task.metadata.availability {
        case .waiting, .paused: return .skipped
        case .actionable: return .pending
        }
    }

    private static func goalFraction(_ goal: GoalProgressSnapshot) -> Double {
        if let fraction = goal.progressFraction { return max(0, min(1, fraction)) }
        guard let current = goal.currentValue, let target = goal.targetValue, target > 0 else { return 0 }
        return max(0, min(1, current / target))
    }

    private func unavailableSnapshot(_ title: String, _ date: Date) -> HomeCardSnapshot {
        HomeCardSnapshot(
            availability: .unavailable,
            title: title,
            detail: String(localized: "Unavailable"),
            updatedAt: date
        )
    }
}

private struct ProjectionHomeCardSource: HomeCardSource {
    let definition: HomeCardDefinition
    let primaryDestination: Destination
    let privacyClassification: DataSensitivity
    private let snapshotBuilder: @MainActor @Sendable (HomeCardSize, Date) -> HomeCardSnapshot
    private let routeBuilder: @MainActor @Sendable () -> AppRoute?

    init(
        definition: HomeCardDefinition,
        destination: Destination,
        snapshotBuilder: @escaping @MainActor @Sendable (HomeCardSize, Date) -> HomeCardSnapshot,
        routeBuilder: @escaping @MainActor @Sendable () -> AppRoute? = { nil }
    ) {
        self.definition = definition
        primaryDestination = destination
        privacyClassification = definition.sensitivity
        self.snapshotBuilder = snapshotBuilder
        self.routeBuilder = routeBuilder
    }

    func snapshot(
        configuration: HomeCardConfiguration,
        size: HomeCardSize,
        at date: Date
    ) async -> HomeCardSnapshot {
        await snapshotBuilder(size, date)
    }

    func resolution(context: HomeCardSnapshotContext) async -> HomeCardResolution {
        let resolvedSnapshot = await snapshot(context: context)
        let route = await routeBuilder()
        let actionTitle: String
        if definition.kind == .goals {
            actionTitle = route == nil ? "View goals" : "View goal"
        } else {
            actionTitle = resolvedSnapshot.actions.first?.title ?? "Open"
        }
        return HomeCardResolution(
            snapshot: resolvedSnapshot,
            primaryRoute: route,
            primaryActionTitle: actionTitle
        )
    }
}
