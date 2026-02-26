import Foundation

enum SlashCommandCategory: String, Codable {
    case planning
    case project
    case housekeeping
}

enum SlashCommandID: String, Codable, CaseIterable {
    case today
    case tomorrow
    case week
    case month
    case project
    case clear

    var canonicalCommand: String {
        switch self {
        case .today:
            return "/today"
        case .tomorrow:
            return "/tomorrow"
        case .week:
            return "/week"
        case .month:
            return "/month"
        case .project:
            return "/project"
        case .clear:
            return "/clear"
        }
    }

    var displayName: String {
        switch self {
        case .today:
            return "Today"
        case .tomorrow:
            return "Tomorrow"
        case .week:
            return "This Week"
        case .month:
            return "This Month"
        case .project:
            return "Project"
        case .clear:
            return "Clear Chat"
        }
    }

    var icon: String {
        switch self {
        case .today:
            return "sun.max"
        case .tomorrow:
            return "sunrise"
        case .week:
            return "calendar"
        case .month:
            return "calendar.badge.clock"
        case .project:
            return "folder"
        case .clear:
            return "trash"
        }
    }

    var requiresProjectName: Bool {
        self == .project
    }

    var category: SlashCommandCategory {
        switch self {
        case .today, .tomorrow, .week, .month:
            return .planning
        case .project:
            return .project
        case .clear:
            return .housekeeping
        }
    }

    var popularityRank: Int {
        switch self {
        case .today:
            return 0
        case .project:
            return 1
        case .week:
            return 2
        case .tomorrow:
            return 3
        case .month:
            return 4
        case .clear:
            return 5
        }
    }
}

struct SlashCommandDescriptor: Identifiable, Codable, Equatable {
    let id: SlashCommandID
    let shortDescription: String
    let example: String
    let aliases: [String]

    var command: String {
        id.canonicalCommand
    }
}

struct SlashCommandInvocation: Codable, Equatable {
    var id: SlashCommandID
    var projectQuery: String?
    var projectName: String?

    var isReady: Bool {
        guard id.requiresProjectName else { return true }
        guard let projectName else { return false }
        return projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var commandLabel: String {
        switch id {
        case .project:
            if let projectName, projectName.isEmpty == false {
                return "Project: \(projectName)"
            }
            return "Project"
        default:
            return id.displayName
        }
    }
}

enum SlashCommandParseResult: Equatable {
    case notCommand
    case unknown(command: String)
    case missingRequiredArgument(commandID: SlashCommandID, partial: String?)
    case invocation(SlashCommandInvocation)
}

enum SlashCommandCatalog {
    static let descriptors: [SlashCommandDescriptor] = [
        SlashCommandDescriptor(
            id: .today,
            shortDescription: "Overdue and due today",
            example: "/today",
            aliases: ["/todo"]
        ),
        SlashCommandDescriptor(
            id: .tomorrow,
            shortDescription: "Tasks due tomorrow",
            example: "/tomorrow",
            aliases: []
        ),
        SlashCommandDescriptor(
            id: .week,
            shortDescription: "Tasks due this week",
            example: "/week",
            aliases: []
        ),
        SlashCommandDescriptor(
            id: .month,
            shortDescription: "Tasks due this month",
            example: "/month",
            aliases: []
        ),
        SlashCommandDescriptor(
            id: .project,
            shortDescription: "Open tasks for a project",
            example: "/project Inbox",
            aliases: []
        ),
        SlashCommandDescriptor(
            id: .clear,
            shortDescription: "Clear current chat thread",
            example: "/clear",
            aliases: []
        )
    ]

    static func descriptor(for id: SlashCommandID) -> SlashCommandDescriptor {
        descriptors.first(where: { $0.id == id }) ?? SlashCommandDescriptor(
            id: id,
            shortDescription: "",
            example: id.canonicalCommand,
            aliases: []
        )
    }

    static func parse(_ rawText: String) -> SlashCommandParseResult {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.hasPrefix("/") else { return .notCommand }

        let components = text.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard let first = components.first else { return .unknown(command: text.lowercased()) }

        let command = first.lowercased()
        let argument = components.count > 1
            ? components[1].trimmingCharacters(in: .whitespacesAndNewlines)
            : ""

        switch command {
        case "/todo", "/today":
            return .invocation(SlashCommandInvocation(id: .today, projectQuery: nil, projectName: nil))
        case "/tomorrow":
            return .invocation(SlashCommandInvocation(id: .tomorrow, projectQuery: nil, projectName: nil))
        case "/week":
            return .invocation(SlashCommandInvocation(id: .week, projectQuery: nil, projectName: nil))
        case "/month":
            return .invocation(SlashCommandInvocation(id: .month, projectQuery: nil, projectName: nil))
        case "/project":
            if argument.isEmpty {
                return .missingRequiredArgument(commandID: .project, partial: nil)
            }
            return .invocation(
                SlashCommandInvocation(id: .project, projectQuery: argument, projectName: nil)
            )
        case "/clear":
            return .invocation(SlashCommandInvocation(id: .clear, projectQuery: nil, projectName: nil))
        default:
            return .unknown(command: command)
        }
    }

    static func filteredDescriptors(
        query: String,
        recents: [SlashCommandID],
        limit: Int = 8
    ) -> [SlashCommandDescriptor] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let recentRank = Dictionary(uniqueKeysWithValues: recents.enumerated().map { ($0.element, $0.offset) })

        let filtered = descriptors.filter { descriptor in
            guard normalized.isEmpty == false else { return true }
            if descriptor.command.lowercased().contains(normalized) { return true }
            if descriptor.id.displayName.lowercased().contains(normalized) { return true }
            return descriptor.aliases.contains(where: { $0.lowercased().contains(normalized) })
        }

        return filtered.sorted { lhs, rhs in
            let lhsRecent = recentRank[lhs.id] ?? Int.max
            let rhsRecent = recentRank[rhs.id] ?? Int.max
            if lhsRecent != rhsRecent { return lhsRecent < rhsRecent }
            if lhs.id.popularityRank != rhs.id.popularityRank {
                return lhs.id.popularityRank < rhs.id.popularityRank
            }
            return lhs.command < rhs.command
        }
        .prefix(limit)
        .map { $0 }
    }
}
