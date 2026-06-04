import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

enum OnboardingPrimaryGoal: String, CaseIterable, Codable, Identifiable {
    case wholeWeek
    case workDeadlines
    case lifeAdmin
    case habitsRoutines
    case calendarChaos
    case dailyExecution

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wholeWeek: return "My whole week"
        case .workDeadlines: return "Work and deadlines"
        case .lifeAdmin: return "Life admin"
        case .habitsRoutines: return "Habits and routines"
        case .calendarChaos: return "Calendar chaos"
        case .dailyExecution: return "Starting each day"
        }
    }

    var subtitle: String {
        switch self {
        case .wholeWeek: return "See work, habits, and personal life in one system."
        case .workDeadlines: return "Stay ahead of deliverables without scattered lists."
        case .lifeAdmin: return "Keep bills, chores, and personal follow-through visible."
        case .habitsRoutines: return "Build consistency with a streak you can actually see."
        case .calendarChaos: return "Turn a packed schedule into something manageable."
        case .dailyExecution: return "Know the one thing to start with when the day opens."
        }
    }

    var symbolName: String {
        switch self {
        case .wholeWeek: return "square.grid.2x2"
        case .workDeadlines: return "briefcase.fill"
        case .lifeAdmin: return "house.fill"
        case .habitsRoutines: return "repeat.circle.fill"
        case .calendarChaos: return "calendar"
        case .dailyExecution: return "play.circle.fill"
        }
    }

    var preferredLifeAreaIDs: [String] {
        switch self {
        case .wholeWeek:
            return ["work-career", "life-admin", "health-self"]
        case .workDeadlines:
            return ["work-career", "life-admin"]
        case .lifeAdmin:
            return ["life-admin", "health-self"]
        case .habitsRoutines:
            return ["health-self", "life-admin"]
        case .calendarChaos:
            return ["life-admin", "work-career"]
        case .dailyExecution:
            return ["work-career", "health-self", "life-admin"]
        }
    }
}
