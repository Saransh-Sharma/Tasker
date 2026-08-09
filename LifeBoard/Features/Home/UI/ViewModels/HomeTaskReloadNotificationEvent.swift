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

struct HomeTaskReloadNotificationEvent {
    let source: String
    let reason: HomeTaskMutationEvent
    let notificationSource: String?
    let includeAnalytics: Bool
    let repostEvent: Bool
    let isCompletionChange: Bool
    let isStructured: Bool
}
