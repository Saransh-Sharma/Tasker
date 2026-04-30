//
//  HomeBottomBarItem.swift
//  Tasker
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum HomeBottomBarItem: Equatable, Hashable {
    case home
    case calendar
    case charts
    case search
    case chat
    case create
}

extension HomeBottomBarItem {
    static let visibleAnimatedItems: [HomeBottomBarItem] = [
        .home,
        .calendar,
        .chat,
        .charts,
        .search,
        .create
    ]

    var accessibilityValue: String {
        switch self {
        case .home:
            return "home"
        case .calendar:
            return "calendar"
        case .charts:
            return "charts"
        case .search:
            return "search"
        case .chat:
            return "chat"
        case .create:
            return "create"
        }
    }
}

enum HomeCalendarBottomBarSymbol {
    static func symbolName(for date: Date, calendar: Calendar = .current) -> String {
        let candidate = symbolName(day: calendar.component(.day, from: date))
        guard candidate != "calendar", isSystemSymbolAvailable(candidate) else {
            return "calendar"
        }
        return candidate
    }

    static func symbolName(day: Int) -> String {
        guard (1...31).contains(day) else {
            return "calendar"
        }
        return "\(day).calendar"
    }

    private static func isSystemSymbolAvailable(_ symbolName: String) -> Bool {
        #if canImport(UIKit)
        return UIImage(systemName: symbolName) != nil
        #else
        return true
        #endif
    }
}
