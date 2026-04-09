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

    static func resolve(for row: HomeHabitRow) -> HomeHabitLastCellInteraction? {
        guard row.trackingMode == .dailyCheckIn else { return nil }

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
        case (.positive, .lapsedToday),
             (.positive, .tracking),
             (.negative, .skippedToday),
             (.negative, .tracking):
            return nil
        }
    }
}
