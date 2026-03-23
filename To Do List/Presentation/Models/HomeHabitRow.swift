//
//  HomeHabitRow.swift
//  Tasker
//
//  Presentation model for due habit rows on Home.
//

import Foundation

public enum HomeHabitRowState: String, Equatable, Hashable {
    case due
    case overdue
    case completedToday
    case lapsedToday
    case skippedToday
    case tracking
}

public typealias HomeHabitDayMark = HabitDayMark

public struct HomeHabitRow: Equatable, Identifiable {
    public let habitID: UUID
    public let occurrenceID: UUID?
    public let title: String
    public let kind: HabitKind
    public let trackingMode: HabitTrackingMode
    public let lifeAreaID: UUID?
    public let lifeAreaName: String
    public let projectID: UUID?
    public let projectName: String?
    public let iconSymbolName: String
    public let dueAt: Date?
    public let state: HomeHabitRowState
    public let currentStreak: Int
    public let bestStreak: Int
    public let last14Days: [HabitDayMark]
    public let riskState: HabitRiskState

    public init(
        habitID: UUID,
        occurrenceID: UUID? = nil,
        title: String,
        kind: HabitKind,
        trackingMode: HabitTrackingMode,
        lifeAreaID: UUID? = nil,
        lifeAreaName: String,
        projectID: UUID? = nil,
        projectName: String? = nil,
        iconSymbolName: String,
        dueAt: Date? = nil,
        state: HomeHabitRowState = .due,
        currentStreak: Int = 0,
        bestStreak: Int = 0,
        last14Days: [HabitDayMark] = [],
        riskState: HabitRiskState = .stable
    ) {
        self.habitID = habitID
        self.occurrenceID = occurrenceID
        self.title = title
        self.kind = kind
        self.trackingMode = trackingMode
        self.lifeAreaID = lifeAreaID
        self.lifeAreaName = lifeAreaName
        self.projectID = projectID
        self.projectName = projectName
        self.iconSymbolName = iconSymbolName
        self.dueAt = dueAt
        self.state = state
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.last14Days = last14Days
        self.riskState = riskState
    }

    public var id: String {
        occurrenceID?.uuidString ?? habitID.uuidString
    }
}
