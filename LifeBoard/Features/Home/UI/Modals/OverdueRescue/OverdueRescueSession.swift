import SwiftUI
import UIKit

// Session state: what a rescue session is, how it is scoped, how it
// persists, and what it remembers for undo.

// MARK: - OverdueRescueSessionScope

//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


struct OverdueRescueSessionScope: Codable, Equatable, Hashable, Sendable {
    var accountScopeID: String
    var workspaceID: String?
    var rescueDay: Date
    var purpose: String? = nil

    var storageKey: String {
        let dayStamp = Int(Calendar.current.startOfDay(for: rescueDay).timeIntervalSince1970)
        let purposeSuffix = purpose.map { ".\($0)" } ?? ""
        return "overdueRescue.session.v1.\(accountScopeID).\(workspaceID ?? "default").\(dayStamp)\(purposeSuffix)"
    }
}

struct OverdueRescueLaunchContext: Equatable, Sendable {
    enum Origin: String, Codable, Sendable {
        case home
        case plan
        /// Adapted Day-Rescue variant entered from the universal input composer:
        /// reuses the same decision-deck chrome and card physics as Overdue
        /// Rescue, but pulls in today's "needs replan" candidates rather than
        /// the overdue pool. The empty-at-launch deck surfaces a different
        /// empty-state copy ("Nothing needs rescuing today") and writes a
        /// distinct `purpose` so a day-rescue run never collides with an
        /// overdue-rescue run's persisted session memory.
        case universalInputDayRescue
    }

    let origin: Origin
    let source: String
    let referenceDate: Date
    let targetPlanningDay: PlanningDay?
    let planningMetadataByTaskID: [UUID: PlanningTaskMetadata]
    let synchronizesKeptTasksWithPlan: Bool

    static func home(referenceDate: Date) -> OverdueRescueLaunchContext {
        OverdueRescueLaunchContext(
            origin: .home,
            source: "home",
            referenceDate: referenceDate,
            targetPlanningDay: nil,
            planningMetadataByTaskID: [:],
            synchronizesKeptTasksWithPlan: false
        )
    }

    static func plan(
        selectedDay: PlanningDay,
        planningMetadataByTaskID: [UUID: PlanningTaskMetadata],
        referenceDate: Date = Date()
    ) -> OverdueRescueLaunchContext {
        OverdueRescueLaunchContext(
            origin: .plan,
            source: "plan_day_open_card",
            referenceDate: referenceDate,
            targetPlanningDay: selectedDay,
            planningMetadataByTaskID: planningMetadataByTaskID,
            synchronizesKeptTasksWithPlan: true
        )
    }

    /// A modified-overdue-rescue deck scoped to today's "needs replan"
    /// candidates rather than the overdue pool. The deck reuses the existing
    /// card machinery and chrome; only the candidate source and the
    /// empty-at-launch copy differ.
    static func universalInputDayRescue(referenceDate: Date) -> OverdueRescueLaunchContext {
        OverdueRescueLaunchContext(
            origin: .universalInputDayRescue,
            source: "universal_input.day_rescue",
            referenceDate: referenceDate,
            targetPlanningDay: nil,
            planningMetadataByTaskID: [:],
            synchronizesKeptTasksWithPlan: false
        )
    }

    func decisionCalendar(base calendar: Calendar = .current) -> Calendar {
        guard let identifier = targetPlanningDay?.timeZoneIdentifier,
              let timeZone = TimeZone(identifier: identifier) else {
            return calendar
        }
        var resolved = calendar
        resolved.timeZone = timeZone
        return resolved
    }

    func targetDate(calendar: Calendar = .current) -> Date {
        let calendar = decisionCalendar(base: calendar)
        if let targetPlanningDay,
           let target = targetPlanningDay.startDate(calendar: calendar) {
            return target
        }
        return calendar.startOfDay(for: referenceDate)
    }

