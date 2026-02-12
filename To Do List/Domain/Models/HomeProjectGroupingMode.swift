//
//  HomeProjectGroupingMode.swift
//  Tasker
//
//  Home task-list grouping mode for Today quick view.
//

import Foundation

public enum HomeProjectGroupingMode: String, Codable, CaseIterable {
    case prioritizeOverdue
    case groupByProjects

    public static let defaultMode: HomeProjectGroupingMode = .prioritizeOverdue

    public var title: String {
        switch self {
        case .prioritizeOverdue:
            return "Prioritize Overdue"
        case .groupByProjects:
            return "Group by Projects"
        }
    }
}
