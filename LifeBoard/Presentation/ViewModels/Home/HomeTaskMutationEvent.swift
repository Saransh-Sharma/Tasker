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

public enum HomeTaskMutationEvent: String, Codable, CaseIterable, Sendable {
    case created
    case updated
    case deleted
    case completed
    case reopened
    case rescheduled
    case projectChanged
    case priorityChanged
    case typeChanged
    case dueDateChanged
    case bulkChanged
}
