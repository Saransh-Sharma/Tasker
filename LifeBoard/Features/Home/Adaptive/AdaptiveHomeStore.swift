import Combine
import Observation
import SwiftUI
import LifeBoardDomain

struct AdaptiveTimelineItem: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
}

struct AdaptiveHomeProjectionSnapshot: Equatable, Sendable {
    var selectedDate = HomeReferenceClock.now
    var focusTitles: [String] = []
    var overdueCount = 0
    var openTaskCount = 0
    var currentHabits: [String] = []
    var recoveryHabits: [String] = []
    var completionRate = 0.0
    var dailyScore = 0
    var streakDays = 0
    var timelineItems: [AdaptiveTimelineItem] = []
    var nextMeetingTitle: String?
    var freeUntil: Date?
    var calendarNeedsSetup = true
}

/// App-level composition for the canonical Home projection.
///
/// The coordinator owns the stores that Adaptive Home reads and applies the
/// view model's slice transaction directly. No view controller has to load or
/// render before Home can receive its first projection.
@MainActor
@Observable
final class HomeProjectionCoordinator {
    private(set) var snapshot = AdaptiveHomeProjectionSnapshot()

    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []

    #if DEBUG
    init(designSnapshot: AdaptiveHomeProjectionSnapshot) {
        snapshot = designSnapshot
    }
    #endif

    init(homeViewModel: HomeViewModel) {
        homeViewModel.$homeRenderTransaction
            .removeDuplicates()
            .sink { [weak self] transaction in self?.apply(transaction) }
            .store(in: &cancellables)
        apply(homeViewModel.homeRenderTransaction)
    }

    private func apply(_ transaction: HomeRenderTransaction) {
        let nextSnapshot = Self.project(transaction)
        guard nextSnapshot != snapshot else { return }
        snapshot = nextSnapshot
    }

    static func project(_ transaction: HomeRenderTransaction) -> AdaptiveHomeProjectionSnapshot {
        let chrome = transaction.chrome
        let tasks = transaction.tasks
        let habits = transaction.habits
        let calendar = transaction.calendar
        let nextSnapshot = AdaptiveHomeProjectionSnapshot(
            selectedDate: chrome.selectedDate,
            focusTitles: tasks.focusNowSectionState.rows.prefix(3).map(\.title),
            overdueCount: tasks.overdueTasks.lazy.filter { !$0.isComplete }.count,
            openTaskCount: tasks.todayOpenTaskCount,
            currentHabits: habits.habitHomeSectionState.primaryRows.prefix(5).map(\.title),
            recoveryHabits: habits.habitHomeSectionState.recoveryRows.prefix(3).map(\.title),
            completionRate: chrome.completionRate,
            dailyScore: chrome.dailyScore,
            streakDays: chrome.progressState.streakDays,
            timelineItems: calendar.selectedDayTimelineEvents.prefix(3).map {
                AdaptiveTimelineItem(id: $0.id, title: $0.title, startDate: $0.startDate, endDate: $0.endDate)
            },
            nextMeetingTitle: calendar.nextMeeting?.event.title,
            freeUntil: calendar.freeUntil,
            calendarNeedsSetup: calendar.moduleState == .permissionRequired || calendar.moduleState == .noCalendarsSelected
        )
        return nextSnapshot
    }
}

@MainActor
@Observable
final class AdaptiveHomeStore {
    private(set) var layout: DashboardLayoutValue
    private(set) var draft: HomeLayoutDraft?
    private(set) var contextSelection = HomeContextSelection(candidates: [], evaluatedAt: .distantPast)
    private(set) var lastLayoutTransaction: HomeLayoutTransaction?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    var showsGallery = false

    @ObservationIgnored private let repository: (any DashboardLayoutRepository)?
    @ObservationIgnored private var contextCandidates: [HomeContextCandidate] = []
    @ObservationIgnored private var permitsSensitiveContext = false
    @ObservationIgnored private let contextEngine: HomeContextService
    @ObservationIgnored private let contextPreferences: HomeContextPreferenceStore
    @ObservationIgnored let registry: DashboardWidgetRegistry

