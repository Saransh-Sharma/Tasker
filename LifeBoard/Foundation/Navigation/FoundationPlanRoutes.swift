import SwiftUI
import SwiftData
import UIKit
import VisionKit

/// Data-preserving rollback destination for the Phase 1 route graph.
///
/// Work created while the flagship was enabled remains in the canonical task
/// repositories and is therefore visible through the previous Home task
/// experience. No Phase 1 store is initialized from this route.
struct PlanRollbackRouteView: View {
    let router: AppRouter

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "checklist")
                .font(Typography.screenTitle())
                .foregroundStyle(Color(SemanticColorTokens.foundationApricotInk))
                .frame(width: 62, height: 62)
                .background(
                    Color(SemanticColorTokens.foundationSurfaceSelected),
                    in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                )
            VStack(spacing: 7) {
                Text("Your tasks are on Home")
                    .font(Typography.sectionTitle())
                    .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                Text("Plan is turned off.")
                    .font(Typography.body())
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    .multilineTextAlignment(.center)
            }
            Button {
                router.select(.home)
            } label: {
                Text("Open Home")
                    .font(Typography.body().weight(.semibold))
                    .foregroundStyle(Color(SemanticColorTokens.foundationSurfaceSolid))
                    .frame(minWidth: 132, minHeight: 44)
                    .padding(.horizontal, 12)
                    .background(
                        Color(SemanticColorTokens.inkPrimary),
                        in: Capsule(style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("plan.rollback.openHome")
        }
        .padding(28)
        .frame(maxWidth: 430)
        .lifeBoardPaperCard()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(SemanticColorTokens.foundationSurfaceSolid).ignoresSafeArea())
        .navigationTitle("Plan")
        .accessibilityIdentifier("plan.rollback")
    }
}

/// Route host for the end-of-day ritual.
///
/// Owns the store so the ritual's state survives a scroll, a keyboard, and a
/// sheet, and rebuilds it only when the *day* changes — `task(id:)` on the day
/// key rather than on the raw `Date`, because a `Date` that ticks would discard
/// every decision made so far.
struct DayCloseRouteView: View {
    let date: Date
    let mode: DayCloseMode
    let dependencies: PlanFeatureDependencies
    let router: AppRouter
    var journal: (any PhaseIIRepository)? = nil

    private var day: PlanningDay { PlanningDay(date: date) }

    /// Opening reports on yesterday; closing reports on itself.
    ///
    /// Without this the morning showed *today's* open tasks beneath "What
    /// carried" and "Last night's decisions" — a claim that was false on any day
    /// that was never closed.
    private var retrospectiveDay: PlanningDay? {
        guard mode == .open else { return nil }
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: date) else { return nil }
        return PlanningDay(date: yesterday)
    }

    var body: some View {
        DayCloseRoute(
            store: DayCloseStore(
                reader: dependencies.planningRepository,
                completions: nil,
                scenarios: DefaultPlanningScenarioCoordinator(
                    planning: dependencies.planningRepository,
                    mutations: dependencies.planningRepository
                ),
                day: day,
                retrospectiveDay: retrospectiveDay
            ),
            mode: mode,
            reflections: dependencies.reflectionNoteRepository,
            journal: journal,
            onFinished: finish
        )
        .id(dayKey)
    }

    /// The evening close ends where it started. The morning's only action is
    /// "Open plan", which used to pop to the root of whichever tab hosted it —
    /// Home, usually — instead of opening the plan it named.
    private func finish() {
        let origin = router.selectedDestination
        guard mode == .open else {
            router.popToRoot(in: origin)
            return
        }
        PlanDayHandoff.request(PlanningDay(date: Date()))
        router.popToRoot(in: origin)
        if origin != .plan { router.popToRoot(in: .plan) }
        router.select(.plan)
    }

    private var dayKey: String {
        "\(day.year)-\(day.month)-\(day.day)"
    }
}

