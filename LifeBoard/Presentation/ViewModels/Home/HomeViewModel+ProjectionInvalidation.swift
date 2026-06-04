//
//  HomeViewModel.swift
//  LifeBoard
//
//  ViewModel for Home screen - manages task display, focus filters, and interactions
//

import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

extension HomeViewModel {
    func bumpTaskRowsDerivationRevision() {
        taskRowsDerivationRevision &+= 1
        cachedOpenTaskRowsForHabitMutation = nil
    }

    func bumpHabitRowsDerivationRevision() {
        habitRowsDerivationRevision &+= 1
        cachedMergedHabitRows = nil
    }

    func invalidateDerivedRowCaches(for keyPath: AnyKeyPath) {
        switch keyPath {
        case \HomeViewModel.morningTasks,
             \HomeViewModel.eveningTasks,
             \HomeViewModel.overdueTasks,
             \HomeViewModel.upcomingTasks:
            bumpTaskRowsDerivationRevision()
        case \HomeViewModel.habitHomeSectionState,
             \HomeViewModel.quietTrackingSummaryState:
            bumpHabitRowsDerivationRevision()
        default:
            break
        }
    }

    func keyPathTriggersHomeRenderRefreshViaDidSet(_ keyPath: AnyKeyPath) -> Bool {
        switch keyPath {
        case \HomeViewModel.selectedDate,
             \HomeViewModel.weeklySummary,
             \HomeViewModel.weeklySummaryIsLoading,
             \HomeViewModel.weeklySummaryErrorMessage,
             \HomeViewModel.lastXPResult,
             \HomeViewModel.dueTodayRows,
             \HomeViewModel.dueTodaySection,
             \HomeViewModel.todaySections,
             \HomeViewModel.focusNowSectionState,
             \HomeViewModel.todayAgendaSectionState,
             \HomeViewModel.agendaTailItems,
             \HomeViewModel.habitHomeSectionState,
             \HomeViewModel.quietTrackingSummaryState,
             \HomeViewModel.activeFilterState,
             \HomeViewModel.savedHomeViews,
             \HomeViewModel.focusRows,
             \HomeViewModel.activeScope,
             \HomeViewModel.evaFocusWhySheetPresented,
             \HomeViewModel.evaRescueSheetPresented,
             \HomeViewModel.evaRescuePlan,
             \HomeViewModel.evaLastBatchRunID,
             \HomeViewModel.homeReplanState,
             \HomeViewModel.homeCalendarSnapshot:
            return true
        default:
            return false
        }
    }

    func homeRenderInvalidation(forAssignedKeyPath keyPath: AnyKeyPath) -> HomeRenderInvalidation {
        switch keyPath {
        case \HomeViewModel.projects,
             \HomeViewModel.lifeAreas:
            return [.chrome, .tasks, .timeline]
        case \HomeViewModel.tags,
             \HomeViewModel.emptyStateMessage,
             \HomeViewModel.emptyStateActionTitle:
            return .tasks
        case \HomeViewModel.morningTasks,
             \HomeViewModel.eveningTasks,
             \HomeViewModel.overdueTasks,
             \HomeViewModel.upcomingTasks,
             \HomeViewModel.focusTasks,
             \HomeViewModel.doneTimelineTasks,
             \HomeViewModel.dailyCompletedTasks,
             \HomeViewModel.completedTasks:
            return [.tasks, .timeline]
        case \HomeViewModel.quickViewCounts,
             \HomeViewModel.pointsPotential,
             \HomeViewModel.completionRate:
            return .chrome
        case \HomeViewModel.progressState:
            return [.chrome, .tasks]
        case \HomeViewModel.focusWhyShuffleCandidates:
            return .overlay
        default:
            return .all
        }
    }
    // MARK: - Initialization

    /// Initializes a new instance.

}