    init(
        repository: (any DashboardLayoutRepository)?,
        registry: DashboardWidgetRegistry = DefaultDashboardWidgetRegistry.shared,
        contextPolicy: any HomeContextPolicy = DeterministicHomeContextPolicy(),
        contextPreferences: HomeContextPreferenceStore = .init()
    ) {
        self.repository = repository
        self.registry = registry
        contextEngine = HomeContextService(policy: contextPolicy)
        self.contextPreferences = contextPreferences
        layout = DashboardLayoutValue(
            mode: .smart,
            isDefault: true,
            placements: CoreDataDashboardLayoutRepository.curatedHomePlacements()
        )
    }

    var activeLayout: DashboardLayoutValue { draft?.current ?? layout }
    var isCustomizing: Bool { draft != nil }

    func load() async {
        guard isLoading == false else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            if let stored = try await repository?.fetchHome() {
                layout = stored
            } else if let repository {
                layout = try await repository.resetHomeToCuratedDefault()
            }
            #if DEBUG
            if HomeProductionEvidenceProfile.enabled {
                layout = HomeProductionEvidenceProfile.layout
                try await repository?.saveHome(layout)
            }
            #endif
            seedUITestUserSpaceIfNeeded()
        } catch {
            errorMessage = String(localized: "Couldn’t load your layout. Showing the default.")
        }
    }

    private func seedUITestUserSpaceIfNeeded() {
        guard ProcessInfo.processInfo.arguments.contains("-LIFEBOARD_TEST_SEED_HOME_USER_SPACE"),
              layout.placements.contains(where: { $0.sectionOverride == .userSpace }) == false else {
            return
        }
        let testPlacementID = UUID(uuidString: "D6ED45B2-1267-4C2C-9A91-A3F5503D51AF")!
        var placement = DashboardWidgetPlacementValue(
            id: testPlacementID,
            widgetKind: DashboardWidgetKind.lifeMoment.rawValue,
            semanticSize: .standard,
            ordinal: layout.placements.count
        )
        placement.updateHomeConfiguration { configuration in
            configuration.placement.ownership = .pinned
            configuration.placement.sectionOverride = .userSpace
            configuration.placement.smartSlot = nil
        }
        layout.placements = HomeGridPackingService.normalized(layout.placements + [placement])
    }

    func beginCustomization() {
        guard draft == nil else { return }
        contextEngine.setFrozen(true, reason: "home-edit")
        draft = HomeLayoutDraft(layout: layout)
    }

    func cancelCustomization() {
        draft = nil
        contextEngine.setFrozen(false, reason: "home-edit")
    }

    func saveCustomization() async {
        guard let committed = try? draft?.committedLayout() else { return }
        let transaction = HomeLayoutTransaction(before: layout, after: committed)
        layout = committed
        draft = nil
        contextEngine.setFrozen(false, reason: "home-edit")
        do {
            try await repository?.saveHome(committed)
            lastLayoutTransaction = transaction
        } catch {
            errorMessage = String(localized: "Couldn’t save your layout.")
        }
    }

    func undoLastLayoutTransaction() async {
        guard let transaction = lastLayoutTransaction else { return }
        layout = transaction.undoLayout
        lastLayoutTransaction = nil
        do {
            try await repository?.saveHome(transaction.undoLayout)
        } catch {
            errorMessage = String(localized: "Couldn’t save the restored layout.")
        }
    }

    func movePlacement(id: UUID, offset: Int) {
        guard var value = draft else { return }
        let placements = value.current.placements.sorted { $0.ordinal < $1.ordinal }
        guard let source = placements.firstIndex(where: { $0.id == id }) else { return }
        let target = min(max(0, source + offset), placements.count - 1)
        guard source != target else { return }
        value.move(fromOffsets: IndexSet(integer: source), toOffset: target > source ? target + 1 : target)
        value.setOwnership(.pinned, id: id)
        draft = value
    }

    func movePlacement(id: UUID, before targetID: UUID) {
        guard var value = draft else { return }
        let placements = value.current.placements.sorted { $0.ordinal < $1.ordinal }
        guard let source = placements.firstIndex(where: { $0.id == id }),
              let target = placements.firstIndex(where: { $0.id == targetID }),
              source != target else { return }
        value.move(fromOffsets: IndexSet(integer: source), toOffset: target > source ? target + 1 : target)
        value.setOwnership(.pinned, id: id)
        draft = value
    }

    func resizePlacement(id: UUID, to size: WidgetSizePreset) {
        guard var value = draft else { return }
        value.resize(id: id, to: size, registry: registry)
        value.setOwnership(.pinned, id: id)
        draft = value
    }

    func cycleSize(id: UUID, expanding: Bool) {
        guard let placement = draft?.current.placements.first(where: { $0.id == id }),
              let descriptor = registry.descriptor(for: DashboardWidgetKind(rawValue: placement.widgetKind)) else { return }
        let choices = WidgetSizePreset.allCases.filter(descriptor.supportedSizes.contains)
        guard let index = choices.firstIndex(of: placement.semanticSize), choices.count > 1 else { return }
        let next = expanding ? min(index + 1, choices.count - 1) : max(index - 1, 0)
        guard next != index else { return }
        resizePlacement(id: id, to: choices[next])
        Haptic.pick.play()
    }

    /// Cards leaving the board erode away rather than vanishing between
    /// frames, so it reads as the card being put down rather than lost.
    private(set) var dissolvingPlacementID: UUID?

    func hidePlacement(id: UUID) {
        guard var value = draft else { return }
        dissolvingPlacementID = id
        value.setVisible(false, id: id)
        draft = value
    }

    func finishDissolve(id: UUID) {
        guard dissolvingPlacementID == id else { return }
        dissolvingPlacementID = nil
    }

    func toggleSmartSlot(id: UUID) {
        guard var value = draft,
              let placement = value.current.placements.first(where: { $0.id == id }) else { return }
        let nextOwnership: HomeCardOwnership = placement.ownership == .smart ? .pinned : .smart
        value.setOwnership(nextOwnership, id: id)
        draft = value
    }

    func updateSmartSlot(
        id: UUID,
        _ update: (inout HomeSmartSlotConfiguration) -> Void
    ) {
        guard var value = draft,
              let placement = value.current.placements.first(where: { $0.id == id }),
              placement.ownership == .smart else { return }
        var configuration = placement.smartSlot ?? .init()
        update(&configuration)
        value.setOwnership(.smart, smartSlot: configuration, id: id)
        draft = value
    }

    func addWidget(_ descriptor: DashboardWidgetDescriptor, size: WidgetSizePreset? = nil) {
        guard var value = draft else { return }
        let selectedSize = size ?? descriptor.defaultSize
        guard descriptor.supportedSizes.contains(selectedSize) else { return }
        value.add(kind: descriptor.kind, size: selectedSize, registry: registry)
        if let placement = value.current.placements.last(where: { $0.widgetKind == descriptor.kind.rawValue }) {
            value.setVisible(true, id: placement.id)
        }
        draft = value
    }

    func resetDraft() {
        guard var value = draft else { return }
        value.resetToCuratedDefault()
        draft = value
    }

    func refreshContext(
        candidates: [HomeContextCandidate],
        permitsSensitiveHomeContent: Bool,
        now: Date = HomeReferenceClock.now,
        force: Bool = false
    ) {
        contextCandidates = candidates
        permitsSensitiveContext = permitsSensitiveHomeContent
        contextSelection = contextEngine.reevaluate(
            candidates: candidates,
            dispositions: contextPreferences.dispositions(at: now),
            permitsSensitiveHomeContent: permitsSensitiveHomeContent,
            now: now,
            force: force
        )
    }

    func setContextFrozen(_ frozen: Bool, reason: String) {
        contextEngine.setFrozen(frozen, reason: reason)
    }

    func applyPendingContext(now: Date = HomeReferenceClock.now) {
        refreshContext(candidates: contextCandidates,
            permitsSensitiveHomeContent: permitsSensitiveContext, now: now)
    }

    func canReevaluateContext(now: Date = HomeReferenceClock.now, force: Bool = false) -> Bool {
        contextEngine.canReevaluate(now: now, force: force)
    }

    func hideContextForToday(_ candidate: HomeContextCandidate, now: Date = HomeReferenceClock.now) {
        contextPreferences.hideForToday(candidate.id, now: now)
        refreshContext(
            candidates: contextCandidates,
            permitsSensitiveHomeContent: permitsSensitiveContext,
            now: now,
            force: true
        )
    }

    func suggestContextLessOften(_ candidate: HomeContextCandidate, now: Date = HomeReferenceClock.now) {
        contextPreferences.set(.suggestLess, for: candidate.id)
        refreshContext(
            candidates: contextCandidates,
            permitsSensitiveHomeContent: permitsSensitiveContext,
            now: now,
            force: true
        )
    }

    /// Puts a suppressed suggestion back into consideration.
    func restoreContextSuggestion(_ candidate: HomeContextCandidate, now: Date = HomeReferenceClock.now) {
        contextPreferences.clear(candidate.id, now: now)
        refreshContext(
            candidates: contextCandidates,
            permitsSensitiveHomeContent: permitsSensitiveContext,
            now: now,
            force: true
        )
    }

    func neverSuggestContext(_ candidate: HomeContextCandidate, now: Date = HomeReferenceClock.now) {
        contextPreferences.set(.neverSuggest, for: candidate.id)
        refreshContext(
            candidates: contextCandidates,
            permitsSensitiveHomeContent: permitsSensitiveContext,
            now: now,
            force: true
        )
    }

    func pinContext(_ candidate: HomeContextCandidate, section: HomeSectionRole? = nil) {
        if draft == nil { beginCustomization() }
        guard let descriptor = registry.descriptor(for: candidate.widgetKind) else { return }
        guard var value = draft else { return }
        if let existing = value.current.placements.first(where: {
            $0.widgetKind == candidate.widgetKind.rawValue && $0.isVisible
        }) {
            value.setOwnership(.pinned, id: existing.id)
            value.setSection(section, id: existing.id)
        } else {
            value.add(kind: descriptor.kind, size: descriptor.defaultSize, registry: registry)
            guard let placement = value.current.placements.last(where: {
                $0.widgetKind == candidate.widgetKind.rawValue
            }) else { return }
            value.setVisible(true, id: placement.id)
            value.setOwnership(.pinned, id: placement.id)
            value.setSection(section, id: placement.id)
        }
        draft = value
        contextPreferences.set(.pinned, for: candidate.id)
    }

    func dismissError() { errorMessage = nil }
}

