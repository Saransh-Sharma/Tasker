import Foundation
import SwiftUI

public struct LifeAreaIconOption: Identifiable, Equatable, Hashable {
    public let symbolName: String
    public let keywords: [String]

    public var id: String { symbolName }

    public init(symbolName: String, keywords: [String]) {
        self.symbolName = symbolName
        self.keywords = keywords
    }
}

public struct LifeManagementAreaRow: Identifiable, Equatable, Sendable {
    public let lifeArea: LifeArea
    public let projectCount: Int
    public let habitCount: Int
    public let taskCount: Int
    public let isGeneral: Bool

    public var id: UUID { lifeArea.id }
}

public struct LifeManagementProjectRow: Identifiable, Equatable, Sendable {
    public let project: Project
    public let taskCount: Int
    public let lifeArea: LifeArea?
    public let linkedHabitCount: Int

    public var id: UUID { project.id }
    public var isInbox: Bool { project.isInbox || project.id == ProjectConstants.inboxProjectID }
    public var isMoveLocked: Bool { isInbox || project.isDefault }
}

public struct LifeManagementHabitRow: Identifiable, Equatable, Sendable {
    public let row: HabitLibraryRow
    public let lifeArea: LifeArea?
    public let project: Project?

    public var id: UUID { row.habitID }
}

public enum LifeManagementSelection: Hashable, Identifiable, Sendable {
    case area(UUID)
    case project(UUID)
    case habit(UUID)

    public var id: String {
        switch self {
        case .area(let id):
            return "area:\(id.uuidString)"
        case .project(let id):
            return "project:\(id.uuidString)"
        case .habit(let id):
            return "habit:\(id.uuidString)"
        }
    }
}

public enum LifeManagementTreeSectionKind: String, Hashable, Identifiable, Sendable {
    case active
    case archived

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .active:
            return String(localized: "Areas")
        case .archived:
            return String(localized: "Archived")
        }
    }
}

public enum LifeManagementTreeNodePayload: Equatable, Sendable {
    case area(LifeManagementAreaRow)
    case project(LifeManagementProjectRow)
    case habit(LifeManagementHabitRow)
}
