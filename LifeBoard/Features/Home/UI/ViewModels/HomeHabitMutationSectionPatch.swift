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

struct HomeHabitMutationSectionPatch {
    let allHabitRows: [HomeHabitRow]
    let dueTodayRows: [HomeTodayRow]
    let dueTodaySection: HomeListSection?
    let habitHomeSectionState: HabitHomeSectionState
    let quietTrackingSummaryState: QuietTrackingSummaryState
    let focusRows: [HomeTodayRow]?
    let focusNowSectionState: FocusNowSectionState?
    let currentHabitSignals: [LifeBoardHabitSignal]
    let affectedRowCount: Int
    let affectedSectionCount: Int
}
