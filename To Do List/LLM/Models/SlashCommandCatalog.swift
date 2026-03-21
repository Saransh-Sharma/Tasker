import Foundation

enum SlashCommandCategory: String, Codable {
    case planning
    case project
    case lifeArea
    case housekeeping
}

enum SlashCommandID: String, Codable, CaseIterable {
    case today
    case tomorrow
    case week
    case month
    case project
    case area
    case recent
    case overdue
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
        case .area:
            return "/area"
        case .recent:
            return "/recent"
        case .overdue:
            return "/overdue"
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
        case .area:
            return "Life Area"
        case .recent:
            return "Recent"
        case .overdue:
            return "Overdue"
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
        case .area:
            return "square.grid.2x2"
        case .recent:
            return "clock.arrow.circlepath"
        case .overdue:
            return "exclamationmark.arrow.trianglehead.counterclockwise"
        case .clear:
            return "trash"
        }
    }

    var requiresArgument: Bool {
        self == .project || self == .area
    }

    var argumentPlaceholder: String? {
        switch self {
        case .project:
            return "Pick project"
        case .area:
            return "Pick life area"
        default:
            return nil
        }
    }

    var category: SlashCommandCategory {
        switch self {
        case .today, .tomorrow, .week, .month, .recent, .overdue:
            return .planning
        case .project:
            return .project
        case .area:
            return .lifeArea
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
        case .recent:
            return 5
        case .overdue:
            return 6
        case .area:
            return 7
        case .clear:
            return 8
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
    var argumentQuery: String?
    var resolvedArgument: String?

    init(
        id: SlashCommandID,
        projectQuery: String? = nil,
        projectName: String? = nil,
        argumentQuery: String? = nil,
        resolvedArgument: String? = nil
    ) {
        self.id = id
        self.argumentQuery = argumentQuery ?? projectQuery
        self.resolvedArgument = resolvedArgument ?? projectName
    }

    var projectQuery: String? {
        get { argumentQuery }
        set { argumentQuery = newValue }
    }

    var projectName: String? {
        get { resolvedArgument }
        set { resolvedArgument = newValue }
    }

    var isReady: Bool {
        guard id.requiresArgument else { return true }
        guard let resolvedArgument else { return false }
        return resolvedArgument.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var commandLabel: String {
        switch id {
        case .project:
            if let resolvedArgument, resolvedArgument.isEmpty == false {
                return "Project: \(resolvedArgument)"
            }
            return "Project"
        case .area:
            if let resolvedArgument, resolvedArgument.isEmpty == false {
                return "Life Area: \(resolvedArgument)"
            }
            return "Life Area"
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
            id: .area,
            shortDescription: "Open tasks for a life area",
            example: "/area Health",
            aliases: []
        ),
        SlashCommandDescriptor(
            id: .recent,
            shortDescription: "Recent operating summary",
            example: "/recent",
            aliases: []
        ),
        SlashCommandDescriptor(
            id: .overdue,
            shortDescription: "Only overdue tasks",
            example: "/overdue",
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
            return .invocation(SlashCommandInvocation(id: .today, argumentQuery: nil, resolvedArgument: nil))
        case "/tomorrow":
            return .invocation(SlashCommandInvocation(id: .tomorrow, argumentQuery: nil, resolvedArgument: nil))
        case "/week":
            return .invocation(SlashCommandInvocation(id: .week, argumentQuery: nil, resolvedArgument: nil))
        case "/month":
            return .invocation(SlashCommandInvocation(id: .month, argumentQuery: nil, resolvedArgument: nil))
        case "/project":
            if argument.isEmpty {
                return .missingRequiredArgument(commandID: .project, partial: nil)
            }
            return .invocation(
                SlashCommandInvocation(id: .project, argumentQuery: argument, resolvedArgument: nil)
            )
        case "/area":
            if argument.isEmpty {
                return .missingRequiredArgument(commandID: .area, partial: nil)
            }
            return .invocation(
                SlashCommandInvocation(id: .area, argumentQuery: argument, resolvedArgument: nil)
            )
        case "/recent":
            return .invocation(SlashCommandInvocation(id: .recent, argumentQuery: nil, resolvedArgument: nil))
        case "/overdue":
            return .invocation(SlashCommandInvocation(id: .overdue, argumentQuery: nil, resolvedArgument: nil))
        case "/clear":
            return .invocation(SlashCommandInvocation(id: .clear, argumentQuery: nil, resolvedArgument: nil))
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
