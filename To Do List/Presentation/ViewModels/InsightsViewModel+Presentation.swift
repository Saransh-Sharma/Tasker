import Foundation

extension InsightsViewModel {
    func blueprint(for tab: InsightsTab) -> InsightsTabBlueprint {
        switch tab {
        case .today:
            return InsightsTabBlueprint(
                heroQuestion: "How is my day going right now?",
                supportModuleIDs: ["pressure", "focus", "completion", "recovery"]
            )
        case .week:
            return InsightsTabBlueprint(
                heroQuestion: "How did I work this week and what patterns matter?",
                supportModuleIDs: ["pattern", "leaderboard", "priority_mix", "type_mix"]
            )
        case .systems:
            return InsightsTabBlueprint(
                heroQuestion: "Is the product helping me operate better over time?",
                supportModuleIDs: ["reminders", "focus_health", "recovery_health", "achievements"]
            )
        }
    }

    func visibility(for moduleID: String, in tab: InsightsTab) -> InsightsModuleVisibility {
        switch tab {
        case .today:
            return InsightsModuleVisibilityPlanner.visibility(for: moduleID, today: todayState)
        case .week:
            return InsightsModuleVisibilityPlanner.visibility(for: moduleID, week: weekState)
        case .systems:
            return InsightsModuleVisibilityPlanner.visibility(for: moduleID, systems: systemsState)
        }
    }
}
