import Foundation

enum HomeHabitLastCellAction: Equatable {
    case complete
    case skip
    case lapse
    case clear
}

struct HomeHabitLastCellInteraction: Equatable {
    let action: HomeHabitLastCellAction
    let currentStateText: String
    let nextActionText: String

    static func resolve(for row: HomeHabitRow) -> HomeHabitLastCellInteraction {
        switch row.trackingMode {
        case .dailyCheckIn:
            return resolveDailyCheckIn(row)
        case .lapseOnly:
            return resolveLapseOnly(row)
        }
    }

    private static func resolveDailyCheckIn(_ row: HomeHabitRow) -> HomeHabitLastCellInteraction {
        switch (row.kind, row.state) {
        case (.positive, .due), (.positive, .overdue):
            return HomeHabitLastCellInteraction(
                action: .complete,
                currentStateText: String(localized: "Not done"),
                nextActionText: String(localized: "Mark done")
            )
        case (.positive, .completedToday):
            return HomeHabitLastCellInteraction(
                action: .skip,
                currentStateText: String(localized: "Done"),
                nextActionText: String(localized: "Mark skipped")
            )
        case (.positive, .skippedToday):
            return HomeHabitLastCellInteraction(
                action: .clear,
                currentStateText: String(localized: "Skipped"),
                nextActionText: String(localized: "Clear")
            )
        case (.negative, .due), (.negative, .overdue):
            return HomeHabitLastCellInteraction(
                action: .complete,
                currentStateText: String(localized: "Not done"),
                nextActionText: String(localized: "Mark stayed clean")
            )
        case (.negative, .completedToday):
            return HomeHabitLastCellInteraction(
                action: .lapse,
                currentStateText: String(localized: "Stayed clean"),
                nextActionText: String(localized: "Log slip")
            )
        case (.negative, .lapsedToday):
            return HomeHabitLastCellInteraction(
                action: .clear,
                currentStateText: String(localized: "Slipped"),
                nextActionText: String(localized: "Clear")
            )
        case (.positive, .lapsedToday):
            return HomeHabitLastCellInteraction(
                action: .clear,
                currentStateText: String(localized: "Slipped"),
                nextActionText: String(localized: "Clear")
            )
        case (.positive, .tracking):
            return HomeHabitLastCellInteraction(
                action: .complete,
                currentStateText: String(localized: "Tracking"),
                nextActionText: String(localized: "Mark done")
            )
        case (.negative, .skippedToday):
            return HomeHabitLastCellInteraction(
                action: .clear,
                currentStateText: String(localized: "Skipped"),
                nextActionText: String(localized: "Clear")
            )
        case (.negative, .tracking):
            return HomeHabitLastCellInteraction(
                action: .complete,
                currentStateText: String(localized: "Tracking"),
                nextActionText: String(localized: "Mark stayed clean")
            )
        }
    }

    private static func resolveLapseOnly(_ row: HomeHabitRow) -> HomeHabitLastCellInteraction {
        switch row.state {
        case .tracking, .due, .overdue:
            return HomeHabitLastCellInteraction(
                action: .lapse,
                currentStateText: String(localized: "Tracking"),
                nextActionText: String(localized: "Log slip")
            )
        case .lapsedToday, .completedToday, .skippedToday:
            return HomeHabitLastCellInteraction(
                action: .clear,
                currentStateText: row.state == .lapsedToday ? String(localized: "Slipped") : String(localized: "Resolved"),
                nextActionText: String(localized: "Clear")
            )
        }
    }
}
