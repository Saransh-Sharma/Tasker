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

struct HomeHabitWidgetRowsState: Sendable {
    var agendaRows: [HomeHabitRow] = []
    var trackingRows: [HomeHabitRow] = []
    /// Today's recorded amount and target for amount habits, by habit id.
    var amounts: [UUID: HomeHabitWidgetAmount] = [:]
}

/// What the widget needs to draw and log an amount ring.
struct HomeHabitWidgetAmount: Equatable, Sendable {
    let current: Double
    let target: Double
    let unit: String
    let isTimed: Bool
    let step: Double
}
