import LifeBoardDomain
import SwiftUI

/// Builds the ritual a chat turn asked for, with the same gates and stores the
/// Plan and task screens use. Lives in navigation so the chat never touches the
/// composition root; the chat only receives an `EvaRitualPresenter`.
enum EvaRitualRouteFactory {
    @MainActor
    static func presenter(router: AppRouter, planDependencies: PlanFeatureDependencies?) -> EvaRitualPresenter {
        EvaRitualPresenter(
            isAvailable: { kind in
                switch kind {
                case .makeItFit: V2FeatureFlags.evaMakeItFitTodayV1Enabled && planDependencies != nil
                case .frictionDetective: V2FeatureFlags.evaFrictionDetectiveV1Enabled && planDependencies != nil
                case .weeklyReset: V2FeatureFlags.evaWeeklyResetV1Enabled
                }
            },
            makeView: { request, onClose in
                let openTask: (UUID) -> Void = { taskID in
                    onClose()
                    router.push(.taskDetail(taskID), in: .eva)
                }
                switch request.kind {
                case .makeItFit:
                    guard V2FeatureFlags.evaMakeItFitTodayV1Enabled, let planDependencies else { return nil }
                    return AnyView(EvaMakeItFitRitualRoute(dependencies: planDependencies, onOpenTask: openTask, onClose: onClose))
                case .weeklyReset:
                    guard V2FeatureFlags.evaWeeklyResetV1Enabled else { return nil }
                    return AnyView(WeeklyReviewRoute(
                        onClose: onClose,
                        onOpenWeeklyPlanner: {
                            onClose()
                            router.select(.plan)
                            router.push(.weeklyPlanningWorkspace(.week), in: .plan)
                        },
                        onOpenTask: openTask
                    ))
                case .frictionDetective:
                    guard V2FeatureFlags.evaFrictionDetectiveV1Enabled, let planDependencies else { return nil }
                    return AnyView(EvaFrictionRitualRoute(
                        repository: planDependencies.taskDefinitionRepository,
                        query: request.argument,
                        onOpenTask: openTask,
                        onClose: onClose
                    ))
                }
            }
        )
    }
}

/// Make It Fit needs a loaded `PlanStore`; Plan's own is not reachable from
/// the chat, so this builds one the way Home's "start focus" path does.
private struct EvaMakeItFitRitualRoute: View {
    @State private var store: PlanStore
    @State private var isLoaded = false
    let onOpenTask: (UUID) -> Void
    let onClose: () -> Void

    init(dependencies: PlanFeatureDependencies, onOpenTask: @escaping (UUID) -> Void, onClose: @escaping () -> Void) {
        let repository = dependencies.planningRepository
        _store = State(initialValue: PlanStore(
            planningRepository: repository,
            blockRepository: repository,
            scenarioCoordinator: DefaultPlanningScenarioCoordinator(planning: repository, mutations: repository),
            taskDefinitionRepository: dependencies.taskDefinitionRepository,
            focusCommands: dependencies.focusCommands
        ))
        self.onOpenTask = onOpenTask
        self.onClose = onClose
    }

    var body: some View {
        Group {
            if isLoaded {
                MakeItFitTodayView(store: store, onOpenTask: onOpenTask, onClose: onClose)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .accessibilityIdentifier("eva.ritual.makeItFit")
        .task {
            await store.load()
            isLoaded = true
        }
    }
}

/// Friction Detective runs on one task, from that task's screen. From chat the
/// person names it ("/friction dentist"); this finds the matches and opens the
/// task, where the ritual itself lives. One match opens straight away.
private struct EvaFrictionRitualRoute: View {
    let repository: any TaskDefinitionRepositoryProtocol
    let query: String?
    let onOpenTask: (UUID) -> Void
    let onClose: () -> Void
    @State private var matches: [TaskDefinition] = []
    @State private var isLoaded = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoaded == false {
                    ProgressView()
                } else if matches.isEmpty {
                    StatusSurface(
                        state: .noRecord,
                        title: query.map { String(localized: "No task called “\($0)”") } ?? String(localized: "Name the task"),
                        message: String(localized: "Try /friction and part of the title.")
                    )
                    .padding(20)
                } else {
                    List(matches) { task in
                        Button {
                            onOpenTask(task.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.title).lifeboardFont(.body)
                                if let projectName = task.projectName {
                                    Text(projectName).lifeboardFont(.meta).foregroundStyle(Color.lifeboard(.textSecondary))
                                }
                            }
                        }
                        .accessibilityIdentifier("eva.ritual.friction.task.\(task.id.uuidString)")
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Pick a task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close", action: onClose).keyboardShortcut(.cancelAction) }
            }
        }
        .accessibilityIdentifier("eva.ritual.friction")
        .task { await load() }
    }

    private func load() async {
        let all: [TaskDefinition] = await withCheckedContinuation { continuation in
            repository.fetchAll { result in
                continuation.resume(returning: (try? result.get()) ?? [])
            }
        }
        let needle = query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let found = needle.isEmpty
            ? Array(all.prefix(20))
            : all.filter { $0.isComplete == false && $0.title.localizedCaseInsensitiveContains(needle) }
        if found.count == 1, needle.isEmpty == false, let only = found.first {
            onOpenTask(only.id)
            return
        }
        matches = found
        isLoaded = true
    }
}
