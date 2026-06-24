//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

extension OverdueRescueViewModel {
    var currentCard: OverdueRescueCardModel? {
        guard cards.indices.contains(currentIndex) else { return nil }
        return cards[currentIndex]
    }

    var progressText: String {
        guard sprintTotal > 0 else { return "0 of 0" }
        return "\(min(sprintResolvedCount + 1, sprintTotal)) of \(sprintTotal)"
    }

    var progress: Double {
        guard sprintTotal > 0 else { return 1 }
        return Double(min(sprintResolvedCount, sprintTotal)) / Double(sprintTotal)
    }

    var remainingCount: Int {
        max(0, sprintTotal - sprintResolvedCount)
    }

    var totalRemainingCount: Int {
        max(0, allCount - resolvedTaskIDs.count)
    }

    var safeFixes: [OverdueRescueCardModel] {
        allCards.filter { card in
            guard resolvedTaskIDs.contains(card.id) == false else { return false }
            guard let recommendation = card.recommendation else { return false }
            guard recommendation.confidence >= 0.75 else { return false }
            guard recommendation.action == .doToday || recommendation.action == .move else { return false }
            guard card.task.recurrenceSeriesID == nil, card.task.repeatPattern == nil else { return false }
            return true
        }
    }

    var safeFixBreakdown: (move: Int, stay: Int, duration: Int) {
        let move = safeFixes.filter { $0.recommendation?.action == .move }.count
        let stay = safeFixes.filter { $0.recommendation?.action == .doToday }.count
        let duration = 0
        return (move, stay, duration)
    }

    func pause() {
        guard state == .active || state == .editing || state == .confirmingDelete else { return }
        transition(to: .paused)
        onTrack("rescue_pause", ["reviewed": summary.reviewed, "remaining": remainingCount])
    }

    func resume() {
        guard state == .paused else { return }
        transition(to: .active)
        onTrack("rescue_resume", ["reviewed": summary.reviewed, "remaining": remainingCount])
    }

    func startManualReview() {
        showLargeStackPreflight = false
        if cards.isEmpty, totalRemainingCount > 0 {
            _ = transition(to: .loading)
            loadNextSprint()
        }
        _ = transition(to: cards.isEmpty ? .completed : .active)
    }

    func requestEdit() {
        guard state == .active, currentCard != nil else { return }
        transition(to: .editing)
        LifeBoardFeedback.selection()
    }

    func cancelEdit() {
        guard state == .editing else { return }
        _ = transition(to: .active)
    }

    func keepToday(source: OverdueRescueDecisionSource) {
        guard let card = currentCard else { return }
        let today = Calendar.current.startOfDay(for: nowProvider())
        let schedule = TaskRescueScheduleShifter.shift(task: card.task, to: today)
        let dueDescription = schedule.dueDate?.description ?? "nil"
        let startDescription = schedule.scheduledStartAt?.description ?? "nil"
        let endDescription = schedule.scheduledEndAt?.description ?? "nil"
        let previousDueDescription = card.task.dueDate?.description ?? "nil"
        let previousStartDescription = card.task.scheduledStartAt?.description ?? "nil"
        let previousEndDescription = card.task.scheduledEndAt?.description ?? "nil"
        let logMessage = "OVERDUE_RESCUE keep_today_request task_id=\(card.id.uuidString) due=\(dueDescription) scheduled_start=\(startDescription) scheduled_end=\(endDescription) is_all_day=\(schedule.isAllDay) previous_due=\(previousDueDescription) previous_start=\(previousStartDescription) previous_end=\(previousEndDescription) previous_all_day=\(card.task.isAllDay)"
        logDebug(logMessage)
        applyUpdate(
            task: card.task,
            request: UpdateTaskDefinitionRequest(
                id: card.id,
                dueDate: schedule.dueDate,
                clearDueDate: schedule.dueDate == nil,
                scheduledStartAt: schedule.scheduledStartAt,
                clearScheduledStartAt: schedule.clearScheduledStartAt,
                scheduledEndAt: schedule.scheduledEndAt,
                clearScheduledEndAt: schedule.clearScheduledEndAt,
                isAllDay: schedule.isAllDay
            ),
            action: .keepToday,
            source: source,
            message: "Kept on today"
        )
    }

    func moveLater(source: OverdueRescueDecisionSource) {
        guard let card = currentCard else { return }
        let dueDate = card.moveDate ?? OverdueRescueMoveLaterResolver.resolveMoveDate(
            for: card.task,
            recommendation: card.recommendation,
            now: nowProvider()
        )
        let schedule = TaskRescueScheduleShifter.shift(task: card.task, to: dueDate)
        applyUpdate(
            task: card.task,
            request: UpdateTaskDefinitionRequest(
                id: card.id,
                dueDate: schedule.dueDate,
                clearDueDate: schedule.dueDate == nil,
                scheduledStartAt: schedule.scheduledStartAt,
                clearScheduledStartAt: schedule.clearScheduledStartAt,
                scheduledEndAt: schedule.scheduledEndAt,
                clearScheduledEndAt: schedule.clearScheduledEndAt,
                isAllDay: schedule.isAllDay
            ),
            action: .moveLater,
            source: source,
            message: card.moveButtonTitle == "Move tomorrow" ? "Moved to tomorrow" : "Moved later"
        )
    }

