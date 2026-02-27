import Foundation

public enum XPActionCategory: String, Codable, CaseIterable {
    case complete
    case start
    case decompose
    case recoverReschedule
    case reflection
    case focus
}

public enum XPSource: String, Codable, CaseIterable {
    case manual
    case notification
    case assistant
    case system
}

public enum TaskMutationSource: String, Codable, CaseIterable {
    case manual
    case notification
    case assistant
    case system
}
