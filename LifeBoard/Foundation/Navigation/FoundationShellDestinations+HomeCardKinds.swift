extension FoundationShell {
    func homeCardKinds(for destination: Destination) -> [DashboardWidgetKind]? {
        switch destination {
        case .home: return nil
        case .plan: return [.focusNow, .tasks, .scheduleCapacity, .compactTimeline]
        case .track:
            var kinds: [DashboardWidgetKind] = [.care, .routines, .goals, .fasting, .journal, .lifeSnapshot]
            if V2FeatureFlags.wellnessCoreV1Enabled {
                kinds += [.bodyMetric, .workout, .sleep, .movement]
            }
            if V2FeatureFlags.nutritionV1Enabled {
                kinds += [.nutritionSummary, .recentMeal, .logMeal]
            }
            if V2FeatureFlags.lifeMomentsV1Enabled {
                kinds.append(.lifeMoment)
            }
            return kinds
        case .insights: return [.progressReflection, .lifeSnapshot]
        case .eva: return [.progressReflection, .journal, .evaConversation]
        }
    }
}