    func saveEdit(draft: OverdueRescueEditDraft) {
        guard let card = currentCard else { return }
        let significant = draft.projectID != card.task.projectID || draft.priority != card.task.priority
        applyUpdate(
            task: card.task,
            request: UpdateTaskDefinitionRequest(
                id: card.id,
                projectID: draft.projectID == card.task.projectID ? nil : draft.projectID,
                dueDate: draft.dueDate,
                clearDueDate: draft.dueDate == nil,
                priority: draft.priority == card.task.priority ? nil : draft.priority,
                estimatedDuration: draft.duration,
                clearEstimatedDuration: draft.duration == nil
            ),
            action: .edit,
            source: .edit,
            message: significant ? "Updated and kept today" : "Updated"
        )
    }

    func requestDelete() {
        guard state == .active, let card = currentCard else { return }
        if card.requiresDeleteConfirmation {
            _ = transition(to: .confirmingDelete)
        } else {
            deleteCurrent()
        }
    }

    func cancelDelete() {
        guard state == .confirmingDelete else { return }
        _ = transition(to: .active)
    }

    func confirmDelete() {
        guard state == .confirmingDelete else { return }
        deleteCurrent()
    }

    func applySafeFixes() {
        let fixes = safeFixes
        guard fixes.isEmpty == false else { return }
        guard transition(to: .applyingBulk) else { return }
        let today = Calendar.current.startOfDay(for: nowProvider())
        let mutations = fixes.compactMap { card -> EvaBatchMutationInstruction? in
            switch card.recommendation?.action {
            case .doToday:
                return EvaBatchMutationInstruction(
                    taskID: card.id,
                    expectedUpdatedAt: card.task.updatedAt,
                    dueDate: today
                )
            case .move:
                return EvaBatchMutationInstruction(
                    taskID: card.id,
                    expectedUpdatedAt: card.task.updatedAt,
                    dueDate: card.moveDate
                )
            default:
                return nil
            }
        }
        onApplyBulk(mutations) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let run):
                    for card in fixes {
                        self.undoRecords.append(OverdueRescueUndoRecord(
                            taskSnapshot: card.task,
                            source: .bulk,
                            action: card.recommendation?.action == .doToday ? .keepToday : .moveLater,
                            runID: run.id
                        ))
                    }
                    self.summary.kept += fixes.filter { $0.recommendation?.action == .doToday }.count
                    self.summary.moved += fixes.filter { $0.recommendation?.action == .move }.count
                    let fixedIDs = Set(fixes.map(\.id))
                    self.resolvedTaskIDs.formUnion(fixedIDs)
                    self.sprintResolvedCount = min(self.sprintTotal, self.sprintResolvedCount + fixes.count)
                    self.cards.removeAll { fixedIDs.contains($0.id) }
                    self.currentIndex = min(self.currentIndex, max(0, self.cards.count - 1))
                    self.snackbar = SnackbarData(message: "Applied \(fixes.count) safe fixes", actions: [SnackbarAction(title: "Undo") { self.undoLast() }])
                    self.showSafeFixesConfirmation = false
                    _ = self.transition(to: self.cards.isEmpty ? .completed : .active)
                    LifeBoardFeedback.success()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    _ = self.transition(to: .error)
                }
            }
        }
    }

    func undoLast() {
        guard let record = undoRecords.popLast() else { return }
        if record.source == .bulk, let runID = record.runID {
            let relatedRecords = [record] + undoRecords.filter { $0.runID == runID }
            undoRecords.removeAll { $0.runID == runID }
            onUndoBulk { [weak self] result in
                Task { @MainActor in
                    switch result {
                    case .success:
                        self?.snackbar = SnackbarData(message: "Safe fixes undone")
                        self?.restoreUndoRecords(relatedRecords)
                        _ = self?.transition(to: .active)
                    case .failure(let error):
                        self?.errorMessage = error.localizedDescription
                    }
                }
            }
            return
        }

        switch record.action {
        case .delete:
            onRestore(record.taskSnapshot) { [weak self] result in
                Task { @MainActor in
                    switch result {
                    case .success:
                        self?.restoreUndoRecords([record])
                        _ = self?.transition(to: .active)
                        self?.snackbar = SnackbarData(message: "Delete undone")
                    case .failure(let error):
                        self?.errorMessage = error.localizedDescription
                    }
                }
            }
        case .keepToday, .moveLater, .edit:
            let request = UpdateTaskDefinitionRequest(
                id: record.taskSnapshot.id,
                projectID: record.taskSnapshot.projectID,
                dueDate: record.taskSnapshot.dueDate,
                clearDueDate: record.taskSnapshot.dueDate == nil,
                scheduledStartAt: record.taskSnapshot.scheduledStartAt,
                clearScheduledStartAt: record.taskSnapshot.scheduledStartAt == nil,
                scheduledEndAt: record.taskSnapshot.scheduledEndAt,
                clearScheduledEndAt: record.taskSnapshot.scheduledEndAt == nil,
                isAllDay: record.taskSnapshot.isAllDay,
                priority: record.taskSnapshot.priority,
                isComplete: record.taskSnapshot.isComplete,
                estimatedDuration: record.taskSnapshot.estimatedDuration,
                clearEstimatedDuration: record.taskSnapshot.estimatedDuration == nil
            )
            onUpdate(request) { [weak self] result in
                Task { @MainActor in
                    switch result {
                    case .success:
                        self?.restoreUndoRecords([record])
                        _ = self?.transition(to: .active)
                        self?.snackbar = SnackbarData(message: "Change undone")
                    case .failure(let error):
                        self?.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    func applyUpdate(
        task: TaskDefinition,
        request: UpdateTaskDefinitionRequest,
        action: OverdueRescueDecisionAction,
        source: OverdueRescueDecisionSource,
        message: String
    ) {
        guard state == .active || state == .editing else { return }
        onUpdate(request) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let updatedTask):
                    logDebug(
                        "OVERDUE_RESCUE update_success task_id=\(updatedTask.id.uuidString) " +
                        "action=\(action.rawValue) due=\(updatedTask.dueDate?.description ?? "nil") " +
                        "scheduled_start=\(updatedTask.scheduledStartAt?.description ?? "nil") " +
                        "scheduled_end=\(updatedTask.scheduledEndAt?.description ?? "nil") " +
                        "is_all_day=\(updatedTask.isAllDay)"
                    )
                    self.undoRecords.append(OverdueRescueUndoRecord(taskSnapshot: task, source: source, action: action, runID: nil))
                    switch action {
                    case .keepToday: self.summary.kept += 1
                    case .moveLater: self.summary.moved += 1
                    case .edit: self.summary.edited += 1
                    case .delete: self.summary.deleted += 1
                    }
                    self.snackbar = SnackbarData(message: message, actions: [SnackbarAction(title: "Undo") { self.undoLast() }])
                    self.advance()
                    LifeBoardFeedback.success()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    _ = self.transition(to: .error)
                }
            }
        }
    }

    func deleteCurrent() {
        guard let card = currentCard else { return }
        onDelete(card.id) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success:
                    self.undoRecords.append(OverdueRescueUndoRecord(taskSnapshot: card.task, source: .delete, action: .delete, runID: nil))
                    self.summary.deleted += 1
                    self.snackbar = SnackbarData(message: "Deleted", actions: [SnackbarAction(title: "Undo") { self.undoLast() }])
                    self.advance()
                    LifeBoardFeedback.success()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    _ = self.transition(to: .error)
                }
            }
        }
    }

    func advance() {
        if cards.indices.contains(currentIndex) {
            resolvedTaskIDs.insert(cards[currentIndex].id)
            sprintResolvedCount = min(sprintTotal, sprintResolvedCount + 1)
            cards.remove(at: currentIndex)
        }
        if cards.isEmpty {
            currentIndex = 0
            _ = transition(to: .completed)
        } else {
            currentIndex = min(currentIndex, cards.count - 1)
            _ = transition(to: .active)
        }
    }

    func loadNextSprint() {
        let nextCards = allCards.filter { resolvedTaskIDs.contains($0.id) == false }
        cards = Array(nextCards.prefix(Self.sprintLimit))
        currentIndex = 0
        sprintTotal = cards.count
        sprintResolvedCount = 0
    }

    func restore(session: OverdueRescueSessionState) {
        let remainingIDs = session.remainingTaskIDs
        let cardByID = Dictionary(uniqueKeysWithValues: allCards.map { ($0.id, $0) })
        let restoredCards = remainingIDs.compactMap { cardByID[$0] }
        let fallbackCards = allCards.filter { session.resolvedTaskIDs.contains($0.id) == false }
        cards = restoredCards.isEmpty ? Array(fallbackCards.prefix(Self.sprintLimit)) : restoredCards
        currentIndex = min(max(0, session.currentIndex), max(0, cards.count - 1))
        sprintTotal = max(cards.count + session.resolvedTaskIDs.count, cards.count)
        sprintResolvedCount = min(session.resolvedTaskIDs.count, sprintTotal)
        summary = session.summary
        undoRecords = session.undoStack
        resolvedTaskIDs = Set(session.resolvedTaskIDs)
        lastRecoverableState = session.lastRecoverableState
        showLargeStackPreflight = allCount >= Self.largeStackThreshold && session.largeStackAcknowledged == false
        errorMessage = session.errorMessage

        if session.deckState == .loading {
            state = cards.isEmpty ? .completed : .active
        } else if session.deckState == .completed, cards.isEmpty == false {
            state = .active
        } else {
            state = session.deckState
        }
    }

    func finishAndClearSession() {
        sessionStore.clearSync(scope: sessionScope)
    }
}
