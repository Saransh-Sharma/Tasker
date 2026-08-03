//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

struct OverdueRescueCardModel: Identifiable, Equatable, Sendable {
    let id: UUID
    let task: TaskDefinition
    let recommendation: EvaRescueRecommendation?
    let overdueDays: Int
    let projectLabel: String
    let confidenceLabel: String
    let reasonTitle: String
    let reasonBody: String
    let moveDate: Date?
    let moveButtonTitle: String
    let requiresDeleteConfirmation: Bool

    static func make(
        task: TaskDefinition,
        recommendation: EvaRescueRecommendation?,
        projectsByID: [UUID: Project],
        now: Date,
        decisionAnchorDate: Date? = nil,
        decisionCalendar: Calendar = .current
    ) -> OverdueRescueCardModel {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let dueDay = task.dueDate.map { calendar.startOfDay(for: $0) } ?? today
        let overdueDays = max(1, calendar.dateComponents([.day], from: dueDay, to: today).day ?? 1)
        let confidence = recommendation?.confidence ?? 0
        let reason = Self.reasonCopy(for: task, recommendation: recommendation, overdueDays: overdueDays)
        let moveDate = OverdueRescueMoveLaterResolver.resolveMoveDate(
            for: task,
            recommendation: recommendation,
            now: decisionAnchorDate ?? now,
            calendar: decisionCalendar
        )

        return OverdueRescueCardModel(
            id: task.id,
            task: task,
            recommendation: recommendation,
            overdueDays: overdueDays,
            projectLabel: task.projectID == ProjectConstants.inboxProjectID
                ? "No project"
                : (projectsByID[task.projectID]?.name ?? task.projectName ?? "No project"),
            confidenceLabel: confidence >= 0.75 ? "High confidence" : "Needs your call",
            reasonTitle: reason.title,
            reasonBody: reason.body,
            moveDate: moveDate,
            moveButtonTitle: OverdueRescueMoveLaterResolver.buttonTitle(
                for: moveDate,
                now: decisionAnchorDate ?? now,
                calendar: decisionCalendar
            ),
            requiresDeleteConfirmation: Self.requiresDeleteConfirmation(task, now: now)
        )
    }

    var overdueText: String {
        overdueDays == 1 ? "Needs a decision for 1 day" : "Needs a decision for \(overdueDays) days"
    }

    var isHighConfidence: Bool {
        (recommendation?.confidence ?? 0) >= 0.75
    }

    static func reasonCopy(
        for task: TaskDefinition,
        recommendation: EvaRescueRecommendation?,
        overdueDays: Int
    ) -> (title: String, body: String) {
        if let recommendation, recommendation.reasons.isEmpty == false {
            let joined = recommendation.reasons
                .map { $0.replacingOccurrences(of: "Overdue \\d+d", with: "", options: .regularExpression) }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: ". ")

            switch recommendation.action {
            case .doToday:
                return ("Still relevant", joined.isEmpty ? "Relevant to current projects." : "\(joined).")
            case .move:
                return ("Today looks full", "This can move out of today’s board without risk.")
            case .split:
                return ("Needs a smaller next step", joined.isEmpty ? "Break this down before it blocks the day." : "\(joined).")
            case .dropCandidate:
                return ("Looks stale", joined.isEmpty ? "This has not moved in a while." : "\(joined).")
            }
        }

        if task.projectID != ProjectConstants.inboxProjectID {
            return ("Still relevant", "Relevant to current projects.")
        }
        if overdueDays >= 14 {
            return ("Looks stale", "This looks stale and has not moved in 2 weeks.")
        }
        return ("Needs your call", "Not enough signal to suggest a safe change.")
    }

    static func resolvedMoveDate(
        for task: TaskDefinition,
        recommendation: EvaRescueRecommendation?,
        now: Date = Date()
    ) -> Date {
        OverdueRescueMoveLaterResolver.resolveMoveDate(for: task, recommendation: recommendation, now: now)
    }

    static func moveButtonTitle(for date: Date?, now: Date = Date()) -> String {
        OverdueRescueMoveLaterResolver.buttonTitle(for: date, now: now)
    }

    static func requiresDeleteConfirmation(_ task: TaskDefinition, now: Date = Date()) -> Bool {
        let hasNotes = task.details?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let hasSubtasks = task.subtasks.isEmpty == false
        let hasRecurrence = task.recurrenceSeriesID != nil || task.repeatPattern != nil
        let hasProject = task.projectID != ProjectConstants.inboxProjectID
        let hasCalendarLink = task.scheduledStartAt != nil || task.scheduledEndAt != nil
        let hasRecentEdits = Calendar.current.dateComponents([.hour], from: task.updatedAt, to: now).hour ?? 999 < 24
        return hasNotes || hasSubtasks || hasRecurrence || hasProject || hasCalendarLink || hasRecentEdits
    }
}
