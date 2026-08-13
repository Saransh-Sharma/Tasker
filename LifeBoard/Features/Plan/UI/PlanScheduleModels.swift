import SwiftUI
import UIKit

enum PlanDayPresentation: String, CaseIterable, Identifiable {
    case canvas = "Timeline"
    case agenda = "Agenda"
    var id: String { rawValue }
}

/// How the agenda schedule is sectioned. `timeOfDay` mirrors best-in-class
/// planners (Morning / Afternoon / Evening); `none` keeps the flat card list.
enum PlanScheduleGrouping: String, CaseIterable, Identifiable {
    case timeOfDay = "Time of day"
    case none = "None"
    var id: String { rawValue }
}

/// A daypart bucket derived from a scheduled entry's start time.
enum PlanScheduleDaypart: Int, CaseIterable, Identifiable {
    case morning, afternoon, evening
    var id: Int { rawValue }

    var title: String {
        switch self {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        }
    }

    var symbolName: String {
        switch self {
        case .morning: return "sunrise"
        case .afternoon: return "sun.max"
        case .evening: return "moon.stars"
        }
    }

    static func daypart(for date: Date, calendar: Calendar = .current) -> PlanScheduleDaypart {
        switch calendar.component(.hour, from: date) {
        case 0..<12: return .morning
        case 12..<17: return .afternoon
        default: return .evening
        }
    }
}

/// A single scheduled agenda entry — a read-only calendar commitment or a
/// LifeBoard time block — unified so the daypart grouping can interleave them.
enum PlanScheduledEntry: Identifiable {
    case commitment(PlanningFixedCommitment)
    case block(InternalTimeBlock)

    var id: String {
        switch self {
        case .commitment(let commitment): return "commitment-\(commitment.id)"
        case .block(let block): return "block-\(block.id.uuidString)"
        }
    }

    var startAt: Date {
        switch self {
        case .commitment(let commitment): return commitment.startAt
        case .block(let block): return block.startAt
        }
    }
}