struct FocusSessionRouteView: View {
    let sessionID: UUID?
    let dependencies: PlanFeatureDependencies
    let router: AppRouter
    let onOpenOverdueRescue: (OverdueRescueLaunchContext) -> Void
    @State private var state: RouteLoadState<FocusSessionV2> = .loading
    /// The surface's own store, built exactly as `PlanRootView` builds its own
    /// (`PlanRootView.swift:63`). Focus is no longer a lens inside Plan, so it
    /// cannot borrow Plan's — and a session surface that outlived its store
    /// would show a live dial over stale transport controls.
    @State private var focusStore: PlanStore

    init(
        sessionID: UUID?,
        dependencies: PlanFeatureDependencies,
        router: AppRouter,
        onOpenOverdueRescue: @escaping (OverdueRescueLaunchContext) -> Void
    ) {
        self.sessionID = sessionID
        self.dependencies = dependencies
        self.router = router
        self.onOpenOverdueRescue = onOpenOverdueRescue
        let repository = dependencies.planningRepository
        _focusStore = State(initialValue: PlanStore(
            planningRepository: repository,
            blockRepository: repository,
            scenarioCoordinator: DefaultPlanningScenarioCoordinator(
                planning: repository,
                mutations: repository
            ),
            taskDefinitionRepository: dependencies.taskDefinitionRepository,
            focusCommands: dependencies.focusCommands
        ))
    }

    private var repository: CoreDataPlanningRepository {
        dependencies.planningRepository
    }

    var body: some View {
        Group {
            switch state {
            case .loading:
                focusUnavailable(
                    state: .loading,
                    title: String(localized: "Loading…"),
                    detail: ""
                )
            case let .loaded(session) where session.state == .running || session.state == .paused:
                // Was `PlanRootView(initialLens: .day)` — the entire Plan Day
                // surface, lens picker included, with the running session as one
                // card inside it. `AppRoute.focusSession` already resolves to
                // `ScreenMode.focused`, so the shell was already dropping its
                // dock and composer for a screen that then showed everything
                // anyway. `FocusSurface` is what that route was always meant to
                // open.
                FocusSurface(
                    store: focusStore,
                    session: session,
                    onClose: { router.popToRoot(in: .plan) },
                    onOpenHistory: { router.push(.focusHistory, in: .plan) }
                )
                .task { await focusStore.load() }
                .accessibilityIdentifier("focus.session.\(session.id.uuidString)")
            case let .loaded(session):
                focusUnavailable(
                    // A session that ran its course is a record, not a failure.
                    state: .noRecord,
                    title: String(localized: "Focus session ended"),
                    detail: session.endedAt.map { String(localized: "Ended \($0.formatted(date: .abbreviated, time: .shortened))") } ?? "",
                    actionTitle: String(localized: "Focus history"),
                    action: { router.push(.focusHistory, in: .plan) }
                )
            case .missing:
                focusUnavailable(
                    state: .noRecord,
                    title: String(localized: "Focus session not found"),
                    detail: String(localized: "It may have been deleted.")
                )
            case let .failed(message):
                // Distinct from the two above: this one is retryable, and the
                // surface says so instead of looking like an empty state.
                focusUnavailable(
                    state: .recoverableError,
                    title: String(localized: "Couldn’t open focus session"),
                    detail: message,
                    actionTitle: String(localized: "Try again"),
                    action: { Task { await load() } }
                )
            }
        }
        .navigationTitle("Focus")
        .task(id: sessionID) { await load() }
    }

