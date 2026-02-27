import SwiftUI
import WidgetKit

@main
struct TaskerWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayXPWidget()
        WeeklyScoreboardWidget()
        NextMilestoneWidget()
        StreakResilienceWidget()
        FocusSeedWidget()
    }
}
