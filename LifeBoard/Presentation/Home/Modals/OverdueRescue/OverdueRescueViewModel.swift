//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

@MainActor
final class OverdueRescueViewModel: ObservableObject {


    static let sprintLimit = OverdueRescueEligibilityService.sprintLimit

    static let largeStackThreshold = OverdueRescueEligibilityService.largeStackThreshold

    @Published var state: OverdueRescueDeckState = .notStarted

    @Published var cards: [OverdueRescueCardModel] = []

    @Published var currentIndex = 0

    @Published var sprintTotal = 0

    @Published var sprintResolvedCount = 0

    @Published var summary = OverdueRescueSummary()

    @Published var undoRecords: [OverdueRescueUndoRecord] = []

    @Published var snackbar: SnackbarData?

    @Published var errorMessage: String?

    @Published var showLargeStackPreflight = false

    @Published var showSafeFixesConfirmation = false

    @Published var isDecisionInFlight = false

    let allCount: Int

    let allCards: [OverdueRescueCardModel]

    let referenceDate: Date

    let projectsByID: [UUID: Project]

    let nowProvider: @Sendable () -> Date

    let launchContext: OverdueRescueLaunchContext

    var resolvedTaskIDs: Set<UUID> = []

    let runID: UUID

    let sessionScope: OverdueRescueSessionScope

    let sessionStore: UserDefaultsOverdueRescueSessionStore

    var lastRecoverableState: OverdueRescueDeckState = .notStarted

    let onUpdate: @Sendable (UpdateTaskDefinitionRequest, @escaping @Sendable (Result<TaskDefinition, Error>) -> Void) -> Void

    let onDelete: @Sendable (UUID, @escaping @Sendable (Result<Void, Error>) -> Void) -> Void

    let onRestore: @Sendable (TaskDefinition, @escaping @Sendable (Result<TaskDefinition, Error>) -> Void) -> Void

    let onApplyBulk: @Sendable ([EvaBatchMutationInstruction], @escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void) -> Void

    let onUndoBulk: @Sendable (@escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void) -> Void

    let onSavePlanningMetadata: @Sendable (
        [PlanningTaskMetadata],
        @escaping @Sendable (Result<Void, Error>) -> Void
    ) -> Void

    let onTrack: (String, [String: Any]) -> Void

    init(
        plan: EvaRescuePlan?,
        tasksByID: [UUID: TaskDefinition],
        projectsByID: [UUID: Project],
        referenceDate: Date = Date(),
        nowProvider: @escaping @Sendable () -> Date = Date.init,
        launchContext: OverdueRescueLaunchContext? = nil,
        sessionScope: OverdueRescueSessionScope? = nil,
        sessionStore: UserDefaultsOverdueRescueSessionStore = UserDefaultsOverdueRescueSessionStore(),
        onUpdate: @escaping @Sendable (UpdateTaskDefinitionRequest, @escaping @Sendable (Result<TaskDefinition, Error>) -> Void) -> Void,
        onDelete: @escaping @Sendable (UUID, @escaping @Sendable (Result<Void, Error>) -> Void) -> Void,
        onRestore: @escaping @Sendable (TaskDefinition, @escaping @Sendable (Result<TaskDefinition, Error>) -> Void) -> Void,
        onApplyBulk: @escaping @Sendable ([EvaBatchMutationInstruction], @escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void) -> Void,
        onUndoBulk: @escaping @Sendable (@escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void) -> Void,
        onSavePlanningMetadata: @escaping @Sendable (
            [PlanningTaskMetadata],
            @escaping @Sendable (Result<Void, Error>) -> Void
        ) -> Void = { _, completion in completion(.success(())) },
        onTrack: @escaping (String, [String: Any]) -> Void
    ) {
        let resolvedLaunchContext = launchContext ?? .home(referenceDate: referenceDate)
        let planRecommendations = Self.orderedRecommendations(from: plan)
        let recommendationByID = Dictionary(uniqueKeysWithValues: planRecommendations.map { ($0.taskID, $0) })
        let scope = sessionScope ?? resolvedLaunchContext.sessionScope()
        let decisionCalendar = resolvedLaunchContext.decisionCalendar()
        let eligibleTasks = OverdueRescueEligibilityService.eligibleTasks(
            from: tasksByID,
            recommendations: planRecommendations,
            projectsByID: projectsByID,
            referenceDate: referenceDate
        )
        let cards = eligibleTasks
            .map { task in
                OverdueRescueCardModel.make(
                    task: task,
                    recommendation: recommendationByID[task.id],
                    projectsByID: projectsByID,
                    now: referenceDate,
                    decisionAnchorDate: resolvedLaunchContext.targetDate(calendar: decisionCalendar),
                    decisionCalendar: decisionCalendar
                )
            }
            .sorted { lhs, rhs in
                OverdueRescueEligibilityService.sortCards(lhs, rhs, referenceDate: referenceDate)
            }

        self.allCards = cards
        self.allCount = cards.count
        self.referenceDate = referenceDate
        self.projectsByID = projectsByID
        self.nowProvider = nowProvider
        self.launchContext = resolvedLaunchContext
        self.sessionScope = scope
        self.sessionStore = sessionStore
        let savedSession: OverdueRescueSessionState?
        do {
            savedSession = try sessionStore.loadSync(scope: scope)
        } catch {
            logError("[OverdueRescue] Failed to load saved session scope=\(scope.storageKey): \(error)")
            savedSession = nil
        }
        self.runID = savedSession?.runID ?? UUID()
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self.onRestore = onRestore
        self.onApplyBulk = onApplyBulk
        self.onUndoBulk = onUndoBulk
        self.onSavePlanningMetadata = onSavePlanningMetadata
        self.onTrack = onTrack

        if let savedSession,
           savedSession.deckState != .completed,
           savedSession.eligibleTaskIDs.contains(where: { tasksByID[$0] != nil }) {
            restore(session: savedSession)
        } else {
            let firstSprintCards = Array(cards.prefix(Self.sprintLimit))
            self.cards = firstSprintCards
            self.sprintTotal = firstSprintCards.count
            self.showLargeStackPreflight = cards.count >= Self.largeStackThreshold
            _ = transition(to: .loading)
            _ = transition(to: cards.isEmpty ? .completed : .active)
        }
    }
}
