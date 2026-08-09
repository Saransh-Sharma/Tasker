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

struct HomeTimelineSnapshotCacheKey: Equatable {
    let dataRevision: HomeDataRevision
    let selectedDay: Date
    let currentMinuteStamp: Int
    let sunriseAnchor: SunriseAnchor
    let calendarSignature: HomeTimelineCalendarSignature
    let workspacePreferences: HomeTimelineWorkspacePreferencesSignature
    let hiddenCalendarEvents: [HomeTimelineHiddenCalendarEventKey]
    let pinnedFocusTaskIDs: [UUID]
    let needsReplanCandidates: [HomeTimelineReplanCandidateSignature]
    let replanState: HomeTimelineReplanStateSignature
    let taskCandidates: [TaskDefinition]
    let projects: [Project]
    let lifeAreas: [LifeArea]
}