    func keepActionTitle(calendar: Calendar = .current) -> String {
        let calendar = decisionCalendar(base: calendar)
        let target = targetDate(calendar: calendar)
        let today = calendar.startOfDay(for: referenceDate)
        if calendar.isDate(target, inSameDayAs: today) {
            return "Keep today"
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
           calendar.isDate(target, inSameDayAs: tomorrow) {
            return "Keep tomorrow"
        }
        return "Keep on \(target.formatted(.dateTime.weekday(.wide)))"
    }

    func keepSuccessMessage(calendar: Calendar = .current) -> String {
        let title = keepActionTitle(calendar: calendar)
        guard title.hasPrefix("Keep") else { return title }
        return "Kept\(title.dropFirst("Keep".count))"
    }

    func sessionScope(
        accountScopeID: String = "default",
        workspaceID: String? = nil,
        calendar: Calendar = .current
    ) -> OverdueRescueSessionScope {
        let calendar = decisionCalendar(base: calendar)
        let purpose: String?
        switch origin {
        case .plan:
            let target = targetDate(calendar: calendar)
            purpose = "plan-\(Int(target.timeIntervalSince1970))"
        case .universalInputDayRescue:
            purpose = "universalInput.dayRescue"
        case .home:
            purpose = nil
        }
        return OverdueRescueSessionScope(
            accountScopeID: accountScopeID,
            workspaceID: workspaceID,
            rescueDay: referenceDate,
            purpose: purpose
        )
    }
}

// MARK: - OverdueRescueSessionState

//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


struct OverdueRescueSessionState: Codable, Equatable, Sendable {
    var runID: UUID
    var accountScopeID: String
    var workspaceID: String?
    var referenceDate: Date
    var deckState: OverdueRescueDeckState
    var eligibleTaskIDs: [UUID]
    var remainingTaskIDs: [UUID]
    var resolvedTaskIDs: [UUID]
    var currentIndex: Int
    var keptCount: Int
    var movedCount: Int
    var deletedCount: Int
    var editedCount: Int
    var bulkAppliedCount: Int
    var largeStackAcknowledged: Bool
    var undoStack: [OverdueRescueUndoRecord]
    var lastRecoverableState: OverdueRescueDeckState
    var errorMessage: String?
    var createdAt: Date
    var updatedAt: Date

    var summary: OverdueRescueSummary {
        OverdueRescueSummary(kept: keptCount, moved: movedCount, edited: editedCount, deleted: deletedCount)
    }
}

// MARK: - OverdueRescueSessionStore

//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


protocol OverdueRescueSessionStore {
    func load(scope: OverdueRescueSessionScope) async throws -> OverdueRescueSessionState?
    func save(_ session: OverdueRescueSessionState, scope: OverdueRescueSessionScope) async throws
    func clear(scope: OverdueRescueSessionScope) async throws
}

// MARK: - UserDefaultsOverdueRescueSessionStore

//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


struct UserDefaultsOverdueRescueSessionStore: OverdueRescueSessionStore {
    let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func load(scope: OverdueRescueSessionScope) async throws -> OverdueRescueSessionState? {
        try loadSync(scope: scope)
    }

    func save(_ session: OverdueRescueSessionState, scope: OverdueRescueSessionScope) async throws {
        try saveSync(session, scope: scope)
    }

    func clear(scope: OverdueRescueSessionScope) async throws {
        clearSync(scope: scope)
    }

    func loadSync(scope: OverdueRescueSessionScope) throws -> OverdueRescueSessionState? {
        guard let data = userDefaults.data(forKey: scope.storageKey) else { return nil }
        return try JSONDecoder().decode(OverdueRescueSessionState.self, from: data)
    }

    func saveSync(_ session: OverdueRescueSessionState, scope: OverdueRescueSessionScope) throws {
        let data = try JSONEncoder().encode(session)
        userDefaults.set(data, forKey: scope.storageKey)
    }

