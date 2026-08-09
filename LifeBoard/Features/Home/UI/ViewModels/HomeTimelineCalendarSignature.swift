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

struct HomeTimelineCalendarSignature: Equatable {
    let moduleState: HomeCalendarModuleState
    let selectedDate: Date
    let selectedDayEvents: [HomeTimelineEventSignature]
    let selectedDayTimelineEvents: [HomeTimelineEventSignature]
    let isLoading: Bool
    let errorMessage: String?

    init(_ snapshot: HomeCalendarSnapshot) {
        moduleState = snapshot.moduleState
        selectedDate = snapshot.selectedDate
        selectedDayEvents = snapshot.selectedDayEvents.map(HomeTimelineEventSignature.init)
        selectedDayTimelineEvents = snapshot.selectedDayTimelineEvents.map(HomeTimelineEventSignature.init)
        isLoading = snapshot.isLoading
        errorMessage = snapshot.errorMessage
    }
}
