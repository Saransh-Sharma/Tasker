import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

enum OnboardingPainPoint: String, CaseIterable, Codable, Identifiable {
    case overwhelm
    case forgottenFollowUps
    case hijackedDay
    case habitRestarts
    case listCalendarMismatch
    case tooManyPriorities

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overwhelm: return "I freeze when there are too many priorities"
        case .forgottenFollowUps: return "I forget important follow-ups"
        case .hijackedDay: return "My day gets hijacked"
        case .habitRestarts: return "I keep restarting the same routines"
        case .listCalendarMismatch: return "My calendar and task list never match"
        case .tooManyPriorities: return "Several priorities compete and I stall"
        }
    }

    var symbolName: String {
        switch self {
        case .overwhelm: return "brain.head.profile"
        case .forgottenFollowUps: return "bell.badge"
        case .hijackedDay: return "bolt.fill"
        case .habitRestarts: return "arrow.counterclockwise"
        case .listCalendarMismatch: return "calendar.badge.exclamationmark"
        case .tooManyPriorities: return "list.bullet.clipboard"
        }
    }

    var mappedFrictionProfile: OnboardingFrictionProfile {
        switch self {
        case .overwhelm:
            return .overwhelmed
        case .forgottenFollowUps:
            return .remembering
        case .hijackedDay:
            return .finishing
        case .habitRestarts:
            return .starting
        case .listCalendarMismatch:
            return .remembering
        case .tooManyPriorities:
            return .choosing
        }
    }
}
