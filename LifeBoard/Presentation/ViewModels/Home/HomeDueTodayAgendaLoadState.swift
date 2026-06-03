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

struct HomeDueTodayAgendaLoadState: Sendable {
    var agendaHabitRows: [HomeHabitRow] = []
    var trackingHabitRows: [HomeHabitRow] = []
    var historyByHabitID: [UUID: [HabitDayMark]] = [:]
    var libraryRowsByID: [UUID: HabitLibraryRow] = [:]
}