    /// `StatusSurface` rather than `ContentUnavailableView`, and with the state
    /// named rather than inferred.
    ///
    /// The three cases that reach this are genuinely different — a session that
    /// ended normally, one that no longer exists, and one that failed to load —
    /// and `ContentUnavailableView` rendered all three as the same grey timer
    /// glyph. `DESIGN.md`: "Loading, genuinely empty, no record, denied… must
    /// remain distinct."
    private func focusUnavailable(
        state: StatusSurface.State,
        title: String,
        detail: String,
        actionTitle: String = "Open Plan",
        action: (() -> Void)? = nil
    ) -> some View {
        VStack {
            StatusSurface(
                state: state,
                title: title,
                message: detail,
                actionTitle: actionTitle,
                action: action ?? { router.popToRoot(in: .plan) }
            )
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func load() async {
        guard let sessionID else {
            do {
                if let active = try await repository.activeSession() { state = .loaded(active) }
                else { state = .missing }
            } catch { state = .failed(error.localizedDescription) }
            return
        }
        do {
            state = try await repository.session(id: sessionID).map(RouteLoadState.loaded) ?? .missing
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

/// Host for "This week".
///
/// Builds its own `PlanStore` from the same dependencies the Plan root uses.
/// A route pushed onto Plan cannot reach the root's `@State` store, and sharing
/// one would couple the workspace's day selection to the Day lens behind it —
/// the two surfaces are deliberately allowed to sit on different days.
@MainActor
struct WeeklyPlanningWorkspaceRoute: View {
    let entry: WeeklyPlanningEntry
    let onClose: () -> Void
    @State private var store: PlanStore

    init(dependencies: PlanFeatureDependencies, entry: WeeklyPlanningEntry, onClose: @escaping () -> Void) {
        self.entry = entry
        self.onClose = onClose
        let repository = dependencies.planningRepository
        _store = State(initialValue: PlanStore(
            planningRepository: repository,
            blockRepository: repository,
            scenarioCoordinator: DefaultPlanningScenarioCoordinator(
                planning: repository,
                mutations: repository
            ),
            taskDefinitionRepository: dependencies.taskDefinitionRepository,
            focusCommands: dependencies.focusCommands
        ))
    }

    var body: some View {
        WeeklyPlanningWorkspaceView(store: store, entry: entry, onClose: onClose)
            .task { await store.load() }
            .accessibilityIdentifier("plan.weeklyPlanningWorkspace.route")
    }
}

/// Typed native route into the existing persisted weekly review and recovery
/// flow. Completion and cancellation both return deterministically to Week.
@MainActor
struct WeeklyReviewRoute: View {
    let onClose: () -> Void
    let onOpenWeeklyPlanner: () -> Void
    let onOpenTask: (UUID) -> Void
    @StateObject private var viewModel: WeeklyReviewViewModel

    init(
        onClose: @escaping () -> Void,
        onOpenWeeklyPlanner: @escaping () -> Void,
        onOpenTask: @escaping (UUID) -> Void
    ) {
        self.onClose = onClose
        self.onOpenWeeklyPlanner = onOpenWeeklyPlanner
        self.onOpenTask = onOpenTask
        _viewModel = StateObject(
            wrappedValue: CompositionRoot.shared.makeWeeklyReviewViewModel()
        )
    }

    var body: some View {
        Group {
            if V2FeatureFlags.evaWeeklyResetV1Enabled,
               let frictionRepository = CompositionRoot.shared.frictionFindingRepository,
               let taskRepository = CompositionRoot.shared.taskDefinitionRepository {
                WeeklyResetView(
                    viewModel: viewModel,
                    frictionRepository: frictionRepository,
                    taskRepository: taskRepository,
                    actionPipeline: CompositionRoot.shared.useCaseCoordinator.assistantActionPipeline,
                    onClose: onClose,
                    onOpenWeeklyPlanner: onOpenWeeklyPlanner,
                    onOpenTask: onOpenTask,
                    // Pushed onto the root's stack: a nested NavigationStack
                    // rendered only SwiftUI's warning-triangle placeholder.
                    embedsInNavigationStack: false
                )
            } else {
                WeeklyReviewView(
                    viewModel: viewModel,
                    onClose: onClose,
                    onCompleted: { _ in onClose() },
                    embedsInNavigationStack: false
                )
            }
        }
        .accessibilityIdentifier("plan.weeklyReview.route")
    }
}
