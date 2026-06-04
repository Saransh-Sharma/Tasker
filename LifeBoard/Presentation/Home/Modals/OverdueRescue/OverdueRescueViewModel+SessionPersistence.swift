//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

extension OverdueRescueViewModel {
    func currentSessionState() -> OverdueRescueSessionState {
        let now = Date()
        return OverdueRescueSessionState(
            runID: runID,
            accountScopeID: sessionScope.accountScopeID,
            workspaceID: sessionScope.workspaceID,
            referenceDate: referenceDate,
            deckState: state,
            eligibleTaskIDs: allCards.map(\.id),
            remainingTaskIDs: cards.map(\.id),
            resolvedTaskIDs: Array(resolvedTaskIDs),
            currentIndex: currentIndex,
            keptCount: summary.kept,
            movedCount: summary.moved,
            deletedCount: summary.deleted,
            editedCount: summary.edited,
            bulkAppliedCount: undoRecords.filter { $0.source == .bulk }.count,
            largeStackAcknowledged: showLargeStackPreflight == false,
            undoStack: undoRecords,
            lastRecoverableState: lastRecoverableState,
            errorMessage: errorMessage,
            createdAt: now,
            updatedAt: now
        )
    }

    func persistSession() {
        do {
            try sessionStore.saveSync(currentSessionState(), scope: sessionScope)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restoreUndoRecords(_ records: [OverdueRescueUndoRecord]) {
        guard records.isEmpty == false else { return }
        for record in records {
            resolvedTaskIDs.remove(record.taskSnapshot.id)
            decrementSummary(for: record.action)
        }
        let restoredCards = records
            .filter { record in cards.contains(where: { $0.id == record.taskSnapshot.id }) == false }
            .map { record in
                OverdueRescueCardModel.make(
                    task: record.taskSnapshot,
                    recommendation: nil,
                    projectsByID: projectsByID,
                    now: referenceDate
                )
            }
        cards.insert(contentsOf: restoredCards, at: min(currentIndex, cards.count))
        sprintResolvedCount = max(0, sprintResolvedCount - records.count)
        if sprintTotal == 0 {
            sprintTotal = cards.count
        }
    }

    func decrementSummary(for action: OverdueRescueDecisionAction) {
        switch action {
        case .keepToday: summary.kept = max(0, summary.kept - 1)
        case .moveLater: summary.moved = max(0, summary.moved - 1)
        case .edit: summary.edited = max(0, summary.edited - 1)
        case .delete: summary.deleted = max(0, summary.deleted - 1)
        }
    }

    @discardableResult
    func transition(to next: OverdueRescueDeckState) -> Bool {
        guard Self.canTransition(from: state, to: next) else {
            assertionFailure("Invalid Overdue Rescue transition: \(state) -> \(next)")
            return false
        }
        if Self.isRecoverable(state) {
            lastRecoverableState = state
        }
        state = next
        persistSession()
        return true
    }

    static func canTransition(from current: OverdueRescueDeckState, to next: OverdueRescueDeckState) -> Bool {
        OverdueRescueStateMachine.canTransition(from: current, to: next)
    }

    static func isRecoverable(_ state: OverdueRescueDeckState) -> Bool {
        OverdueRescueStateMachine.isRecoverable(state)
    }

    static func orderedRecommendations(from plan: EvaRescuePlan?) -> [EvaRescueRecommendation] {
        guard let plan else { return [] }
        return plan.doToday + plan.move + plan.split + plan.dropCandidate
    }
}
