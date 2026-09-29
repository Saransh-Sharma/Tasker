import SwiftUI

/// Synthetic, deterministic gallery data. Never reads a user store.
enum HomeCardPreviewFixtures {
    static let date = Date(timeIntervalSince1970: 1_789_430_400)
    static let tasks: [PlanningTaskSummary] = [
        "Sketch the first draft", "Book a library visit", "Water the balcony plants", "Review the weekly plan",
        "Send the project notes", "Pack a walking bag", "Choose tomorrow’s focus"
    ].enumerated().map { index, title in
        PlanningTaskSummary(id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index+1))!,
            title: title, dueDate: date, metadata: .init(taskID: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index+1))!, updatedAt: date))
    }
    static let careRows: [HomeCardQueueRow] = (1...5).map { index in
        .init(id: UUID(uuidString: String(format: "00000000-0000-0000-0001-%012d", index))!,
            title: "Medication decision", symbol: "pills", detail: "Scheduled")
    }
    static let routineRows: [HomeCardQueueRow] = ["Morning stretch", "Read for 10 min", "Water the plants", "Prepare a walking bag", "Evening wind-down"].enumerated().map { index, title in
        .init(id: UUID(uuidString: String(format: "00000000-0000-0000-0002-%012d", index+1))!, title: title, symbol: "figure.mind.and.body")
    }
    static let timeline: [AdaptiveTimelineItem] = [
        .init(id: "sample.review", title: "Design review", startDate: date.addingTimeInterval(9 * 3600), endDate: date.addingTimeInterval(10 * 3600)),
        .init(id: "sample.walk", title: "Afternoon walk", startDate: date.addingTimeInterval(14 * 3600), endDate: date.addingTimeInterval(14.5 * 3600))
    ]

    static func snapshot(for kind: DashboardWidgetKind) -> HomeCardSnapshot {
        let copy: (String, String, String)
        switch kind {
        case .setupChecklist: copy = ("2 of 5 steps", "Connect your calendar", "Continue setup")
        case .focusNow: copy = ("Sketch the first draft", "25 min focus session", "Open focus")
        case .lifeSnapshot: copy = ("Today", "Tasks, care and mood", "View snapshot")
        case .care: copy = ("1 due", "Water break", "Open care")
        case .tasks: copy = ("Today’s tasks", "Sketch the first draft", "View tasks")
        case .routines: copy = ("Evening wind-down", "Read for 10 min", "View routines")
        case .scheduleCapacity: copy = ("2 hr free", "Free this afternoon", "View schedule")
        case .quickCapture: copy = ("Capture", "Task, note or water", "Capture")
        case .compactTimeline: copy = ("Your day", "09:00 Design review", "View day")
        case .journal: copy = ("Today’s entry", "The walk home helped me slow down.", "Open journal")
        case .progressReflection: copy = ("4 of 6 done", "This week", "View progress")
        case .fasting: copy = ("Not fasting", "Last meal 12:30", "Open fasting")
        case .goals: copy = ("3 of 5 milestones", "Finish the portfolio", "View goal")
        case .evaConversation: copy = ("Suggestion", "Keep Thursday afternoon free for focus.", "Open insight")
        case .bodyMetric: copy = ("72.4 kg", "Recorded 15 September", "View body metrics")
        case .workout: copy = ("30 min", "Afternoon walk", "View workout")
        case .sleep: copy = ("7.5 hours", "Recorded 15 September", "View sleep")
        case .movement: copy = ("6,240 steps", "Recorded 15 September", "View movement")
        case .lifeMoment: copy = ("A day to remember", "Family picnic · 22 September", "View moment")
        case .nutritionSummary: copy = ("2 meals logged", "Today’s recorded meals", "View nutrition")
        case .recentMeal: copy = ("Lunch", "Vegetable soup · 12:30", "View meal")
        case .logMeal: copy = ("No meals logged", "Breakfast, lunch or dinner", "Log meal")
        default: copy = ("No preview", "Open the card", "Open")
        }
        let actionTitle = HomeWidgetRouteResolver.target(for: kind, resolution: nil, daypart: .morning)?.actionTitle ?? copy.2
        let title = DefaultDashboardWidgetRegistry.shared.descriptor(for: kind)?.title ?? "LifeBoard"
        return HomeCardSnapshot(
            availability: .ready, title: title, value: copy.0, detail: copy.1,
            payload: payload(for: kind, value: copy.0, detail: copy.1),
            actions: [.init(id: "sample.open", title: actionTitle, systemImage: "arrow.up.right", role: .primary)],
            updatedAt: date
        )
    }

    private static func payload(for kind: DashboardWidgetKind, value: String, detail: String) -> HomeCardPayload {
        switch kind {
        case .bodyMetric: return .metric(.init(amount: 72.4, fractionDigits: 1, unit: "kg"))
        case .workout: return .metric(.init(amount: 30, unit: "min"))
        case .movement: return .metric(.init(amount: 6240, unit: "steps"))
        case .nutritionSummary: return .metric(.init(amount: 2, unit: "meals logged"))
        case .goals: return .progress(fraction: 0.6, label: "3 of 5")
        case .setupChecklist: return .progress(fraction: 0.4, label: "2 of 5")
        case .journal, .evaConversation, .recentMeal:
            return .moment(.init(excerpt: detail))
        case .tasks, .care, .routines:
            return .queue([.init(id: "sample.1", title: detail), .init(id: "sample.2", title: "Take a short break")])
        default: return .none
        }
    }
}
