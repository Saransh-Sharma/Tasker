//
//  HomeSunriseFace.swift
//  LifeBoard
//
//  Move-only Home shell face support.
//

import Foundation

enum HomeSunriseFace: Equatable {
    case tasks
    case schedule
    case analytics
    case search
    case chat

    var isBackFace: Bool {
        self != .tasks
    }

    var selectedBottomBarItem: HomeBottomBarItem {
        switch self {
        case .tasks:
            return .home
        case .schedule:
            return .calendar
        case .analytics:
            return .charts
        case .search:
            return .search
        case .chat:
            return .chat
        }
    }

    var surfaceAccessibilityValue: String {
        switch self {
        case .tasks:
            return "collapsed"
        case .schedule, .analytics, .search, .chat:
            return "fullReveal"
        }
    }
}
