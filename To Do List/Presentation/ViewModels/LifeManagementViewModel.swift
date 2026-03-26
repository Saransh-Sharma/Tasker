import Foundation
import SwiftUI
import UniformTypeIdentifiers

private enum LifeManagementConstants {
    static let generalDisplayName = "General"
    static let generalNormalizedName = "general"
}

public enum LifeManagementScope: String, CaseIterable, Identifiable {
    case overview
    case areas
    case projects
    case habits
    case archive

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .overview:
            return String(localized: "Overview", defaultValue: "Overview")
        case .areas:
            return String(localized: "Areas", defaultValue: "Areas")
        case .projects:
            return String(localized: "Projects", defaultValue: "Projects")
        case .habits:
            return String(localized: "Habits", defaultValue: "Habits")
        case .archive:
            return String(localized: "Archive", defaultValue: "Archive")
        }
    }
}

public enum LifeManagementHabitFilter: String, CaseIterable, Identifiable {
    case all
    case build
    case quit
    case paused

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .all: return "All"
        case .build: return "Build"
        case .quit: return "Quit"
        case .paused: return "Paused"
        }
    }
}

public struct LifeAreaIconOption: Identifiable, Equatable, Hashable {
    public let symbolName: String
    public let keywords: [String]

    public var id: String { symbolName }

    /// Initializes a new instance.
    public init(symbolName: String, keywords: [String]) {
        self.symbolName = symbolName
        self.keywords = keywords
    }
}

public struct LifeManagementOverviewStat: Identifiable, Equatable {
    public let title: String
    public let value: String
    public let symbolName: String

    public var id: String { title }

    /// Initializes a new instance.
    public init(title: String, value: String, symbolName: String) {
        self.title = title
        self.value = value
        self.symbolName = symbolName
    }
}

public enum LifeManagementAttentionItemKind: String, Equatable {
    case emptyProject = "empty_project"
    case pausedHabit = "paused_habit"
    case archivedItem = "archived_item"
}

public struct LifeManagementAttentionItem: Identifiable, Equatable {
    public let kind: LifeManagementAttentionItemKind
    public let title: String
    public let detail: String
    public let symbolName: String

    public var id: String { kind.rawValue }

    /// Initializes a new instance.
    public init(kind: LifeManagementAttentionItemKind, title: String, detail: String, symbolName: String) {
        self.kind = kind
        self.title = title
        self.detail = detail
        self.symbolName = symbolName
    }
}

public struct LifeManagementOverview: Equatable {
    public var stats: [LifeManagementOverviewStat]
    public var attentionItems: [LifeManagementAttentionItem]
    public var topAreas: [LifeManagementAreaRow]
    public var attentionProjects: [LifeManagementProjectRow]
    public var attentionHabits: [LifeManagementHabitRow]

    public static let empty = LifeManagementOverview(
        stats: [],
        attentionItems: [],
        topAreas: [],
        attentionProjects: [],
        attentionHabits: []
    )
}

public struct LifeManagementAreaRow: Identifiable, Equatable {
    public let lifeArea: LifeArea
    public let projectCount: Int
    public let habitCount: Int
    public let taskCount: Int
    public let isGeneral: Bool

    public var id: UUID { lifeArea.id }
}

public struct LifeManagementProjectRow: Identifiable, Equatable {
    public let project: Project
    public let taskCount: Int
    public let lifeArea: LifeArea?
    public let linkedHabitCount: Int

    public var id: UUID { project.id }
    public var isInbox: Bool { project.isInbox || project.id == ProjectConstants.inboxProjectID }
    public var isMoveLocked: Bool { isInbox || project.isDefault }
}

public struct LifeManagementHabitRow: Identifiable, Equatable {
    public let row: HabitLibraryRow
    public let lifeArea: LifeArea?
    public let project: Project?

    public var id: UUID { row.habitID }
}

public struct LifeManagementProjectGroup: Identifiable, Equatable {
    public let lifeArea: LifeArea?
    public let title: String
    public let rows: [LifeManagementProjectRow]

    public var id: String { lifeArea?.id.uuidString ?? title }
}

public struct LifeManagementHabitGroup: Identifiable, Equatable {
    public let lifeArea: LifeArea?
    public let title: String
    public let rows: [LifeManagementHabitRow]

    public var id: String { lifeArea?.id.uuidString ?? title }
}

public struct LifeManagementArchiveSections: Equatable {
    public let areas: [LifeManagementAreaRow]
    public let projects: [LifeManagementProjectGroup]
    public let habits: [LifeManagementHabitGroup]

    public static let empty = LifeManagementArchiveSections(areas: [], projects: [], habits: [])

    public var hasContent: Bool {
        areas.isEmpty == false || projects.isEmpty == false || habits.isEmpty == false
    }
}

public struct LifeManagementSearchResults: Equatable {
    public let areas: [LifeManagementAreaRow]
    public let projects: [LifeManagementProjectRow]
    public let habits: [LifeManagementHabitRow]

    public static let empty = LifeManagementSearchResults(areas: [], projects: [], habits: [])

    public var isEmpty: Bool {
        areas.isEmpty && projects.isEmpty && habits.isEmpty
    }
}

public struct LifeManagementLifeAreaDraft: Identifiable, Equatable {
    public let id: UUID
    public let existingID: UUID?
    public var name: String
    public var colorHex: String
    public var iconSymbolName: String

    public var isNew: Bool { existingID == nil }

    /// Initializes a new instance.
    public init(
        id: UUID = UUID(),
        existingID: UUID? = nil,
        name: String,
        colorHex: String,
        iconSymbolName: String
    ) {
        self.id = id
        self.existingID = existingID
        self.name = name
        self.colorHex = colorHex
        self.iconSymbolName = iconSymbolName
    }
}

public struct LifeManagementProjectDraft: Identifiable, Equatable {
    public let id: UUID
    public let existingID: UUID?
    public var name: String
    public var description: String
    public var lifeAreaID: UUID?
    public var color: ProjectColor
    public var icon: ProjectIcon

    public var isNew: Bool { existingID == nil }

    /// Initializes a new instance.
    public init(
        id: UUID = UUID(),
        existingID: UUID? = nil,
        name: String,
        description: String,
        lifeAreaID: UUID?,
        color: ProjectColor,
        icon: ProjectIcon
    ) {
        self.id = id
        self.existingID = existingID
        self.name = name
        self.description = description
        self.lifeAreaID = lifeAreaID
        self.color = color
        self.icon = icon
    }
}

public struct LifeManagementProjectMoveDraft: Identifiable, Equatable {
    public let id: UUID
    public let projectID: UUID
    public let projectName: String
    public var targetLifeAreaID: UUID?
}

