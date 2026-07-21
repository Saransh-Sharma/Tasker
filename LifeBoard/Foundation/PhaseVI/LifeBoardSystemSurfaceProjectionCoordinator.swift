import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Global registration point that ties canonical domain mutations to
/// system-surface refreshes. Stores call `requestRefresh()` after committing;
/// the projector re-publishes redacted envelopes on a short debounce so rapid
/// edits collapse into one write per domain.
public enum LifeBoardSystemSurfaceRefresher {
    private static let state = State()

    private actor State {
        var projector: LifeBoardSystemSurfaceProjectionCoordinator?
        var pending: Task<Void, Never>?
        var journalSubscription: Task<Void, Never>?

        func install(_ coordinator: LifeBoardSystemSurfaceProjectionCoordinator) {
            projector = coordinator
            journalSubscription?.cancel()
            journalSubscription = Task {
                let updates = await JournalProjectionInvalidationHub.shared.updates()
                for await event in updates {
                    guard case .projectionsInvalidated = event else { continue }
                    await LifeBoardSystemSurfaceRefresher.requestRefresh()
                }
            }
        }

        func scheduleRefresh() {
            guard let projector else { return }
            pending?.cancel()
            pending = Task {
                try? await Task.sleep(for: .seconds(1))
                guard Task.isCancelled == false else { return }
                await projector.refresh()
            }
        }
    }

    public static func install(_ coordinator: LifeBoardSystemSurfaceProjectionCoordinator) async {
        await state.install(coordinator)
    }

    public static func requestRefresh() async {
        await state.scheduleRefresh()
    }

    /// Fire-and-forget variant for synchronous mutation sites.
    public static func requestRefreshSoon() {
        Task { await state.scheduleRefresh() }
    }
}

