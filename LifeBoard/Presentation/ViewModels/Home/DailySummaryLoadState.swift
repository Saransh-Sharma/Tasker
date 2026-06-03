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

struct DailySummaryLoadState: Sendable {
    var allTasksResult: Result<[TaskDefinition], GetTasksError>?
    var analytics: DailyAnalytics?
    var streakCount: Int?
    var dateTasks: DateTasksResult?
}
