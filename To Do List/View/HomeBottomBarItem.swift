//
//  HomeBottomBarItem.swift
//  Tasker
//

import Foundation

enum HomeBottomBarItem: Equatable {
    case home
    case charts
    case search
    case chat
    case create
}

extension HomeBottomBarItem {
    var accessibilityValue: String {
        switch self {
        case .home:
            return "home"
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
