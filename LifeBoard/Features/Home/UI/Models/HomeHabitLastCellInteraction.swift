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
                currentStateText: "Empty",
                nextActionText: "Mark done"
            )
        case (.positive, .completedToday):
            return HomeHabitLastCellInteraction(
                action: .skip,
                currentStateText: "Done",
                nextActionText: "Mark skipped"
            )
        case (.positive, .skippedToday):
            return HomeHabitLastCellInteraction(
                action: .clear,
                currentStateText: "Skipped",
                nextActionText: "Clear to empty"
            )
        case (.negative, .due), (.negative, .overdue):
            return HomeHabitLastCellInteraction(
                action: .complete,
                currentStateText: "Empty",
                nextActionText: "Mark stayed clean"
            )
        case (.negative, .completedToday):
            return HomeHabitLastCellInteraction(
                action: .lapse,
                currentStateText: "Stayed clean",
                nextActionText: "Mark lapsed"
            )
        case (.negative, .lapsedToday):
            return HomeHabitLastCellInteraction(
                action: .clear,
                currentStateText: "Lapsed",
                nextActionText: "Clear to empty"
            )
        case (.positive, .lapsedToday):
            return HomeHabitLastCellInteraction(
                action: .clear,
                currentStateText: "Lapsed",
                nextActionText: "Clear to empty"
            )
        case (.positive, .tracking):
            return HomeHabitLastCellInteraction(
                action: .complete,
                currentStateText: "Tracking",
                nextActionText: "Mark done"
            )
        case (.negative, .skippedToday):
            return HomeHabitLastCellInteraction(
                action: .clear,
                currentStateText: "Skipped",
                nextActionText: "Clear to empty"
            )
        case (.negative, .tracking):
            return HomeHabitLastCellInteraction(
                action: .complete,
                currentStateText: "Tracking",
                nextActionText: "Mark stayed clean"
            )
        }
    }

    private static func resolveLapseOnly(_ row: HomeHabitRow) -> HomeHabitLastCellInteraction {
        switch row.state {
        case .tracking, .due, .overdue:
            return HomeHabitLastCellInteraction(
                action: .lapse,
                currentStateText: "Tracking",
                nextActionText: "Mark lapsed"
            )
        case .lapsedToday, .completedToday, .skippedToday:
            return HomeHabitLastCellInteraction(
                action: .clear,
                currentStateText: row.state == .lapsedToday ? "Lapsed" : "Resolved",
                nextActionText: "Clear to tracking"
            )
        }
    }
}
