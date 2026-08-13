import SwiftUI
import UIKit

enum BacklogContextFilter: String, CaseIterable, Identifiable {
    case all = "All contexts"
    case work = "Work"
    case personal = "Personal"
    case neutral = "Neutral"
    var id: String { rawValue }
}

enum BacklogReadinessFilter: String, CaseIterable, Identifiable {
    case all = "All readiness"
    case ready = "Ready"
    case blocked = "Blocked"
    case estimateMissing = "Estimate missing"
    case hasDeadline = "Has deadline"
    var id: String { rawValue }
}

enum BacklogEnergyFilter: String, CaseIterable, Identifiable {
    case all = "All energy"
    case low = "Low energy"
    case medium = "Medium energy"
    case high = "High energy"
    case missing = "Energy missing"
    var id: String { rawValue }
}

enum BacklogDurationFilter: String, CaseIterable, Identifiable {
    case all = "All durations"
    case quick = "15 minutes or less"
    case short = "30 minutes or less"
    case hour = "60 minutes or less"
    case long = "More than 60 minutes"
    case missing = "Estimate missing"
    var id: String { rawValue }
}

enum BacklogProjectFilter: String, CaseIterable, Identifiable {
    case all = "All projects"
    case assigned = "Has project"
    case unassigned = "No project"
    var id: String { rawValue }
}