public struct LifeManagementDeleteAreaDraft: Identifiable, Equatable {
    public let id: UUID
    public let areaID: UUID
    public let areaName: String
    public let projectCount: Int
    public let habitCount: Int
    public var destinationLifeAreaID: UUID?
}

public struct LifeManagementDeleteProjectDraft: Identifiable, Equatable {
    public let id: UUID
    public let projectID: UUID
    public let projectName: String
    public let taskCount: Int
    public let linkedHabitCount: Int
    public var destinationProjectID: UUID?
}

public struct LifeManagementDeleteHabitDraft: Identifiable, Equatable {
    public let id: UUID
    public let habitID: UUID
    public let habitTitle: String
}

private enum LifeManagementUndoAction {
    case lifeArea(UUID)
    case project(UUID)
    case habit(UUID)
}

struct LifeManagementProjection {
    struct Snapshot: Equatable {
        let overview: LifeManagementOverview
        let areaRows: [LifeManagementAreaRow]
        let projectGroups: [LifeManagementProjectGroup]
        let habitGroups: [LifeManagementHabitGroup]
        let archiveSections: LifeManagementArchiveSections
        let searchResults: LifeManagementSearchResults
    }

    static func build(
        lifeAreas: [LifeArea],
        projectStats: [ProjectWithStats],
        habitRows: [HabitLibraryRow],
        selectedScope: LifeManagementScope,
        selectedHabitFilter: LifeManagementHabitFilter,
        searchQuery: String,
        generalLifeAreaID: UUID?
    ) -> Snapshot {
        let areasByID = Dictionary(uniqueKeysWithValues: lifeAreas.map { ($0.id, $0) })

        let projectRows = projectStats.map { entry in
            let resolvedAreaID = entry.project.lifeAreaID ?? generalLifeAreaID
            return LifeManagementProjectRow(
                project: entry.project,
                taskCount: entry.taskCount,
                lifeArea: resolvedAreaID.flatMap { areasByID[$0] },
                linkedHabitCount: habitRows.filter { $0.projectID == entry.project.id && $0.isArchived == false }.count
            )
        }

        let projectsByID = Dictionary(uniqueKeysWithValues: projectRows.map { ($0.project.id, $0.project) })
        let habitViewRows = habitRows.map { row in
            LifeManagementHabitRow(
                row: row,
                lifeArea: row.lifeAreaID.flatMap { areasByID[$0] },
                project: row.projectID.flatMap { projectsByID[$0] }
            )
        }

        let activeAreas = sortAreas(lifeAreas.filter { $0.isArchived == false })
        let archivedAreas = sortAreas(lifeAreas.filter(\.isArchived))

        let activeAreaRows = activeAreas.map { area in
            buildAreaRow(area: area, projectRows: projectRows, habitRows: habitViewRows)
        }

        let activeProjects = sortProjectRows(projectRows.filter { row in
            row.project.isArchived == false && row.lifeArea?.isArchived != true
        })
        let archivedProjects = sortProjectRows(projectRows.filter { row in
            row.project.isArchived || row.lifeArea?.isArchived == true
        })
        let activeHabits = sortHabitRows(habitViewRows.filter { row in
            row.row.isArchived == false && row.lifeArea?.isArchived != true
        })
        let archivedHabits = sortHabitRows(habitViewRows.filter { row in
            row.row.isArchived || row.lifeArea?.isArchived == true
        })

        let filteredActiveHabits = filteredHabits(activeHabits, filter: selectedHabitFilter)
        let projectGroups = groupProjects(activeProjects, activeAreas: activeAreas)
        let habitGroups = groupHabits(filteredActiveHabits, activeAreas: activeAreas)

        let archiveSections = LifeManagementArchiveSections(
            areas: archivedAreas.map { buildAreaRow(area: $0, projectRows: projectRows, habitRows: habitViewRows) },
            projects: groupProjects(archivedProjects, activeAreas: sortAreas(lifeAreas)),
            habits: groupHabits(archivedHabits, activeAreas: sortAreas(lifeAreas))
        )

        let overview = buildOverview(
            areaRows: activeAreaRows,
            activeProjects: activeProjects,
            activeHabits: activeHabits,
            archivedAreas: archiveSections.areas,
            archivedProjects: archivedProjects,
            archivedHabits: archivedHabits
        )

        let searchResults: LifeManagementSearchResults
        if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            searchResults = .empty
        } else if selectedScope == .archive {
            searchResults = LifeManagementSearchResults(
                areas: archiveSections.areas.filter { matchesSearch(areaRow: $0, query: searchQuery) },
                projects: archivedProjects.filter { matchesSearch(projectRow: $0, query: searchQuery) },
                habits: archivedHabits.filter { matchesSearch(habitRow: $0, query: searchQuery) }
            )
        } else {
            searchResults = LifeManagementSearchResults(
                areas: activeAreaRows.filter { matchesSearch(areaRow: $0, query: searchQuery) },
                projects: activeProjects.filter { matchesSearch(projectRow: $0, query: searchQuery) },
                habits: activeHabits.filter { matchesSearch(habitRow: $0, query: searchQuery) }
            )
        }

