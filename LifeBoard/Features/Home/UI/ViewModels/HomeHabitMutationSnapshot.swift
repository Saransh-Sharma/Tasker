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

struct HomeHabitMutationSnapshot {
    let dueTodayRows: [HomeTodayRow]
    let dueTodaySection: HomeListSection?
    let todayAgendaSectionState: TodayAgendaSectionState
    let habitHomeSectionState: HabitHomeSectionState
    let quietTrackingSummaryState: QuietTrackingSummaryState
    let focusRows: [HomeTodayRow]
    let focusNowSectionState: FocusNowSectionState
    let currentHabitSignals: [LifeBoardHabitSignal]
}