public actor LifeBoardSystemSurfaceProjectionCoordinator {
    private let store: LifeBoardSystemSnapshotStore
    private let phaseII: any LifeBoardPhaseIIRepository
    private let track: any TrackFoundationRepository
    private let wellness: any WellnessRepository
    private let nutrition: any NutritionRepository
    private let moments: any LifeMomentRepository
    private let defaults: UserDefaults

    public init(
        store: LifeBoardSystemSnapshotStore,
        phaseII: any LifeBoardPhaseIIRepository,
        track: any TrackFoundationRepository,
        wellness: any WellnessRepository,
        nutrition: any NutritionRepository,
        moments: any LifeMomentRepository,
        defaults: UserDefaults = .standard
    ) {
        self.store = store; self.phaseII = phaseII; self.track = track; self.wellness = wellness
        self.nutrition = nutrition; self.moments = moments; self.defaults = defaults
    }

    public func refresh(now: Date = Date()) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.refreshJournal(now: now) }
            group.addTask { await self.refreshFasting(now: now) }
            group.addTask { await self.refreshWellness(now: now) }
            group.addTask { await self.refreshNutrition(now: now) }
            group.addTask { await self.refreshMoments(now: now) }
            group.addTask { await self.refreshGoals(now: now) }
            group.addTask { await self.refreshRoutines(now: now) }
        }
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    private func permitted(_ domain: LifeBoardSystemSurfaceDomain) -> Bool {
        defaults.bool(forKey: "lifeOS.systemSurface.\(domain.rawValue).enabled")
    }

    private func write(_ domain: LifeBoardSystemSurfaceDomain, _ snapshots: [LifeBoardSystemSurfaceSnapshot], now: Date) async {
        try? await store.write(.init(domain: domain, generatedAt: now, snapshots: snapshots))
    }

    private func refreshJournal(now: Date) async {
        let latest = try? await phaseII.fetchJournalDays(search: nil, starredOnly: false, mood: nil).first
        let snapshot = LifeBoardSystemSurfaceSnapshot(id: latest?.id ?? UUID(), title: "Journal", primaryValue: latest == nil ? "Capture a moment" : "Recent reflection", secondaryValue: nil, systemImage: "book.closed", sensitivity: .privateSensitive, isExplicitlyAuthorized: permitted(.journal), deepLinkPath: "journal", updatedAt: latest?.updatedAt ?? now)
        await write(.journal, [snapshot], now: now)
    }

    private func refreshFasting(now: Date) async {
        let active = try? await phaseII.fetchFastingSessions(limit: 20).first(where: { $0.endedAt == nil })
        let elapsed = active.map { max(0, now.timeIntervalSince($0.startedAt)) }
        let value = elapsed.map { Self.duration($0) } ?? "No active timer"
        let snapshot = LifeBoardSystemSurfaceSnapshot(id: active?.id ?? UUID(), title: "Fasting", primaryValue: value, secondaryValue: active == nil ? nil : "Timer active", systemImage: "timer", sensitivity: .privateSensitive, isExplicitlyAuthorized: permitted(.fasting), deepLinkPath: "track", updatedAt: active?.updatedAt ?? active?.startedAt ?? now)
        await write(.fasting, [snapshot], now: now)
    }

    private func refreshWellness(now: Date) async {
        let sample = try? await wellness.bodyMetricSamples(kind: .bodyMass).first
        let value = (try? sample?.value(in: sample?.displayUnit ?? .kilograms)).flatMap { $0 }.map { "\($0.formatted(.number.precision(.fractionLength(1)))) \(sample?.displayUnit.symbol ?? "")" } ?? "Open Track"
        let snapshot = LifeBoardSystemSurfaceSnapshot(id: sample?.id ?? UUID(), title: "Wellness", primaryValue: value, secondaryValue: "Private measurement", systemImage: "heart.text.square", sensitivity: .privateSensitive, isExplicitlyAuthorized: permitted(.wellness), deepLinkPath: "track", updatedAt: sample?.updatedAt ?? now)
        await write(.wellness, [snapshot], now: now)
    }

    private func refreshNutrition(now: Date) async {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = .autoupdatingCurrent
        let values = (try? await nutrition.logs(from: calendar.startOfDay(for: now), to: nil)) ?? []
        let total = values.reduce(NutritionMacros.zero) { $0.adding($1.resolvedMacrosSnapshot) }
        let snapshot = LifeBoardSystemSurfaceSnapshot(id: UUID(), title: "Nutrition", primaryValue: values.isEmpty ? "Nothing logged" : "\(Int(total.calories.rounded())) kcal", secondaryValue: values.isEmpty ? nil : "\(values.count) logged items", systemImage: "fork.knife", sensitivity: .privateSensitive, isExplicitlyAuthorized: permitted(.nutrition), deepLinkPath: "track", updatedAt: values.map(\.updatedAt).max() ?? now)
        await write(.nutrition, [snapshot], now: now)
    }

    private func refreshMoments(now: Date) async {
        let candidates = ((try? await moments.moments(includeArchived: false)) ?? []).filter(\.permitsHomeDisplay).compactMap { moment in moment.calendarDaysUntilNextOccurrence(from: now).map { (moment, $0) } }.sorted { $0.1 < $1.1 }
        let next = candidates.first
        let snapshot = LifeBoardSystemSurfaceSnapshot(id: next?.0.id ?? UUID(), title: next?.0.title ?? "Life Moments", primaryValue: next.map { $0.1 == 0 ? "Today" : "\($0.1) days" } ?? "Open LifeBoard", secondaryValue: nil, systemImage: "calendar.badge.heart", sensitivity: .privateStandard, isExplicitlyAuthorized: permitted(.lifeMoments) && next?.0.permitsHomeDisplay == true, deepLinkPath: "insights", updatedAt: next?.0.updatedAt ?? now)
        await write(.lifeMoments, [snapshot], now: now)
    }

    private func refreshGoals(now: Date) async {
        let values = ((try? await track.fetchGoals()) ?? []).filter { !$0.isArchived }
        let snapshot = LifeBoardSystemSurfaceSnapshot(id: UUID(), title: "Goals", primaryValue: values.isEmpty ? "No active goals" : "\(values.count) active", systemImage: "target", sensitivity: .privateStandard, isExplicitlyAuthorized: permitted(.goals), deepLinkPath: "insights", updatedAt: now)
        await write(.goals, [snapshot], now: now)
    }

    private func refreshRoutines(now: Date) async {
        let values = ((try? await track.fetchRoutines()) ?? []).filter { !$0.isArchived }
        let snapshot = LifeBoardSystemSurfaceSnapshot(id: UUID(), title: "Routines", primaryValue: values.isEmpty ? "No routines" : "\(values.count) available", systemImage: "repeat", sensitivity: .privateStandard, isExplicitlyAuthorized: permitted(.routines), deepLinkPath: "track", updatedAt: now)
        await write(.routines, [snapshot], now: now)
    }

    private static func duration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60); return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
}