        return Snapshot(
            overview: overview,
            areaRows: activeAreaRows,
            projectGroups: projectGroups,
            habitGroups: habitGroups,
            archiveSections: archiveSections,
            searchResults: searchResults
        )
    }

    private static func buildOverview(
        areaRows: [LifeManagementAreaRow],
        activeProjects: [LifeManagementProjectRow],
        activeHabits: [LifeManagementHabitRow],
        archivedAreas: [LifeManagementAreaRow],
        archivedProjects: [LifeManagementProjectRow],
        archivedHabits: [LifeManagementHabitRow]
    ) -> LifeManagementOverview {
        var attentionItems: [LifeManagementAttentionItem] = []

        let emptyProjects = activeProjects.filter { $0.isInbox == false && $0.taskCount == 0 }
        if emptyProjects.isEmpty == false {
            attentionItems.append(
                LifeManagementAttentionItem(
                    kind: .emptyProject,
                    title: "\(emptyProjects.count) empty project\(emptyProjects.count == 1 ? "" : "s")",
                    detail: "Projects with no open tasks are easiest to clean up here.",
                    symbolName: "tray"
                )
            )
        }

        let pausedHabits = activeHabits.filter(\.row.isPaused)
        if pausedHabits.isEmpty == false {
            attentionItems.append(
                LifeManagementAttentionItem(
                    kind: .pausedHabit,
                    title: "\(pausedHabits.count) paused habit\(pausedHabits.count == 1 ? "" : "s")",
                    detail: "Paused habits stay recoverable, but still need a structural decision.",
                    symbolName: "pause.circle"
                )
            )
        }

        let archivedCount = archivedAreas.count + archivedProjects.count + archivedHabits.count
        if archivedCount > 0 {
            attentionItems.append(
                LifeManagementAttentionItem(
                    kind: .archivedItem,
                    title: "\(archivedCount) archived item\(archivedCount == 1 ? "" : "s")",
                    detail: "Restore what still matters. Delete what is finished for good.",
                    symbolName: "archivebox"
                )
            )
        }

        let stats = [
            LifeManagementOverviewStat(title: "Areas", value: "\(areaRows.count)", symbolName: "square.grid.2x2"),
            LifeManagementOverviewStat(title: "Projects", value: "\(activeProjects.count)", symbolName: "folder"),
            LifeManagementOverviewStat(title: "Habits", value: "\(activeHabits.count)", symbolName: "repeat")
        ]

        let topAreas = Array(areaRows.sorted { lhs, rhs in
            if lhs.projectCount != rhs.projectCount { return lhs.projectCount > rhs.projectCount }
            if lhs.habitCount != rhs.habitCount { return lhs.habitCount > rhs.habitCount }
            return lhs.lifeArea.name.localizedCaseInsensitiveCompare(rhs.lifeArea.name) == .orderedAscending
        }.prefix(4))

        return LifeManagementOverview(
            stats: stats,
            attentionItems: attentionItems,
            topAreas: topAreas,
            attentionProjects: Array(emptyProjects.prefix(4)),
            attentionHabits: Array(pausedHabits.prefix(4))
        )
    }

    private static func buildAreaRow(
        area: LifeArea,
        projectRows: [LifeManagementProjectRow],
        habitRows: [LifeManagementHabitRow]
    ) -> LifeManagementAreaRow {
        let areaProjects = projectRows.filter { $0.project.lifeAreaID == area.id }
        let areaHabits = habitRows.filter { $0.row.lifeAreaID == area.id }
        return LifeManagementAreaRow(
            lifeArea: area,
            projectCount: areaProjects.filter { $0.project.isArchived == false }.count,
            habitCount: areaHabits.filter { $0.row.isArchived == false }.count,
            taskCount: areaProjects.filter { $0.project.isArchived == false }.reduce(0) { $0 + $1.taskCount },
            isGeneral: normalizedAreaName(area.name) == LifeManagementConstants.generalNormalizedName
        )
    }

    private static func groupProjects(
        _ rows: [LifeManagementProjectRow],
        activeAreas: [LifeArea]
    ) -> [LifeManagementProjectGroup] {
        let grouped = Dictionary(grouping: rows) { row in
            row.lifeArea?.id
        }

        var results: [LifeManagementProjectGroup] = activeAreas.compactMap { area in
            guard let rows = grouped[area.id], rows.isEmpty == false else { return nil }
            return LifeManagementProjectGroup(lifeArea: area, title: area.name, rows: sortProjectRows(rows))
        }

        if let unassigned = grouped[nil], unassigned.isEmpty == false {
            results.append(
                LifeManagementProjectGroup(
                    lifeArea: nil,
                    title: "No Area",
                    rows: sortProjectRows(unassigned)
                )
            )
        }

        return results
    }

    private static func groupHabits(
        _ rows: [LifeManagementHabitRow],
        activeAreas: [LifeArea]
    ) -> [LifeManagementHabitGroup] {
        let grouped = Dictionary(grouping: rows) { row in
            row.row.lifeAreaID
        }

        var results: [LifeManagementHabitGroup] = activeAreas.compactMap { area in
            guard let rows = grouped[area.id], rows.isEmpty == false else { return nil }
            return LifeManagementHabitGroup(lifeArea: area, title: area.name, rows: sortHabitRows(rows))
        }

        if let unassigned = grouped[nil], unassigned.isEmpty == false {
            results.append(
                LifeManagementHabitGroup(
                    lifeArea: nil,
                    title: "No Area",
                    rows: sortHabitRows(unassigned)
                )
            )
        }

        return results
    }

    private static func filteredHabits(
        _ rows: [LifeManagementHabitRow],
        filter: LifeManagementHabitFilter
    ) -> [LifeManagementHabitRow] {
        switch filter {
        case .all:
            return rows
        case .build:
            return rows.filter { $0.row.kind == .positive }
        case .quit:
            return rows.filter { $0.row.kind == .negative }
        case .paused:
            return rows.filter(\.row.isPaused)
        }
    }

    private static func sortAreas(_ areas: [LifeArea]) -> [LifeArea] {
        areas.sorted { lhs, rhs in
            let lhsIsGeneral = normalizedAreaName(lhs.name) == LifeManagementConstants.generalNormalizedName
            let rhsIsGeneral = normalizedAreaName(rhs.name) == LifeManagementConstants.generalNormalizedName
            if lhsIsGeneral != rhsIsGeneral {
                return lhsIsGeneral
            }
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private static func sortProjectRows(_ rows: [LifeManagementProjectRow]) -> [LifeManagementProjectRow] {
        rows.sorted { lhs, rhs in
            if lhs.isInbox != rhs.isInbox { return lhs.isInbox }
            if lhs.taskCount != rhs.taskCount { return lhs.taskCount > rhs.taskCount }
            return lhs.project.name.localizedCaseInsensitiveCompare(rhs.project.name) == .orderedAscending
        }
    }

    private static func sortHabitRows(_ rows: [LifeManagementHabitRow]) -> [LifeManagementHabitRow] {
        rows.sorted { lhs, rhs in
            if lhs.row.isPaused != rhs.row.isPaused { return rhs.row.isPaused == false }
            if lhs.row.currentStreak != rhs.row.currentStreak { return lhs.row.currentStreak > rhs.row.currentStreak }
            return lhs.row.title.localizedCaseInsensitiveCompare(rhs.row.title) == .orderedAscending
        }
    }

    private static func matchesSearch(areaRow: LifeManagementAreaRow, query: String) -> Bool {
        let searchable = [
            areaRow.lifeArea.name,
            areaRow.lifeArea.color ?? "",
            areaRow.lifeArea.icon ?? "",
            "\(areaRow.projectCount) projects",
            "\(areaRow.habitCount) habits"
        ]
        return matchesSearch(searchable: searchable, query: query)
    }

    private static func matchesSearch(projectRow: LifeManagementProjectRow, query: String) -> Bool {
        let searchable = [
            projectRow.project.name,
            projectRow.project.projectDescription ?? "",
            projectRow.lifeArea?.name ?? "",
            projectRow.project.color.displayName,
            projectRow.project.icon.displayName,
            "\(projectRow.taskCount) tasks"
        ]
        return matchesSearch(searchable: searchable, query: query)
    }

    private static func matchesSearch(habitRow: LifeManagementHabitRow, query: String) -> Bool {
        let searchable = [
            habitRow.row.title,
            habitRow.row.lifeAreaName,
            habitRow.row.projectName ?? "",
            habitRow.row.notes ?? "",
            habitRow.row.icon?.symbolName ?? "",
            habitRow.row.kind == .positive ? "build" : "quit",
            habitRow.row.isPaused ? "paused" : "active"
        ]
        return matchesSearch(searchable: searchable, query: query)
    }

    private static func matchesSearch(searchable: [String], query: String) -> Bool {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalizedQuery.isEmpty == false else { return true }
        return searchable.contains { $0.lowercased().contains(normalizedQuery) }
    }

    private static func normalizedAreaName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed.isEmpty ? LifeManagementConstants.generalDisplayName : trimmed).lowercased()
    }
}

