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

struct HomeTimelineEventSignature: Equatable {
    let id: String
    let calendarID: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let availability: LifeBoardCalendarEventAvailability
    let status: LifeBoardCalendarEventStatus
    let participationStatus: LifeBoardCalendarEventParticipationStatus
    let lastModifiedAt: Date?

    init(_ event: LifeBoardCalendarEventSnapshot) {
        id = event.id
        calendarID = event.calendarID
        startDate = event.startDate
        endDate = event.endDate
        isAllDay = event.isAllDay
        availability = event.availability
        status = event.eventStatus
        participationStatus = event.participationStatus
        lastModifiedAt = event.lastModifiedAt
    }
}
