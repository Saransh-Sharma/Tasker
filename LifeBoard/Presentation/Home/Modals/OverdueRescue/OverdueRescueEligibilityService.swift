//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

enum OverdueRescueEligibilityService {
    static let sprintLimit = 12
    static let maximumSprintLimit = 15
    static let largeStackThreshold = 20

    static func eligibleTasks(
        from tasksByID: [UUID: TaskDefinition],
        recommendations: [EvaRescueRecommendation],
        projectsByID: [UUID: Project],
        referenceDate: Date
    ) -> [TaskDefinition] {
        let taskIDs = Set(tasksByID.keys).union(recommendations.map(\.taskID))
        return taskIDs
            .compactMap { tasksByID[$0] }
            .filter { isEligible($0, projectsByID: projectsByID, referenceDate: referenceDate) }
    }

    static func isEligible(
        _ task: TaskDefinition,
        projectsByID: [UUID: Project],
        referenceDate: Date
    ) -> Bool {
        guard task.isComplete == false, task.parentTaskID == nil, let dueDate = task.dueDate else { return false }
        if let project = projectsByID[task.projectID], project.isArchived {
            return false
        }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)
        guard dueDate < today else { return false }
        if let deferred = task.deferredFromWeekStart, calendar.isDate(deferred, inSameDayAs: today) {
            return false
        }
        return true
    }

    static func sortCards(
        _ lhs: OverdueRescueCardModel,
        _ rhs: OverdueRescueCardModel,
        referenceDate: Date
    ) -> Bool {
        let lhsScore = rankingScore(lhs, referenceDate: referenceDate)
        let rhsScore = rankingScore(rhs, referenceDate: referenceDate)
        if lhsScore != rhsScore { return lhsScore > rhsScore }
        if lhs.overdueDays != rhs.overdueDays { return lhs.overdueDays > rhs.overdueDays }
        return lhs.task.title.localizedCaseInsensitiveCompare(rhs.task.title) == .orderedAscending
    }

    static func rankingScore(_ card: OverdueRescueCardModel, referenceDate: Date) -> Int {
        var score = 0
        if card.task.priority.isHighPriority { score += 1_000 }
        if Calendar.current.isDate(card.task.dueDate ?? .distantPast, inSameDayAs: referenceDate) { score += 800 }
        if (card.task.estimatedDuration ?? .greatestFiniteMagnitude) <= 1_800 { score += 300 }
        if Calendar.current.dateComponents([.day], from: card.task.updatedAt, to: referenceDate).day ?? 999 <= 7 { score += 200 }
        if card.task.projectID != ProjectConstants.inboxProjectID { score += 100 }
        if card.projectLabel == "No project" { score -= 80 }
        if card.isHighConfidence == false { score -= 100 }
        if card.overdueDays >= 14 { score -= 120 }
        return score
    }
}