@MainActor
public final class LifeManagementViewModel: ObservableObject {
    @Published public var selectedScope: LifeManagementScope = .overview {
        didSet { rebuildDerivedState() }
    }
    @Published public var searchQuery = "" {
        didSet { rebuildDerivedState() }
    }
    @Published public var selectedHabitFilter: LifeManagementHabitFilter = .all {
        didSet { rebuildDerivedState() }
    }
    @Published public private(set) var overview: LifeManagementOverview = .empty
    @Published public private(set) var areaRows: [LifeManagementAreaRow] = []
    @Published public private(set) var projectGroups: [LifeManagementProjectGroup] = []
    @Published public private(set) var habitGroups: [LifeManagementHabitGroup] = []
    @Published public private(set) var archiveSections: LifeManagementArchiveSections = .empty
    @Published public private(set) var searchResults: LifeManagementSearchResults = .empty
    @Published public private(set) var isLoading = false
    @Published public private(set) var isMutating = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var draggingProjectID: UUID?
    @Published public private(set) var activeDropLifeAreaID: UUID?
    @Published var snackbar: SnackbarData?
    @Published public var lifeAreaDraft: LifeManagementLifeAreaDraft?
    @Published public var projectDraft: LifeManagementProjectDraft?
    @Published public var moveProjectDraft: LifeManagementProjectMoveDraft?
    @Published public var deleteAreaDraft: LifeManagementDeleteAreaDraft?
    @Published public var deleteProjectDraft: LifeManagementDeleteProjectDraft?
    @Published public var deleteHabitDraft: LifeManagementDeleteHabitDraft?

    public let lifeAreaIconCatalog: [LifeAreaIconOption] = [
        LifeAreaIconOption(symbolName: "square.grid.2x2", keywords: ["general", "default", "grid"]),
        LifeAreaIconOption(symbolName: "heart.fill", keywords: ["health", "fitness", "wellness"]),
        LifeAreaIconOption(symbolName: "briefcase.fill", keywords: ["career", "work", "job"]),
        LifeAreaIconOption(symbolName: "book.fill", keywords: ["learning", "study", "education"]),
        LifeAreaIconOption(symbolName: "dumbbell.fill", keywords: ["gym", "exercise", "fitness"]),
        LifeAreaIconOption(symbolName: "leaf.fill", keywords: ["mindfulness", "nature", "calm"]),
        LifeAreaIconOption(symbolName: "brain.head.profile", keywords: ["focus", "thinking", "mind"]),
        LifeAreaIconOption(symbolName: "figure.run", keywords: ["running", "sports", "cardio"]),
        LifeAreaIconOption(symbolName: "fork.knife", keywords: ["nutrition", "food", "diet"]),
        LifeAreaIconOption(symbolName: "moon.stars.fill", keywords: ["sleep", "rest", "night"]),
        LifeAreaIconOption(symbolName: "house.fill", keywords: ["home", "family", "household"]),
        LifeAreaIconOption(symbolName: "person.2.fill", keywords: ["relationships", "friends", "social"]),
        LifeAreaIconOption(symbolName: "paintpalette.fill", keywords: ["creative", "art", "design"]),
        LifeAreaIconOption(symbolName: "chart.line.uptrend.xyaxis", keywords: ["growth", "progress", "improvement"]),
        LifeAreaIconOption(symbolName: "dollarsign.circle.fill", keywords: ["finance", "money", "budget"]),
        LifeAreaIconOption(symbolName: "airplane", keywords: ["travel", "trip", "vacation"]),
        LifeAreaIconOption(symbolName: "sparkles", keywords: ["personal", "self", "improvement"]),
        LifeAreaIconOption(symbolName: "flag.fill", keywords: ["goals", "milestones", "targets"]),
        LifeAreaIconOption(symbolName: "star.fill", keywords: ["priorities", "important", "highlight"]),
        LifeAreaIconOption(symbolName: "bolt.fill", keywords: ["execution", "action", "momentum"]),
        LifeAreaIconOption(symbolName: "tray.full.fill", keywords: ["inbox", "capture", "intake"]),
        LifeAreaIconOption(symbolName: "wrench.and.screwdriver.fill", keywords: ["maintenance", "ops", "repairs"])
    ]

    private let useCaseCoordinator: UseCaseCoordinator
    private let manageLifeAreasUseCase: ManageLifeAreasUseCase
    private let manageProjectsUseCase: ManageProjectsUseCase
    private let destructiveFlowCoordinator: LifeManagementDestructiveFlowCoordinator
    private let projectRepository: ProjectRepositoryProtocol
    private let lifeAreaRepository: LifeAreaRepositoryProtocol

    private var sourceLifeAreas: [LifeArea] = []
    private var sourceProjectStats: [ProjectWithStats] = []
    private var sourceHabitRows: [HabitLibraryRow] = []
    private var generalLifeAreaID: UUID?
    private var hasLoadedOnce = false
    private var hasPerformedBackfill = false
    private var pendingUndoAction: LifeManagementUndoAction?

    /// Initializes a new instance.
    public init(
        useCaseCoordinator: UseCaseCoordinator,
        projectRepository: ProjectRepositoryProtocol? = nil
    ) {
        self.useCaseCoordinator = useCaseCoordinator
        self.manageLifeAreasUseCase = useCaseCoordinator.manageLifeAreas
        self.manageProjectsUseCase = useCaseCoordinator.manageProjects
        self.destructiveFlowCoordinator = useCaseCoordinator.lifeManagementDestructiveFlow
        self.projectRepository = projectRepository ?? useCaseCoordinator.projectRepository
        self.lifeAreaRepository = useCaseCoordinator.lifeAreaRepository
    }

