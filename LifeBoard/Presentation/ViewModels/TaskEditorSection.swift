import Foundation

public enum TaskEditorSection: String, CaseIterable, Hashable {
    case schedule
    case organize
    case execution
    case relationships

    public var title: String {
        switch self {
        case .schedule:
            return "Schedule"
        case .organize:
            return "Organize"
        case .execution:
            return "Execution"
        case .relationships:
            return "Relationships"
        }
    }

    public var icon: String {
        switch self {
        case .schedule:
            return "calendar.badge.clock"
        case .organize:
            return "folder"
        case .execution:
            return "bolt"
        case .relationships:
            return "link"
        }
    }
}
