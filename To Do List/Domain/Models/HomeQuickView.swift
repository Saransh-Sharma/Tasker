//
//  HomeQuickView.swift
//  Tasker
//
//  Canonical quick filter views for Home "Focus Engine"
//

import Foundation

public enum HomeQuickView: String, CaseIterable, Codable {
    case today
    case upcoming
    case done
    case morning
    case evening

    public static let defaultView: HomeQuickView = .today

    public var title: String {
        switch self {
        case .today: return "Today"
        case .upcoming: return "Upcoming"
        case .done: return "Done"
        case .morning: return "Morning"
        case .evening: return "Evening"
        }
    }

    public var analyticsAction: String {
        switch self {
        case .today: return "today"
        case .upcoming: return "upcoming"
        case .done: return "done"
        case .morning: return "morning"
        case .evening: return "evening"
        }
    }
}
