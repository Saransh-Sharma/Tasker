import Foundation

enum InsightsModuleVisibilityPlanner {
    static func visibility(for moduleID: String, today state: InsightsTodayState) -> InsightsModuleVisibility {
        let hasAnySignal =
            state.duePressureMetrics.isEmpty == false
            || state.focusMetrics.isEmpty == false
            || state.completionMixSections.isEmpty == false
            || state.recoveryMetrics.isEmpty == false

        switch moduleID {
        case "pressure":
            if state.duePressureMetrics.isEmpty {
                return hasAnySignal ? .hidden : .empty(message: "Not enough signal yet. Complete a few tasks or log one recovery action to build today’s board.")
            }
            return .visible
        case "focus":
            return state.focusMetrics.isEmpty ? .hidden : .visible
        case "completion":
            return state.completionMixSections.isEmpty ? .hidden : .visible
        case "recovery":
            return state.recoveryMetrics.isEmpty ? .hidden : .visible
        default:
            return .hidden
        }
    }

    static func visibility(for moduleID: String, week state: InsightsWeekState) -> InsightsModuleVisibility {
        let hasAnySignal =
            state.weeklyBars.isEmpty == false
            || state.projectLeaderboard.isEmpty == false
            || state.priorityMix.isEmpty == false
            || state.taskTypeMix.isEmpty == false

        switch moduleID {
        case "pattern":
            if state.weeklyBars.isEmpty {
                return hasAnySignal ? .hidden : .empty(message: "Not enough weekly signal yet. Once a few days of work land, the patterns will tighten up here.")
            }
            return .visible
        case "leaderboard":
            return state.projectLeaderboard.isEmpty ? .hidden : .visible
        case "priority_mix":
            return state.priorityMix.isEmpty ? .hidden : .visible
        case "type_mix":
            return state.taskTypeMix.isEmpty ? .hidden : .visible
        default:
            return .hidden
        }
    }

    static func visibility(for moduleID: String, systems state: InsightsSystemsState) -> InsightsModuleVisibility {
        let hasAnySignal =
            state.reminderResponse.totalDeliveries > 0
            || state.focusHealthMetrics.isEmpty == false
            || state.recoveryHealthMetrics.isEmpty == false
            || state.achievementProgress.isEmpty == false

        switch moduleID {
        case "reminders":
            if state.reminderResponse.totalDeliveries == 0 {
                return hasAnySignal ? .hidden : .empty(message: "Not enough system signal yet. Reminder response, focus, and recovery patterns will show up as the app gets used.")
            }
            return .visible
        case "focus_health":
            return state.focusHealthMetrics.isEmpty ? .hidden : .visible
        case "recovery_health":
            return state.recoveryHealthMetrics.isEmpty ? .hidden : .visible
        case "achievements":
            return state.achievementProgress.isEmpty ? .hidden : .visible
        default:
            return .hidden
        }
    }
}
