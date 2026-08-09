//
//  HomeHabitRow.swift
//  LifeBoard
//
//  Presentation model for due habit rows on Home.
//

import Foundation

public enum HomeHabitRowState: String, Equatable, Hashable, Sendable {
    case due
    case overdue
    case completedToday
    case lapsedToday
    case skippedToday
    case tracking
}

public typealias HomeHabitDayMark = HabitDayMark

public struct HomeHabitRow: Equatable, Identifiable, Sendable {
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
    public let accentHex: String?
    public let cadence: HabitCadenceDraft
    public let cadenceLabel: String
    public let dueAt: Date?
    public let state: HomeHabitRowState
    public let currentStreak: Int
    public let bestStreak: Int
    public let last14Days: [HabitDayMark]
    public let boardCellsCompact: [HabitBoardCell]
    public let boardCellsExpanded: [HabitBoardCell]
    public let riskState: HabitRiskState
    public let helperText: String?

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
        accentHex: String? = nil,
        cadence: HabitCadenceDraft = .daily(),
        cadenceLabel: String = "Every day",
        dueAt: Date? = nil,
        state: HomeHabitRowState = .due,
        currentStreak: Int = 0,
        bestStreak: Int = 0,
        last14Days: [HabitDayMark] = [],
        boardCellsCompact: [HabitBoardCell] = [],
        boardCellsExpanded: [HabitBoardCell] = [],
        riskState: HabitRiskState = .stable,
        helperText: String? = nil
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
        self.accentHex = accentHex
        self.cadence = cadence
        self.cadenceLabel = cadenceLabel
        self.dueAt = dueAt
        self.state = state
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.last14Days = last14Days
        self.boardCellsCompact = boardCellsCompact
        self.boardCellsExpanded = boardCellsExpanded
        self.riskState = riskState
        self.helperText = helperText
    }

    public var id: String {
        occurrenceID?.uuidString ?? habitID.uuidString
    }
}

// Maps a domain occurrence summary onto the Home row's presentation state.
//
// This lived on `HabitRuntimeSupport` in the domain layer, which made Domain
// name a presentation enum — the last outward reference blocking Domain from
// being extracted as a package. The derivation is presentation, so it belongs
// beside the type it produces.
public extension HabitRuntimeSupport {
    static func homeState(
        for summary: HabitOccurrenceSummary,
        on date: Date,
        calendar: Calendar = .current
    ) -> HomeHabitRowState {
        let startOfDay = calendar.startOfDay(for: date)
        switch summary.state {
        case .completed:
            return .completedToday
        case .failed:
            return .lapsedToday
        case .pending:
            if let dueAt = summary.dueAt, dueAt < startOfDay {
                return .overdue
            }
            return .due
        case .missed:
            return .overdue
        case .skipped:
            return .skippedToday
        }
    }
}