    func clearSync(scope: OverdueRescueSessionScope) {
        userDefaults.removeObject(forKey: scope.storageKey)
    }
}

// MARK: - OverdueRescueUndoRecord

//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


struct OverdueRescueUndoRecord: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let runID: UUID?
    let taskID: UUID
    let source: OverdueRescueDecisionSource
    let action: OverdueRescueDecisionAction
    let previousDueDate: Date?
    let previousProjectID: UUID?
    let previousDurationMinutes: Int?
    let previousPriority: TaskPriority?
    let previousCompletionState: Bool
    let previousDeletedState: Bool
    let previousRecurrenceState: RecurrenceInstanceSnapshot?
    let previousPlanningMetadata: PlanningTaskMetadata?
    let fullSnapshot: AssistantTaskSnapshot
    let createdAt: Date

    init(
        taskSnapshot: TaskDefinition,
        source: OverdueRescueDecisionSource,
        action: OverdueRescueDecisionAction,
        runID: UUID?,
        previousPlanningMetadata: PlanningTaskMetadata? = nil
    ) {
        self.id = UUID()
        self.runID = runID
        self.taskID = taskSnapshot.id
        self.source = source
        self.action = action
        self.previousDueDate = taskSnapshot.dueDate
        self.previousProjectID = taskSnapshot.projectID
        self.previousDurationMinutes = taskSnapshot.estimatedDuration.map { Int(($0 / 60).rounded()) }
        self.previousPriority = taskSnapshot.priority
        self.previousCompletionState = taskSnapshot.isComplete
        self.previousDeletedState = false
        self.previousRecurrenceState = RecurrenceInstanceSnapshot(
            recurrenceSeriesID: taskSnapshot.recurrenceSeriesID,
            repeatPattern: taskSnapshot.repeatPattern,
            dueDate: taskSnapshot.dueDate,
            scheduledStartAt: taskSnapshot.scheduledStartAt,
            scheduledEndAt: taskSnapshot.scheduledEndAt
        )
        self.previousPlanningMetadata = previousPlanningMetadata
        self.fullSnapshot = AssistantTaskSnapshot(task: taskSnapshot)
        self.createdAt = Date()
    }

    var taskSnapshot: TaskDefinition {
        fullSnapshot.toTaskDefinition()
    }
}

// MARK: - OverdueRescueSummary

//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


struct OverdueRescueSummary: Equatable, Sendable {
    var kept = 0
    var moved = 0
    var edited = 0
    var deleted = 0

    var reviewed: Int { kept + moved + edited + deleted }
}

// MARK: - OverdueRescueStateMachine

//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


enum OverdueRescueStateMachine {
    static func canTransition(from current: OverdueRescueDeckState, to next: OverdueRescueDeckState) -> Bool {
        if next == .error {
            return current != .completed
        }
        switch (current, next) {
        case (.notStarted, .loading),
             (.loading, .active),
             (.loading, .completed),
             (.loading, .error),
             (.active, .editing),
             (.editing, .active),
             (.active, .confirmingDelete),
             (.confirmingDelete, .active),
             (.active, .paused),
             (.editing, .paused),
             (.confirmingDelete, .paused),
             (.paused, .active),
             (.active, .applyingBulk),
             (.applyingBulk, .active),
             (.active, .completed),
             (.editing, .completed),
             (.confirmingDelete, .completed),
             (.paused, .completed),
             (.applyingBulk, .completed),
             (.completed, .loading),
             (.completed, .active),
             (.error, .active),
             (.error, .editing),
             (.error, .confirmingDelete),
             (.error, .paused),
             (.error, .applyingBulk):
            return true
        default:
            return current == next
        }
    }

    static func isRecoverable(_ state: OverdueRescueDeckState) -> Bool {
        switch state {
        case .active, .editing, .confirmingDelete, .paused, .applyingBulk:
            return true
        case .notStarted, .loading, .completed, .error:
            return false
        }
    }
}

// MARK: - RecurrenceInstanceSnapshot

//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


struct RecurrenceInstanceSnapshot: Codable, Equatable, Sendable {
    let recurrenceSeriesID: UUID?
    let repeatPattern: TaskRepeatPattern?
    let dueDate: Date?
    let scheduledStartAt: Date?
    let scheduledEndAt: Date?
}