    /// Executes loadIfNeeded.
    public func loadIfNeeded() {
        guard hasLoadedOnce == false else { return }
        hasLoadedOnce = true
        Task {
            await load(runBackfill: true, showsLoading: true)
        }
    }

    /// Executes reload.
    public func reload() {
        Task {
            await load(runBackfill: hasPerformedBackfill == false, showsLoading: true)
        }
    }

    /// Executes clearError.
    public func clearError() {
        errorMessage = nil
    }

    /// Executes filteredIconOptions.
    public func filteredIconOptions(query: String) -> [LifeAreaIconOption] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.isEmpty == false else { return lifeAreaIconCatalog }
        return lifeAreaIconCatalog.filter { option in
            option.symbolName.lowercased().contains(normalized) ||
            option.keywords.contains(where: { $0.lowercased().contains(normalized) })
        }
    }

    /// Executes beginCreateLifeArea.
    public func beginCreateLifeArea(prefillName: String = "") {
        lifeAreaDraft = LifeManagementLifeAreaDraft(
            existingID: nil,
            name: prefillName,
            colorHex: LifeAreaConstants.generalSeedColor,
            iconSymbolName: "square.grid.2x2"
        )
    }

    /// Executes beginEditLifeArea.
    public func beginEditLifeArea(_ lifeAreaID: UUID) {
        guard let area = sourceLifeAreas.first(where: { $0.id == lifeAreaID }) else { return }
        lifeAreaDraft = LifeManagementLifeAreaDraft(
            existingID: area.id,
            name: area.name,
            colorHex: area.color ?? "",
            iconSymbolName: area.icon ?? "square.grid.2x2"
        )
    }

    /// Executes dismissLifeAreaDraft.
    public func dismissLifeAreaDraft() {
        lifeAreaDraft = nil
    }

    /// Executes saveLifeAreaDraft.
    public func saveLifeAreaDraft() {
        guard let draft = lifeAreaDraft else { return }
        performMutation {
            let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedName.isEmpty == false else {
                throw NSError(
                    domain: "LifeManagementViewModel",
                    code: 400,
                    userInfo: [NSLocalizedDescriptionKey: "Enter a name for the life area."]
                )
            }

            if let existingID = draft.existingID {
                _ = try await self.awaitResult { completion in
                    self.manageLifeAreasUseCase.update(
                        id: existingID,
                        name: trimmedName,
                        color: draft.colorHex.nilIfBlank,
                        icon: draft.iconSymbolName.nilIfBlank,
                        completion: completion
                    )
                }
            } else {
                _ = try await self.awaitResult { completion in
                    self.manageLifeAreasUseCase.create(
                        name: trimmedName,
                        color: draft.colorHex.nilIfBlank,
                        icon: draft.iconSymbolName.nilIfBlank,
                        completion: completion
                    )
                }
            }
            self.lifeAreaDraft = nil
            self.snackbar = SnackbarData(message: draft.isNew ? "Area added" : "Area updated")
        }
    }

    /// Executes beginCreateProject.
    public func beginCreateProject(prefillLifeAreaID: UUID? = nil) {
        projectDraft = LifeManagementProjectDraft(
            existingID: nil,
            name: "",
            description: "",
            lifeAreaID: prefillLifeAreaID ?? generalLifeAreaID ?? areaRows.first?.id,
            color: .blue,
            icon: .folder
        )
    }

    /// Executes beginEditProject.
    public func beginEditProject(_ projectID: UUID) {
        guard let row = projectRow(for: projectID) else { return }
        projectDraft = LifeManagementProjectDraft(
            existingID: row.project.id,
            name: row.project.name,
            description: row.project.projectDescription ?? "",
            lifeAreaID: row.project.lifeAreaID ?? generalLifeAreaID,
            color: row.project.color,
            icon: row.project.icon
        )
    }

    /// Executes dismissProjectDraft.
    public func dismissProjectDraft() {
        projectDraft = nil
    }

    /// Executes saveProjectDraft.
    public func saveProjectDraft() {
        guard let draft = projectDraft else { return }
        performMutation {
            let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedName.isEmpty == false else {
                throw NSError(
                    domain: "LifeManagementViewModel",
                    code: 400,
                    userInfo: [NSLocalizedDescriptionKey: "Enter a name for the project."]
                )
            }

            let description = draft.description.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
            if let existingID = draft.existingID {
                let originalProject = try await self.awaitResult { completion in
                    self.projectRepository.fetchProject(withId: existingID) { result in
                        completion(result)
                    }
                }
                guard let originalProject else {
                    throw NSError(
                        domain: "LifeManagementViewModel",
                        code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "The project could not be found."]
                    )
                }

                _ = try await self.awaitProjectResult { completion in
                    self.manageProjectsUseCase.updateProject(
                        projectId: existingID,
                        request: UpdateProjectRequest(
                            name: trimmedName,
                            description: description,
                            color: draft.color,
                            icon: draft.icon
                        ),
                        completion: completion
                    )
                }

                let currentLifeAreaID = originalProject.lifeAreaID ?? self.generalLifeAreaID
                if draft.lifeAreaID != currentLifeAreaID, let targetAreaID = draft.lifeAreaID {
                    do {
                        _ = try await self.awaitProjectResult { completion in
                            self.manageProjectsUseCase.moveProjectToLifeArea(
                                projectId: existingID,
                                lifeAreaID: targetAreaID,
                                completion: completion
                            )
                        }
                    } catch {
                        do {
                            _ = try await self.awaitProjectResult { completion in
                                self.manageProjectsUseCase.updateProject(
                                    projectId: existingID,
                                    request: UpdateProjectRequest(
                                        name: originalProject.name,
                                        description: originalProject.projectDescription,
                                        color: originalProject.color,
                                        icon: originalProject.icon
                                    ),
                                    completion: completion
                                )
                            }

                            let currentProject = try await self.awaitResult { completion in
                                self.projectRepository.fetchProject(withId: existingID) { result in
                                    completion(result)
                                }
                            }
                            if let originalLifeAreaID = originalProject.lifeAreaID,
                               currentProject?.lifeAreaID != originalLifeAreaID {
                                _ = try await self.awaitProjectResult { completion in
                                    self.manageProjectsUseCase.moveProjectToLifeArea(
                                        projectId: existingID,
                                        lifeAreaID: originalLifeAreaID,
                                        completion: completion
                                    )
                                }
                            }
                        } catch let rollbackError {
                            throw LifeManagementMutationError.projectMoveRollbackFailed(
                                moveError: error,
                                rollbackError: rollbackError
                            )
                        }

                        throw LifeManagementMutationError.projectMoveRolledBack(moveError: error)
                    }
                }
            } else {
                _ = try await self.awaitProjectResult { completion in
                    self.manageProjectsUseCase.createProject(
                        request: CreateProjectRequest(
                            name: trimmedName,
                            description: description,
                            lifeAreaID: draft.lifeAreaID,
                            color: draft.color,
                            icon: draft.icon
                        ),
                        completion: completion
                    )
                }
            }
            self.projectDraft = nil
            self.snackbar = SnackbarData(message: draft.isNew ? "Project added" : "Project updated")
        }
    }

    /// Executes beginMoveProject.
    public func beginMoveProject(_ projectID: UUID) {
        guard let row = projectRow(for: projectID), row.isMoveLocked == false else { return }
        let fallbackTarget = availableAreaTargets(excluding: row.lifeArea?.id).first?.id
        moveProjectDraft = LifeManagementProjectMoveDraft(
            id: UUID(),
            projectID: projectID,
            projectName: row.project.name,
            targetLifeAreaID: fallbackTarget
        )
    }

    /// Executes dismissMoveProjectDraft.
    public func dismissMoveProjectDraft() {
        moveProjectDraft = nil
    }

    /// Executes moveProjectFromDraft.
    public func moveProjectFromDraft() {
        guard let draft = moveProjectDraft, let targetLifeAreaID = draft.targetLifeAreaID else { return }
        performMutation {
            _ = try await self.awaitProjectResult { completion in
                self.manageProjectsUseCase.moveProjectToLifeArea(
                    projectId: draft.projectID,
                    lifeAreaID: targetLifeAreaID,
                    completion: completion
                )
            }
            self.moveProjectDraft = nil
        }
    }

    /// Executes beginDeleteArea.
    public func beginDeleteArea(_ lifeAreaID: UUID) {
        guard let area = sourceLifeAreas.first(where: { $0.id == lifeAreaID }), isGeneralArea(area) == false else { return }
        let defaultTarget = availableAreaTargets(excluding: lifeAreaID).first?.id
        deleteAreaDraft = LifeManagementDeleteAreaDraft(
            id: UUID(),
            areaID: area.id,
            areaName: area.name,
            projectCount: projects(inLifeArea: area.id).count,
            habitCount: habits(inLifeArea: area.id).count,
            destinationLifeAreaID: defaultTarget
        )
    }

    /// Executes dismissDeleteAreaDraft.
    public func dismissDeleteAreaDraft() {
        deleteAreaDraft = nil
    }

    /// Executes confirmDeleteArea.
    public func confirmDeleteArea() {
        guard let draft = deleteAreaDraft else { return }
        performMutation {
            guard let destinationLifeAreaID = draft.destinationLifeAreaID, destinationLifeAreaID != draft.areaID else {
                throw NSError(
                    domain: "LifeManagementViewModel",
                    code: 400,
                    userInfo: [NSLocalizedDescriptionKey: "Choose a destination area before deleting this area."]
                )
            }

            _ = try await self.awaitVoid { completion in
                self.destructiveFlowCoordinator.deleteLifeArea(
                    request: DeleteLifeAreaRequest(
                        areaID: draft.areaID,
                        destinationLifeAreaID: destinationLifeAreaID,
                        projects: self.projects(inLifeArea: draft.areaID).map(\.project),
                        habits: self.habits(inLifeArea: draft.areaID).map(\.row)
                    ),
                    completion: completion
                )
            }

            self.deleteAreaDraft = nil
        }
    }

    /// Executes beginDeleteProject.
    public func beginDeleteProject(_ projectID: UUID) {
        guard let row = projectRow(for: projectID), row.project.isDefault == false else { return }
        let fallbackProjectID = availableProjectDeleteTargets(excluding: projectID).first?.id
        deleteProjectDraft = LifeManagementDeleteProjectDraft(
            id: UUID(),
            projectID: projectID,
            projectName: row.project.name,
            taskCount: row.taskCount,
            linkedHabitCount: projectHabits(projectID: projectID).count,
            destinationProjectID: fallbackProjectID
        )
    }

    /// Executes dismissDeleteProjectDraft.
    public func dismissDeleteProjectDraft() {
        deleteProjectDraft = nil
    }

    /// Executes confirmDeleteProject.
    public func confirmDeleteProject() {
        guard let draft = deleteProjectDraft else { return }
        performMutation {
            guard let destinationProjectID = draft.destinationProjectID, destinationProjectID != draft.projectID else {
                throw NSError(
                    domain: "LifeManagementViewModel",
                    code: 400,
                    userInfo: [NSLocalizedDescriptionKey: "Choose a destination project before deleting this project."]
                )
            }

            _ = try await self.awaitVoid { completion in
                self.destructiveFlowCoordinator.deleteProject(
                    request: DeleteProjectRequest(
                        projectID: draft.projectID,
                        destinationProjectID: destinationProjectID,
                        linkedHabitIDs: self.projectHabits(projectID: draft.projectID).map(\.row.habitID)
                    ),
                    completion: completion
                )
            }

            self.deleteProjectDraft = nil
        }
    }

    /// Executes beginDeleteHabit.
    public func beginDeleteHabit(_ habitID: UUID) {
        guard let row = habitRow(for: habitID) else { return }
        deleteHabitDraft = LifeManagementDeleteHabitDraft(
            id: UUID(),
            habitID: habitID,
            habitTitle: row.row.title
        )
    }

    /// Executes dismissDeleteHabitDraft.
    public func dismissDeleteHabitDraft() {
        deleteHabitDraft = nil
    }

    /// Executes confirmDeleteHabit.
    public func confirmDeleteHabit() {
        guard let draft = deleteHabitDraft else { return }
        performMutation {
            _ = try await self.awaitVoid { completion in
                self.useCaseCoordinator.deleteHabit.execute(id: draft.habitID, completion: completion)
            }
            self.deleteHabitDraft = nil
        }
    }

    /// Executes archiveLifeArea.
    public func archiveLifeArea(_ lifeAreaID: UUID) {
        guard let row = areaRow(for: lifeAreaID), row.isGeneral == false else { return }
        performMutation {
            _ = try await self.awaitResult { completion in
                self.manageLifeAreasUseCase.archive(id: lifeAreaID, completion: completion)
            }
            self.presentArchiveUndo(message: "\(row.lifeArea.name) archived", action: .lifeArea(lifeAreaID))
        }
    }

    /// Executes restoreLifeArea.
    public func restoreLifeArea(_ lifeAreaID: UUID) {
        performMutation {
            _ = try await self.awaitResult { completion in
                self.manageLifeAreasUseCase.unarchive(id: lifeAreaID, completion: completion)
            }
        }
    }

    /// Executes archiveProject.
    public func archiveProject(_ projectID: UUID) {
        guard let row = projectRow(for: projectID), row.isInbox == false else { return }
        performMutation {
            _ = try await self.awaitProjectResult { completion in
                self.manageProjectsUseCase.archiveProject(projectId: projectID, completion: completion)
            }
            self.presentArchiveUndo(message: "\(row.project.name) archived", action: .project(projectID))
        }
    }

    /// Executes restoreProject.
    public func restoreProject(_ projectID: UUID) {
        performMutation {
            _ = try await self.awaitProjectResult { completion in
                self.manageProjectsUseCase.unarchiveProject(projectId: projectID, completion: completion)
            }
        }
    }

    /// Executes archiveHabit.
    public func archiveHabit(_ habitID: UUID) {
        guard let row = habitRow(for: habitID) else { return }
        performMutation {
            _ = try await self.awaitResult { completion in
                self.useCaseCoordinator.setHabitArchived.execute(id: habitID, isArchived: true, completion: completion)
            }
            self.presentArchiveUndo(message: "\(row.row.title) archived", action: .habit(habitID))
        }
    }

    /// Executes restoreHabit.
    public func restoreHabit(_ habitID: UUID) {
        performMutation {
            _ = try await self.awaitResult { completion in
                self.useCaseCoordinator.setHabitArchived.execute(id: habitID, isArchived: false, completion: completion)
            }
        }
    }

    /// Executes toggleHabitPause.
    public func toggleHabitPause(_ habitID: UUID) {
        guard let row = habitRow(for: habitID) else { return }
        performMutation {
            _ = try await self.awaitResult { completion in
                self.useCaseCoordinator.pauseHabit.execute(
                    id: habitID,
                    isPaused: row.row.isPaused == false,
                    completion: completion
                )
            }
        }
    }

    /// Executes undoArchive.
    public func undoArchive() {
        guard let pendingUndoAction else { return }
        self.pendingUndoAction = nil
        snackbar = nil
        switch pendingUndoAction {
        case .lifeArea(let id):
            restoreLifeArea(id)
        case .project(let id):
            restoreProject(id)
        case .habit(let id):
            restoreHabit(id)
        }
    }

    /// Executes areaRow.
    public func areaRow(for lifeAreaID: UUID) -> LifeManagementAreaRow? {
        areaRows.first(where: { $0.id == lifeAreaID }) ??
        archiveSections.areas.first(where: { $0.id == lifeAreaID })
    }

    /// Executes projectRow.
    public func projectRow(for projectID: UUID) -> LifeManagementProjectRow? {
        for group in projectGroups where group.rows.contains(where: { $0.id == projectID }) {
            return group.rows.first(where: { $0.id == projectID })
        }
        for group in archiveSections.projects where group.rows.contains(where: { $0.id == projectID }) {
            return group.rows.first(where: { $0.id == projectID })
        }
        return nil
    }

    /// Executes habitRow.
    public func habitRow(for habitID: UUID) -> LifeManagementHabitRow? {
        for group in habitGroups where group.rows.contains(where: { $0.id == habitID }) {
            return group.rows.first(where: { $0.id == habitID })
        }
        for group in archiveSections.habits where group.rows.contains(where: { $0.id == habitID }) {
            return group.rows.first(where: { $0.id == habitID })
        }
        return nil
    }

    /// Executes projectsInArea.
    public func projects(inLifeArea lifeAreaID: UUID) -> [LifeManagementProjectRow] {
        sourceProjectStats.compactMap { entry in
            guard (entry.project.lifeAreaID ?? generalLifeAreaID) == lifeAreaID else { return nil }
            let lifeArea = sourceLifeAreas.first(where: { $0.id == lifeAreaID })
            return LifeManagementProjectRow(
                project: entry.project,
                taskCount: entry.taskCount,
                lifeArea: lifeArea,
                linkedHabitCount: sourceHabitRows.filter { $0.projectID == entry.project.id && $0.isArchived == false }.count
            )
        }.sorted { lhs, rhs in
            lhs.project.name.localizedCaseInsensitiveCompare(rhs.project.name) == .orderedAscending
        }
    }

    /// Executes habitsInArea.
    public func habits(inLifeArea lifeAreaID: UUID) -> [LifeManagementHabitRow] {
        sourceHabitRows.compactMap { row in
            guard row.lifeAreaID == lifeAreaID else { return nil }
            return LifeManagementHabitRow(
                row: row,
                lifeArea: sourceLifeAreas.first(where: { $0.id == lifeAreaID }),
                project: row.projectID.flatMap { self.projectRow(for: $0)?.project }
            )
        }.sorted { lhs, rhs in
            lhs.row.title.localizedCaseInsensitiveCompare(rhs.row.title) == .orderedAscending
        }
    }

    /// Executes projectHabits.
    public func projectHabits(projectID: UUID) -> [LifeManagementHabitRow] {
        sourceHabitRows.compactMap { row in
            guard row.projectID == projectID else { return nil }
            return LifeManagementHabitRow(
                row: row,
                lifeArea: row.lifeAreaID.flatMap { id in sourceLifeAreas.first(where: { $0.id == id }) },
                project: projectRow(for: projectID)?.project
            )
        }.sorted { lhs, rhs in
            lhs.row.title.localizedCaseInsensitiveCompare(rhs.row.title) == .orderedAscending
        }
    }

    /// Executes availableAreaTargets.
    public func availableAreaTargets(excluding lifeAreaID: UUID?) -> [LifeManagementAreaRow] {
        areaRows.filter { row in
            row.id != lifeAreaID && row.lifeArea.isArchived == false
        }
    }

    /// Executes availableProjectDeleteTargets.
    public func availableProjectDeleteTargets(excluding projectID: UUID?) -> [LifeManagementProjectRow] {
        projectGroups
            .flatMap(\.rows)
            .filter { row in
                row.id != projectID && row.project.isArchived == false
            }
            .sorted { lhs, rhs in
                if lhs.isInbox != rhs.isInbox { return lhs.isInbox }
                return lhs.project.name.localizedCaseInsensitiveCompare(rhs.project.name) == .orderedAscending
            }
    }

    /// Executes beginProjectDrag.
    public func beginProjectDrag(_ projectID: UUID) -> NSItemProvider {
        draggingProjectID = projectID
        return NSItemProvider(object: projectID.uuidString as NSString)
    }

    /// Executes setDropTarget.
    public func setDropTarget(_ lifeAreaID: UUID?) {
        activeDropLifeAreaID = lifeAreaID
    }

    /// Executes handleProjectDrop.
    public func handleProjectDrop(providers: [NSItemProvider], targetLifeAreaID: UUID) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else {
            resetDragState()
            return false
        }

        provider.loadObject(ofClass: NSString.self) { [weak self] object, _ in
            guard let self, let value = object as? NSString, let projectID = UUID(uuidString: value as String) else {
                Task { @MainActor in
                    self?.resetDragState()
                }
                return
            }
            Task { @MainActor in
                self.performMutation {
                    _ = try await self.awaitProjectResult { completion in
                        self.manageProjectsUseCase.moveProjectToLifeArea(
                            projectId: projectID,
                            lifeAreaID: targetLifeAreaID,
                            completion: completion
                        )
                    }
                    self.resetDragState()
                }
            }
        }
        return true
    }

    private func rebuildDerivedState() {
        let snapshot = LifeManagementProjection.build(
            lifeAreas: sourceLifeAreas,
            projectStats: sourceProjectStats,
            habitRows: sourceHabitRows,
            selectedScope: selectedScope,
            selectedHabitFilter: selectedHabitFilter,
            searchQuery: searchQuery,
            generalLifeAreaID: generalLifeAreaID
        )
        overview = snapshot.overview
        areaRows = snapshot.areaRows
        projectGroups = snapshot.projectGroups
        habitGroups = snapshot.habitGroups
        archiveSections = snapshot.archiveSections
        searchResults = snapshot.searchResults
    }

    private func presentArchiveUndo(message: String, action: LifeManagementUndoAction) {
        pendingUndoAction = action
        snackbar = SnackbarData(
            message: message,
            actions: [
                SnackbarAction(title: "Undo") { [weak self] in
                    self?.undoArchive()
                }
            ]
        )
    }

    private func performMutation(_ operation: @escaping () async throws -> Void) {
        guard isMutating == false else { return }
        isMutating = true
        errorMessage = nil

        Task { [weak self] in
            guard let self else { return }
            defer { self.isMutating = false }

            do {
                try await operation()
                await self.load(runBackfill: false, showsLoading: false)
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func load(runBackfill: Bool, showsLoading: Bool) async {
        if showsLoading {
            isLoading = true
        }
        errorMessage = nil

        do {
            let listedAreas = try await awaitResult { completion in
                self.manageLifeAreasUseCase.list(completion: completion)
            }
            let dedupedAreas = dedupeLifeAreasByNormalizedName(listedAreas)
            let generalArea = try await resolveGeneralLifeArea(from: dedupedAreas.filter { $0.isArchived == false })

            if runBackfill || hasPerformedBackfill == false {
                _ = try? await awaitProjectResult { completion in
                    self.manageProjectsUseCase.backfillUnassignedProjectsToGeneral(
                        generalLifeAreaID: generalArea.id,
                        completion: completion
                    )
                }
                hasPerformedBackfill = true
            }

            let projectStats = try await awaitProjectResult { completion in
                self.manageProjectsUseCase.getAllProjects(completion: completion)
            }
            let habitRows = try await awaitResult { completion in
                self.useCaseCoordinator.getHabitLibrary.execute(includeArchived: true, completion: completion)
            }

            var mergedAreas = dedupedAreas
            if mergedAreas.contains(where: { $0.id == generalArea.id }) == false {
                mergedAreas.append(generalArea)
            }

            sourceLifeAreas = mergedAreas
            sourceProjectStats = projectStats
            sourceHabitRows = habitRows
            generalLifeAreaID = generalArea.id
            rebuildDerivedState()
        } catch {
            errorMessage = error.localizedDescription
        }

        if showsLoading {
            isLoading = false
        }
    }

    private func resolveGeneralLifeArea(from activeAreas: [LifeArea]) async throws -> LifeArea {
        if let general = activeAreas.first(where: { normalizedLifeAreaName($0.name) == LifeManagementConstants.generalNormalizedName }) {
            return general
        }

        do {
            return try await awaitResult { completion in
                self.manageLifeAreasUseCase.create(
                    name: LifeManagementConstants.generalDisplayName,
                    color: LifeAreaConstants.generalSeedColor,
                    icon: "square.grid.2x2",
                    completion: completion
                )
            }
        } catch {
            let refreshedAreas = try await awaitResult { completion in
                self.manageLifeAreasUseCase.list(completion: completion)
            }
            if let general = refreshedAreas.first(where: { normalizedLifeAreaName($0.name) == LifeManagementConstants.generalNormalizedName }) {
                return general
            }
            throw error
        }
    }

    private func dedupeLifeAreasByNormalizedName(_ lifeAreas: [LifeArea]) -> [LifeArea] {
        var chosenByName: [String: LifeArea] = [:]
        for lifeArea in lifeAreas {
            let normalizedName = normalizedLifeAreaName(lifeArea.name)
            if let existing = chosenByName[normalizedName] {
                let keepExisting = existing.createdAt <= lifeArea.createdAt
                chosenByName[normalizedName] = keepExisting ? existing : lifeArea
            } else {
                chosenByName[normalizedName] = lifeArea
            }
        }

        var emitted = Set<String>()
        var deduped: [LifeArea] = []
        for lifeArea in lifeAreas {
            let normalizedName = normalizedLifeAreaName(lifeArea.name)
            guard chosenByName[normalizedName]?.id == lifeArea.id else { continue }
            guard emitted.insert(normalizedName).inserted else { continue }
            deduped.append(lifeArea)
        }
        return deduped
    }

    private func normalizedLifeAreaName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed.isEmpty ? LifeManagementConstants.generalDisplayName : trimmed).lowercased()
    }

    private func isGeneralArea(_ area: LifeArea) -> Bool {
        normalizedLifeAreaName(area.name) == LifeManagementConstants.generalNormalizedName
    }

    private func resetDragState() {
        draggingProjectID = nil
        activeDropLifeAreaID = nil
    }

    private func awaitResult<T>(
        _ body: (@escaping (Result<T, Error>) -> Void) -> Void
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            body { result in
                continuation.resume(with: result)
            }
        }
    }

    private func awaitProjectResult<T>(
        _ body: (@escaping (Result<T, ProjectError>) -> Void) -> Void
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            body { result in
                continuation.resume(with: result.mapError { $0 as Error })
            }
        }
    }

    private func awaitVoid(
        _ body: (@escaping (Result<Void, Error>) -> Void) -> Void
    ) async throws {
        _ = try await awaitResult(body)
    }
}

private enum LifeManagementMutationError: LocalizedError {
    case projectMoveRolledBack(moveError: Error)
    case projectMoveRollbackFailed(moveError: Error, rollbackError: Error)

    var errorDescription: String? {
        switch self {
        case .projectMoveRolledBack:
            return "Project details were restored because moving the project to the selected area failed."
        case .projectMoveRollbackFailed:
            return "Project updates could not be safely rolled back after the move failed."
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
