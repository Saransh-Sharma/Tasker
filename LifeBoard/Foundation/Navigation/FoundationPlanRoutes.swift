import SwiftUI
import SwiftData
import LifeBoardTranscription
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
                .foregroundStyle(Color(SemanticColorTokens.foundationApricotAccent))
                .frame(width: 62, height: 62)
                .background(
                    Color(SemanticColorTokens.foundationSurfaceSelected),
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                )
            VStack(spacing: 7) {
                Text("Your tasks are on Home")
                    .font(Typography.sectionTitle())
                    .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                Text("The daily planning workspace is currently turned off. Nothing has been removed or rewritten.")
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
            onFinished: { router.popToRoot(in: router.selectedDestination) }
        )
        .id(dayKey)
    }

    private var dayKey: String {
        "\(day.year)-\(day.month)-\(day.day)"
    }
}

struct FocusSessionRouteView: View {
    let sessionID: UUID?
    let dependencies: PlanFeatureDependencies
    let router: AppRouter
    let rescueRefreshGeneration: Int
    let onOpenOverdueRescue: (OverdueRescueLaunchContext) -> Void
    @State private var state: RouteLoadState<FocusSessionV2> = .loading

    private var repository: CoreDataPlanningRepository {
        dependencies.planningRepository
    }

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView("Opening focus session…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .loaded(session) where session.state == .running || session.state == .paused:
                PlanRootView(
                    dependencies: dependencies,
                    initialLens: .day,
                    rescueRefreshGeneration: rescueRefreshGeneration,
                    onOpenFocus: { _ in },
                    onAskEva: { router.select(.eva) },
                    onOpenOverdueRescue: onOpenOverdueRescue,
                    onOpenTask: { router.push(.taskDetail($0), in: .plan) },
                    onOpenProject: { router.push(.project($0), in: .plan) }
                )
                .accessibilityIdentifier("focus.session.\(session.id.uuidString)")
            case let .loaded(session):
                focusUnavailable(
                    title: "Focus session ended",
                    detail: "This session ended \(session.endedAt?.formatted(date: .abbreviated, time: .shortened) ?? "earlier"). Its history remains available in Plan."
                )
            case .missing:
                focusUnavailable(
                    title: "Focus session not found",
                    detail: "It may have been removed on another device or the link may be out of date. No replacement session was opened."
                )
            case let .failed(message):
                focusUnavailable(title: "Focus could not be opened", detail: message)
            }
        }
        .navigationTitle("Focus")
        .task(id: sessionID) { await load() }
    }

    private func focusUnavailable(title: String, detail: String) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: "timer")
        } description: {
            Text(detail)
        } actions: {
            Button("Open Plan") { router.popToRoot(in: .plan) }
                .buttonStyle(.borderedProminent)
        }
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
    @StateObject private var viewModel: WeeklyReviewViewModel

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        _viewModel = StateObject(
            wrappedValue: CompositionRoot.shared.makeWeeklyReviewViewModel()
        )
    }

    var body: some View {
        WeeklyReviewView(
            viewModel: viewModel,
            onClose: onClose,
            onCompleted: { _ in onClose() }
        )
        .accessibilityIdentifier("plan.weeklyReview.route")
    }
}
