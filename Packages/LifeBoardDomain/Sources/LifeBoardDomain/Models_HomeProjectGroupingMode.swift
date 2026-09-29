//
//  HomeProjectGroupingMode.swift
//  LifeBoard
//
//  Home task-list grouping mode for Today quick view.
//

import Foundation

public enum HomeProjectGroupingMode: String, Codable, CaseIterable, Sendable {
    case prioritizeOverdue
    case groupByProjects

    public static let defaultMode: HomeProjectGroupingMode = .prioritizeOverdue

    public var title: String {
        switch self {
        case .prioritizeOverdue:
            return String(localized: "From earlier first")
        case .groupByProjects:
            return String(localized: "By project")
        }
    }
}
