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

struct HomeCanonicalHabitMutationLoadState: Sendable {
    var projectionRow: HomeHabitRow?
    var libraryRow: HabitLibraryRow?
    var historyByHabitID: [UUID: [HabitDayMark]] = [:]
}
