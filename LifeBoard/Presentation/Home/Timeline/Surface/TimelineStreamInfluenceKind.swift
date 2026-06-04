import SwiftUI

enum TimelineStreamInfluenceKind: Equatable {
    case range
    case sweep
    case routine
    case meeting
    case task
    case gap
    case flock

    var priority: Int {
        switch self {
        case .flock:
            return 6
        case .meeting:
            return 5
        case .task:
            return 4
        case .routine:
            return 3
        case .gap:
            return 2
        case .range:
            return 0
        case .sweep:
            return 1
        }
    }

    var baseStrength: CGFloat {
        switch self {
        case .range:
            return 0
        case .sweep:
            return 0
        case .routine:
            return 8
        case .task:
            return 5
        case .gap:
            return 0
        case .meeting:
            return 9
        case .flock:
            return 18
        }
    }

    var baseMass: CGFloat {
        switch self {
        case .routine:
            return 0.65
        case .meeting:
            return 0.75
        case .task:
            return 0.45
        case .flock:
            return 1.40
        case .range, .sweep, .gap:
            return 0
        }
    }

    var contributesCurvatureMass: Bool {
        switch self {
        case .routine, .meeting, .task, .flock:
            return true
        case .range, .sweep, .gap:
            return false
        }
    }

    var thicknessBonus: CGFloat {
        switch self {
        case .flock:
            return 1
        case .meeting:
            return 0.5
        case .gap:
            return 0.35
        case .task:
            return 0.25
        case .range, .sweep, .routine:
            return 0
        }
    }

    var overshoot: CGFloat {
        switch self {
        case .flock:
            return 0
        case .meeting:
            return 0
        case .sweep:
            return 0
        case .task:
            return 0
        case .range, .routine, .gap:
            return 0
        }
    }
}
