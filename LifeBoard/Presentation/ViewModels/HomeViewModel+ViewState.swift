//
//  HomeViewModel+ViewState.swift
//  LifeBoard
//
//  Move-only HomeViewModel decomposition.
//

import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

// MARK: - View State

extension HomeViewModel {

    /// Combined state for the view.
    public var viewState: HomeViewState {
        HomeViewState(
            isLoading: isLoading,
            errorMessage: errorMessage,
            selectedDate: selectedDate,
            selectedProject: selectedProject,
            morningTasks: morningTasks,
            eveningTasks: eveningTasks,
            overdueTasks: overdueTasks,
            dueTodayRows: dueTodayRows,
            dueTodaySection: dueTodaySection,
            todaySections: todaySections,
            focusNowSectionState: focusNowSectionState,
            todayAgendaSectionState: todayAgendaSectionState,
            agendaTailItems: agendaTailItems,
            habitHomeSectionState: habitHomeSectionState,
            quietTrackingSummaryState: quietTrackingSummaryState,
            upcomingTasks: upcomingTasks,
            completedTasks: completedTasks,
            doneTimelineTasks: doneTimelineTasks,
            projects: projects,
            dailyScore: dailyScore,
            streak: streak,
            completionRate: completionRate,
            activeQuickView: activeFilterState.quickView,
            activeScope: activeScope,
            selectedProjectIDs: activeFilterState.selectedProjectIDs,
            pointsPotential: pointsPotential,
            progressState: progressState,
            focusTasks: focusTasks,
            focusRows: focusRows,
            pinnedFocusTaskIDs: pinnedFocusTaskIDs,
            quickViewCounts: quickViewCounts,
            savedHomeViews: savedHomeViews,
            emptyStateMessage: emptyStateMessage,
            emptyStateActionTitle: emptyStateActionTitle,
            showCompletedInline: activeFilterState.showCompletedInline,
            pinnedProjectIDs: activeFilterState.pinnedProjectIDs
        )
    }
}

/// State structure for the home view.
public struct HomeViewState {
    public let isLoading: Bool
    public let errorMessage: String?
    public let selectedDate: Date
    public let selectedProject: String
    public let morningTasks: [TaskDefinition]
    public let eveningTasks: [TaskDefinition]
    public let overdueTasks: [TaskDefinition]
    public let dueTodayRows: [HomeTodayRow]
    public let dueTodaySection: HomeListSection?
    public let todaySections: [HomeListSection]
    public let focusNowSectionState: FocusNowSectionState
    public let todayAgendaSectionState: TodayAgendaSectionState
    public let agendaTailItems: [HomeAgendaTailItem]
    public let habitHomeSectionState: HabitHomeSectionState
    public let quietTrackingSummaryState: QuietTrackingSummaryState
    public let upcomingTasks: [TaskDefinition]
    public let completedTasks: [TaskDefinition]
    public let doneTimelineTasks: [TaskDefinition]
    public let projects: [Project]
    public let dailyScore: Int
    public let streak: Int
    public let completionRate: Double
    public let activeQuickView: HomeQuickView
    public let activeScope: HomeListScope
    public let selectedProjectIDs: [UUID]
    public let pointsPotential: Int
    public let progressState: HomeProgressState
    public let focusTasks: [TaskDefinition]
    public let focusRows: [HomeTodayRow]
    public let pinnedFocusTaskIDs: [UUID]
    public let quickViewCounts: [HomeQuickView: Int]
    public let savedHomeViews: [SavedHomeView]
    public let emptyStateMessage: String?
    public let emptyStateActionTitle: String?
    public let showCompletedInline: Bool
    public let pinnedProjectIDs: [UUID]
}

public struct HomeProgressState: Equatable, Sendable {
    public let earnedXP: Int
    public let remainingPotentialXP: Int
    public let todayTargetXP: Int
    public let streakDays: Int
    public let isStreakSafeToday: Bool

    public static var empty: HomeProgressState {
        HomeProgressState(
            earnedXP: 0,
            remainingPotentialXP: 0,
            todayTargetXP: 0,
            streakDays: 0,
            isStreakSafeToday: false
        )
    }

    public var progressFraction: Double {
        guard todayTargetXP > 0 else { return 0 }
        return min(1, Double(earnedXP) / Double(todayTargetXP))
    }
}

public struct SummaryTaskRow: Equatable, Identifiable, Sendable {
    public let taskID: UUID
    public let title: String
    public let priority: TaskPriority
    public let dueDate: Date?
    public let isOverdue: Bool
    public let estimatedDuration: TimeInterval?
    public let isBlocked: Bool
    public let projectName: String?

    public var id: UUID { taskID }
}

public struct MorningPlanSummary: Equatable, Sendable {
    public let date: Date
    public let openTodayCount: Int
    public let highPriorityCount: Int
    public let overdueCount: Int
    public let potentialXP: Int
    public let focusTasks: [SummaryTaskRow]
    public let blockedCount: Int
    public let longTaskCount: Int
    public let morningPlannedCount: Int
    public let eveningPlannedCount: Int
}

public struct NightlyRetrospectiveSummary: Equatable, Sendable {
    public let date: Date
    public let completedCount: Int
    public let totalCount: Int
    public let xpEarned: Int
    public let completionRate: Double
    public let streakCount: Int
    public let biggestWins: [SummaryTaskRow]
    public let carryOverDueTodayCount: Int
    public let carryOverOverdueCount: Int
    public let tomorrowPreview: [SummaryTaskRow]
    public let morningCompletedCount: Int
    public let eveningCompletedCount: Int
}

public enum DailySummaryAnalyticsValue: Equatable, Sendable {
    case int(Int)
    case double(Double)
    case string(String)
    case bool(Bool)

    var metadataValue: Any {
        switch self {
        case .int(let value):
            return value
        case .double(let value):
            return value
        case .string(let value):
            return value
        case .bool(let value):
            return value
        }
    }
}

public struct DailySummaryAnalyticsSnapshot: Equatable, Sendable {
    public let values: [String: DailySummaryAnalyticsValue]

    public init(_ values: [String: DailySummaryAnalyticsValue]) {
        self.values = values
    }

    public var metadataValue: [String: Any] {
        values.mapValues(\.metadataValue)
    }
}

public enum DailySummaryModalData: Equatable, Sendable {
    case morning(MorningPlanSummary)
    case nightly(NightlyRetrospectiveSummary)

    public var analyticsSnapshot: DailySummaryAnalyticsSnapshot {
        switch self {
        case .morning(let summary):
            return DailySummaryAnalyticsSnapshot([
                "open_today_count": .int(summary.openTodayCount),
                "high_priority_count": .int(summary.highPriorityCount),
                "overdue_count": .int(summary.overdueCount),
                "potential_xp": .int(summary.potentialXP),
                "focus_count": .int(summary.focusTasks.count),
                "blocked_count": .int(summary.blockedCount),
                "long_task_count": .int(summary.longTaskCount)
            ])
        case .nightly(let summary):
            return DailySummaryAnalyticsSnapshot([
                "completed_count": .int(summary.completedCount),
                "total_count": .int(summary.totalCount),
                "xp_earned": .int(summary.xpEarned),
                "carry_over_due_today_count": .int(summary.carryOverDueTodayCount),
                "carry_over_overdue_count": .int(summary.carryOverOverdueCount),
                "tomorrow_preview_count": .int(summary.tomorrowPreview.count),
                "streak_count": .int(summary.streakCount)
            ])
        }
    }
}