@MainActor
final class HomeContextPreferenceStore {
    private struct StoredPreferences: Codable {
        var persistent: [String: HomeContextDisposition] = [:]
        var hiddenByDay: [String: Set<String>] = [:]
    }

    private let defaults: UserDefaults
    private let key = "lifeOS.home.context.preferences.v1"
    private var stored: StoredPreferences

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(StoredPreferences.self, from: data) {
            stored = decoded
        } else {
            stored = .init()
        }
    }

    func dispositions(at date: Date, calendar: Calendar = .current) -> [String: HomeContextDisposition] {
        var result = stored.persistent
        for id in stored.hiddenByDay[dayKey(for: date, calendar: calendar)] ?? [] {
            result[id] = .hiddenToday
        }
        return result
    }

    func set(_ disposition: HomeContextDisposition, for candidateID: String) {
        stored.persistent[candidateID] = disposition
        persist()
    }

    /// Restores a candidate to no stated preference. Without this, "Never
    /// suggest this" was a one-way door with no receipt.
    func clear(_ candidateID: String, now: Date, calendar: Calendar = .current) {
        stored.persistent[candidateID] = nil
        stored.hiddenByDay[dayKey(for: now, calendar: calendar)]?.remove(candidateID)
        persist()
    }

    func hideForToday(_ candidateID: String, now: Date, calendar: Calendar = .current) {
        stored.hiddenByDay[dayKey(for: now, calendar: calendar), default: []].insert(candidateID)
        stored.hiddenByDay = stored.hiddenByDay.filter { $0.key >= dayKey(for: now, calendar: calendar) }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(stored) else { return }
        defaults.set(data, forKey: key)
    }

    private func dayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}
