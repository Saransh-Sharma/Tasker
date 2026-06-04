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

struct HomeTimelineWorkspacePreferencesSignature: Equatable {
    let weekStartsOn: Weekday
    let showCalendarEventsInTimeline: Bool
    let riseAndShineHour: Int
    let riseAndShineMinute: Int
    let windDownHour: Int
    let windDownMinute: Int

    init(_ preferences: LifeBoardWorkspacePreferences) {
        weekStartsOn = preferences.weekStartsOn
        showCalendarEventsInTimeline = preferences.showCalendarEventsInTimeline
        riseAndShineHour = preferences.timelineRiseAndShineHour
        riseAndShineMinute = preferences.timelineRiseAndShineMinute
        windDownHour = preferences.timelineWindDownHour
        windDownMinute = preferences.timelineWindDownMinute
    }
}
